import Foundation
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
import BackgroundTasks
#endif

// MARK: - Gestionnaire Natif de Notifications « Livria Store » (APNs HTTP/2 + BGTaskScheduler + Anti-Spam Quotidien • Swift 6)

private final class LivriaBGTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private let completeBlock: (Bool) -> Void

    init(_ complete: @escaping (Bool) -> Void) {
        self.completeBlock = complete
    }

    func complete(_ ok: Bool) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()
        completeBlock(ok)
    }
}

#if canImport(UIKit)
private final class LivriaRemoteFetchBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let completeBlock: (UIBackgroundFetchResult) -> Void

    init(_ complete: @escaping (UIBackgroundFetchResult) -> Void) {
        self.completeBlock = complete
    }

    func complete(_ result: UIBackgroundFetchResult) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        completeBlock(result)
    }
}

/// Pont strictement `nonisolated` pour `BGTaskScheduler` (Swift 6 Strict Concurrency).
/// Évite toute assertion d'isolation `@MainActor` sur la file système `com.apple.BGTaskScheduler`.
private enum LivriaBackgroundRuntime {
    static let refreshIdentifier = "com.viplenetwork.livria.bgrefresh"
    static let processingIdentifier = "com.viplenetwork.livria.bgprocessing"

    static func scheduleAll() {
        let refreshReq = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        refreshReq.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(refreshReq)

        let procReq = BGProcessingTaskRequest(identifier: processingIdentifier)
        procReq.requiresNetworkConnectivity = true
        procReq.requiresExternalPower = false
        procReq.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(procReq)
    }

    static func registerAll() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            let box = LivriaBGTaskBox { ok in task.setTaskCompleted(success: ok) }
            scheduleAll()
            let work = Task { @MainActor in
                let ok = await LivriaNotificationManager.shared.performNotificationPollCycle(isBackground: true)
                box.complete(ok)
            }
            task.expirationHandler = {
                work.cancel()
                scheduleAll()
                box.complete(false)
            }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            let box = LivriaBGTaskBox { ok in task.setTaskCompleted(success: ok) }
            scheduleAll()
            let work = Task { @MainActor in
                let ok = await LivriaNotificationManager.shared.performNotificationPollCycle(isBackground: true)
                box.complete(ok)
            }
            task.expirationHandler = {
                work.cancel()
                scheduleAll()
                box.complete(false)
            }
        }
    }
}

@MainActor
public final class LivriaAppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LivriaNotificationManager.shared.configureOnLaunch()
        return true
    }

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        LivriaNotificationManager.shared.handleRegisteredDeviceToken(deviceToken)
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        LivriaNotificationManager.shared.scheduleBackgroundTasks()
    }

    public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let box = LivriaRemoteFetchBox(completionHandler)
        Task { @MainActor in
            LivriaNotificationManager.shared.scheduleBackgroundTasks()
            let ok = await LivriaNotificationManager.shared.performNotificationPollCycle(isBackground: true)
            box.complete(ok ? .newData : .noData)
        }
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let remoteNotifId = (userInfo["notificationId"] as? String) ?? ""
        let box = LivriaRemoteFetchBox(completionHandler)
        Task { @MainActor in
            if !remoteNotifId.isEmpty {
                LivriaNotificationManager.shared.markNotificationSeenAndAck(remoteNotifId)
            }
            LivriaNotificationManager.shared.scheduleBackgroundTasks()
            let ok = await LivriaNotificationManager.shared.performNotificationPollCycle(isBackground: true)
            box.complete(ok ? .newData : .noData)
        }
    }
}
#endif

@MainActor
public final class LivriaNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = LivriaNotificationManager()

    public static let refreshTaskIdentifier = "com.viplenetwork.livria.bgrefresh"
    public static let processingTaskIdentifier = "com.viplenetwork.livria.bgprocessing"
    public static let storeCategoryIdentifier = "LIVRIA_STORE_NOTIF"

    public static let actionOpenReleases = "OPEN_DAILY_RELEASES_ACTION"
    public static let actionOpenBook = "OPEN_BOOK_DETAIL_ACTION"

    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: notificationsEnabledKey)
            Task { await syncDeviceRegistration() }
        }
    }
    @Published public var newReleasesEnabled: Bool {
        didSet {
            defaults.set(newReleasesEnabled, forKey: newReleasesEnabledKey)
            Task { await syncDeviceRegistration() }
        }
    }
    @Published public var dailyRecommendationsEnabled: Bool {
        didSet {
            defaults.set(dailyRecommendationsEnabled, forKey: dailyRecsEnabledKey)
            Task { await syncDeviceRegistration() }
        }
    }
    @Published public private(set) var apnsDeviceTokenHex: String? = nil
    @Published public private(set) var lastSyncDate: Date? = nil

    public weak var attachedStore: LivriaStoreViewModel?

    private let defaults = UserDefaults.standard
    private let notificationsEnabledKey = "livria.store.ios.notif.enabled.v1"
    private let newReleasesEnabledKey = "livria.store.ios.notif.newReleases.v1"
    private let dailyRecsEnabledKey = "livria.store.ios.notif.dailyRecs.v1"
    private let savedApnsTokenKey = "livria.store.ios.apnsTokenHex.v1"
    private let seenNotificationIdsKey = "livria.store.ios.seenNotifIds.v1"
    private let pendingDeepLinkKey = "livria.store.ios.pendingNotifDeepLink.v1"
    private let cachedUserIdKey = "livria.store.ios.notif.userId.v1"
    private let cachedEmailKey = "livria.store.ios.notif.email.v1"
    private let cachedCidKey = "livria.store.ios.notif.cid.v1"

    private var didRegisterBackgroundTasks = false
    private var isPollInFlight = false
    private var foregroundLoopTask: Task<Void, Never>? = nil
    #if canImport(UIKit)
    private var backgroundGraceTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif

    private override init() {
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "livria.store.ios.notif.enabled.v1") as? Bool ?? true
        self.newReleasesEnabled = UserDefaults.standard.object(forKey: "livria.store.ios.notif.newReleases.v1") as? Bool ?? true
        self.dailyRecommendationsEnabled = UserDefaults.standard.object(forKey: "livria.store.ios.notif.dailyRecs.v1") as? Bool ?? true
        self.apnsDeviceTokenHex = UserDefaults.standard.string(forKey: "livria.store.ios.apnsTokenHex.v1")
        super.init()
    }

    public var isOsAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    public var statusBadgeText: String {
        if !notificationsEnabled || !newReleasesEnabled {
            return "Alertes désactivées"
        }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Alertes activées"
        case .denied:
            return "Bloqué dans Réglages"
        case .notDetermined:
            return "Activer les alertes"
        @unknown default:
            return "Alertes actives"
        }
    }

    // MARK: - 1. Configuration au Lancement, Catégories & Permissions OS

    public func configureOnLaunch() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationCategories()
        registerBackgroundTasksIfNeeded()
        scheduleBackgroundTasks()

        Task {
            await refreshAuthorizationStatus()
            if isOsAuthorized {
                registerForRemoteNotificationsOnSystem()
            }
        }
    }

    private func registerNotificationCategories() {
        let openReleasesAction = UNNotificationAction(
            identifier: Self.actionOpenReleases,
            title: "Voir les nouveautés du jour",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "sparkles")
        )
        let openBookAction = UNNotificationAction(
            identifier: Self.actionOpenBook,
            title: "Découvrir l'ouvrage",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "book.fill")
        )
        let storeCategory = UNNotificationCategory(
            identifier: Self.storeCategoryIdentifier,
            actions: [openReleasesAction, openBookAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Nouvelle sélection Livria Store",
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([storeCategory])
    }

    private func registerBackgroundTasksIfNeeded() {
        guard !didRegisterBackgroundTasks else { return }
        didRegisterBackgroundTasks = true
        #if canImport(UIKit)
        LivriaBackgroundRuntime.registerAll()
        #endif
    }

    public func scheduleBackgroundTasks() {
        #if canImport(UIKit)
        LivriaBackgroundRuntime.scheduleAll()
        #endif
    }

    public func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    public func requestPermissionIfNeeded(promptIfNotDetermined: Bool = true) async -> Bool {
        await refreshAuthorizationStatus()

        if authorizationStatus == .notDetermined && promptIfNotDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                await refreshAuthorizationStatus()
                if granted {
                    registerForRemoteNotificationsOnSystem()
                    await syncDeviceRegistration()
                }
                return granted
            } catch {
                return false
            }
        }

        if isOsAuthorized {
            registerForRemoteNotificationsOnSystem()
            await syncDeviceRegistration()
            return true
        }

        return false
    }

    public func registerForRemoteNotificationsOnSystem() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    public func openSystemNotificationSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    public func handleRegisteredDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.apnsDeviceTokenHex = hex
        defaults.set(hex, forKey: savedApnsTokenKey)

        Task {
            await syncDeviceRegistration()
        }
    }

    // MARK: - 2. Synchronisation de l'Appareil avec le Serveur Livria

    public var cachedAccountSnapshot: (userId: Int?, email: String?, cid: String?) {
        let uid = defaults.integer(forKey: cachedUserIdKey)
        let em = defaults.string(forKey: cachedEmailKey)
        let cid = defaults.string(forKey: cachedCidKey)
        return (uid > 0 ? uid : nil, em, cid)
    }

    private var resolvedUserId: Int? {
        if let store = attachedStore {
            guard store.isAuthenticated, let u = store.currentUser, !u.isGuestAccount, u.id > 0 else {
                return nil
            }
            return u.id
        }
        let saved = defaults.integer(forKey: cachedUserIdKey)
        return saved > 0 ? saved : nil
    }

    private var resolvedEmail: String? {
        if let store = attachedStore {
            guard store.isAuthenticated, let u = store.currentUser, !u.isGuestAccount, !u.email.isEmpty else {
                return nil
            }
            return u.email
        }
        guard let em = defaults.string(forKey: cachedEmailKey),
              !em.isEmpty,
              !em.lowercased().hasSuffix("@guest.livria.store") else {
            return nil
        }
        return em
    }

    private var resolvedCid: String? {
        if let store = attachedStore {
            guard store.isAuthenticated, let u = store.currentUser, !u.isGuestAccount else {
                return nil
            }
            return u.cid.isEmpty ? defaults.string(forKey: cachedCidKey) : u.cid
        }
        return defaults.string(forKey: cachedCidKey)
    }

    public func clearCachedUserCredentialsOnly() {
        defaults.removeObject(forKey: cachedUserIdKey)
        defaults.removeObject(forKey: cachedEmailKey)
        defaults.removeObject(forKey: cachedCidKey)
    }

    /// Efface immédiatement les identifiants du background poll et toutes les notifications locales en attente ou affichées.
    public func clearCachedUserStateAndNotificationsImmediately() {
        clearCachedUserCredentialsOnly()
        defaults.removeObject(forKey: pendingDeepLinkKey)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    public func syncDeviceRegistration(user: LivriaUserProfile? = nil, isExplicitLogin: Bool = false) async {
        if let user, user.isGuestAccount {
            clearCachedUserCredentialsOnly()
            return
        }

        let targetUid = user?.id ?? resolvedUserId
        let targetEmail = (user?.email ?? resolvedEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCid = user?.cid ?? resolvedCid
        let targetDisplayName = user?.displayName ?? attachedStore?.currentUser?.displayName

        guard let uid = targetUid, uid > 0,
              !targetEmail.isEmpty,
              !targetEmail.lowercased().hasSuffix("@guest.livria.store") else {
            clearCachedUserCredentialsOnly()
            return
        }

        // Si l'utilisateur change de compte sur cet iPhone, purge immédiatement les notifications de l'ancien compte
        let previousCachedEmail = (defaults.string(forKey: cachedEmailKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !previousCachedEmail.isEmpty && previousCachedEmail.lowercased() != targetEmail.lowercased() {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            defaults.removeObject(forKey: seenNotificationIdsKey)
        }

        defaults.set(uid, forKey: cachedUserIdKey)
        defaults.set(targetEmail, forKey: cachedEmailKey)
        if let targetCid, !targetCid.isEmpty {
            defaults.set(targetCid, forKey: cachedCidKey)
        }

        let sessionRevoked = await LivriaAPIClient.shared.registerPushDevice(
            userId: uid,
            email: targetEmail,
            cid: targetCid,
            displayName: targetDisplayName,
            apnsToken: apnsDeviceTokenHex,
            notificationsEnabled: notificationsEnabled,
            newReleasesEnabled: newReleasesEnabled,
            dailyRecommendationsEnabled: dailyRecommendationsEnabled,
            isExplicitLogin: isExplicitLogin
        )

        if sessionRevoked && !isExplicitLogin {
            await executeRemoteSessionRevocation()
        }
    }

    public func handleSignOut(previousUser: LivriaUserProfile?) async {
        await handleSignOut(
            userId: previousUser?.id,
            email: previousUser?.email,
            cid: previousUser?.cid
        )
    }

    public func handleSignOut(userId: Int?, email: String?, cid: String?) async {
        clearCachedUserStateAndNotificationsImmediately()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        await LivriaAPIClient.shared.unregisterPushDevice(
            userId: userId,
            email: email,
            cid: cid
        )
    }

    public func executeRemoteSessionRevocation() async {
        clearCachedUserStateAndNotificationsImmediately()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        if let store = attachedStore {
            store.handleRemoteSessionRevocation()
        } else {
            defaults.removeObject(forKey: "livria.store.ios.vipleLiveEmail")
            defaults.removeObject(forKey: "livria.store.ios.vipleLiveUserId")
            UserDefaults(suiteName: "group.store.livria.shared")?.removeObject(forKey: "viple.crossapp.store.account")
        }
    }

    // MARK: - 3. Cycle de Vie Scène, Boucle Premier Plan & Fenêtre Arrière-Plan

    public func consumePendingDeepLinkIfNeeded() {
        guard let store = attachedStore, !store.isInitialBootstrapping else { return }
        if let pending = defaults.string(forKey: pendingDeepLinkKey),
           !pending.isEmpty,
           let url = URL(string: pending) {
            defaults.removeObject(forKey: pendingDeepLinkKey)
            store.handleIncomingURL(url)
        }
    }

    public func enterForegroundMode() {
        endBackgroundGraceTask()
        startForegroundPollingLoop()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
            await refreshAuthorizationStatus()
            if attachedStore?.hasAcceptedTermsOfUse == true && authorizationStatus == .notDetermined {
                _ = await requestPermissionIfNeeded(promptIfNotDetermined: true)
            } else if isOsAuthorized {
                registerForRemoteNotificationsOnSystem()
                await syncDeviceRegistration()
            } else {
                await syncDeviceRegistration()
            }
            consumePendingDeepLinkIfNeeded()
        }
    }

    public func handleSceneBecameInactive() {
        scheduleBackgroundTasks()
    }

    public func enterBackgroundMode() {
        stopForegroundPollingLoop()
        scheduleBackgroundTasks()
        startBackgroundGracePoll()
    }

    private func startForegroundPollingLoop() {
        foregroundLoopTask?.cancel()
        foregroundLoopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                _ = await self.performNotificationPollCycle(isBackground: false)
                try? await Task.sleep(nanoseconds: 180_000_000_000) // Toutes les 3 min au premier plan
            }
        }
    }

    private func stopForegroundPollingLoop() {
        foregroundLoopTask?.cancel()
        foregroundLoopTask = nil
    }

    private func startBackgroundGracePoll() {
        #if canImport(UIKit)
        endBackgroundGraceTask()
        backgroundGraceTaskId = UIApplication.shared.beginBackgroundTask(withName: "LivriaStoreNotificationSync") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundGraceTask()
            }
        }
        Task { [weak self] in
            guard let self else { return }
            _ = await self.performNotificationPollCycle(isBackground: true)
            self.endBackgroundGraceTask()
        }
        #endif
    }

    private func endBackgroundGraceTask() {
        #if canImport(UIKit)
        if backgroundGraceTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundGraceTaskId)
            backgroundGraceTaskId = .invalid
        }
        #endif
    }

    // MARK: - 4. Polling, Déduplication Persistante & Planification UNNotificationCenter

    private var seenNotificationIds: [String] {
        defaults.stringArray(forKey: seenNotificationIdsKey) ?? []
    }

    private func appendSeenNotificationIds(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var current = seenNotificationIds
        for id in ids where !id.isEmpty && !current.contains(id) {
            current.append(id)
        }
        if current.count > 300 {
            current = Array(current.suffix(300))
        }
        defaults.set(current, forKey: seenNotificationIdsKey)
    }

    public func markNotificationSeenAndAck(_ notificationId: String) {
        guard !notificationId.isEmpty else { return }
        appendSeenNotificationIds([notificationId])
        let uid = resolvedUserId
        let em = resolvedEmail
        Task {
            await LivriaAPIClient.shared.ackNotifications(
                notificationIds: [notificationId],
                userId: uid,
                email: em
            )
        }
    }

    @discardableResult
    public func performNotificationPollCycle(isBackground: Bool) async -> Bool {
        guard !isPollInFlight else { return false }
        guard let pollUid = resolvedUserId, pollUid > 0,
              let pollEmail = resolvedEmail, !pollEmail.isEmpty,
              !pollEmail.lowercased().hasSuffix("@guest.livria.store") else {
            return false
        }
        let pollCid = resolvedCid

        isPollInFlight = true
        defer { isPollInFlight = false }

        do {
            let poll = try await LivriaAPIClient.shared.pollNotifications(
                userId: pollUid,
                email: pollEmail,
                cid: pollCid,
                limit: 25,
                fastBackground: isBackground
            )
            self.lastSyncDate = Date()

            if poll.sessionRevoked {
                await executeRemoteSessionRevocation()
                return false
            }

            // Vérifie que l'utilisateur ne s'est pas déconnecté ou n'a pas changé de compte pendant la requête réseau
            guard let activeEmail = resolvedEmail,
                  activeEmail.lowercased() == pollEmail.lowercased() else {
                return false
            }

            if let store = attachedStore {
                store.notificationInbox = poll.recent
                if !isBackground && poll.todayReleasesCount != (store.dailyNewReleases?.todayCount ?? -1) {
                    await store.loadDailyNewReleases()
                }
            }

            guard notificationsEnabled else {
                if !poll.unseen.isEmpty {
                    await LivriaAPIClient.shared.ackNotifications(
                        notificationIds: poll.unseen.map(\.id),
                        userId: pollUid,
                        email: pollEmail
                    )
                }
                return true
            }

            await refreshAuthorizationStatus()
            let alreadySeen = Set(seenNotificationIds)
            var deliveredIds: [String] = []

            for item in poll.unseen.prefix(3) {
                if alreadySeen.contains(item.id) {
                    deliveredIds.append(item.id)
                    continue
                }
                if item.kind == "new_releases" && !newReleasesEnabled {
                    deliveredIds.append(item.id)
                    continue
                }
                if item.kind == "daily_rec" && !dailyRecommendationsEnabled {
                    deliveredIds.append(item.id)
                    continue
                }

                if isOsAuthorized {
                    let added = await scheduleLocalNotification(for: item, isBackground: isBackground)
                    if added {
                        appendSeenNotificationIds([item.id])
                        deliveredIds.append(item.id)
                    }
                }
            }

            if !deliveredIds.isEmpty {
                await LivriaAPIClient.shared.ackNotifications(
                    notificationIds: deliveredIds,
                    userId: pollUid,
                    email: pollEmail
                )
            }

            return true
        } catch {
            return false
        }
    }

    private func scheduleLocalNotification(
        for item: LivriaMobileNotificationItem,
        isBackground: Bool
    ) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = item.title
        if !item.subtitle.isEmpty {
            content.subtitle = item.subtitle
        }
        content.body = item.body
        content.sound = .default
        content.categoryIdentifier = Self.storeCategoryIdentifier
        content.threadIdentifier = "livria-store"
        content.interruptionLevel = .active

        var info: [String: Any] = [
            "notificationId": item.id,
            "kind": item.kind,
            "target": item.target,
            "deepLink": item.deepLink
        ]
        if let bookId = item.bookId, bookId > 0 {
            info["bookId"] = bookId
        }
        content.userInfo = info

        if !isBackground, let attachment = await downloadCoverAttachment(rawUrl: item.coverUrl) {
            content.attachments = [attachment]
        }

        let req = UNNotificationRequest(
            identifier: "livria.notif.\(item.id)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(req)
            return true
        } catch {
            return false
        }
    }

    private func downloadCoverAttachment(rawUrl: String?) async -> UNNotificationAttachment? {
        guard let url = LivriaURLResolver.resolve(rawUrl) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.8
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        let tempUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("livria-cover-\(UUID().uuidString.prefix(10)).jpg")
        do {
            try data.write(to: tempUrl, options: .atomic)
            return try UNNotificationAttachment(identifier: "cover", url: tempUrl, options: nil)
        } catch {
            return nil
        }
    }

    // MARK: - 5. UNUserNotificationCenterDelegate (Swift 6 Strict Concurrency Safe)

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let notifId = (notification.request.content.userInfo["notificationId"] as? String) ?? ""
        return await MainActor.run {
            guard let activeEmail = self.resolvedEmail,
                  !activeEmail.isEmpty,
                  !activeEmail.lowercased().hasSuffix("@guest.livria.store") else {
                return []
            }
            if !notifId.isEmpty {
                self.markNotificationSeenAndAck(notifId)
            }
            guard self.notificationsEnabled else { return [] }
            return [.banner, .list, .sound, .badge]
        }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let notifId = (userInfo["notificationId"] as? String) ?? ""
        let target = (userInfo["target"] as? String) ?? ""
        let deepLink = (userInfo["deepLink"] as? String) ?? ""
        let parsedBookId: Int? = {
            if let intVal = userInfo["bookId"] as? Int { return intVal }
            if let numVal = userInfo["bookId"] as? NSNumber { return numVal.intValue }
            if let strVal = userInfo["bookId"] as? String, let intVal = Int(strVal) { return intVal }
            return nil
        }()

        await handleNotificationInteraction(
            actionIdentifier: actionId,
            notificationId: notifId,
            target: target,
            bookId: parsedBookId,
            deepLink: deepLink
        )
    }

    private func handleNotificationInteraction(
        actionIdentifier: String,
        notificationId: String,
        target: String,
        bookId: Int?,
        deepLink: String
    ) async {
        if !notificationId.isEmpty {
            markNotificationSeenAndAck(notificationId)
        }
        try? await UNUserNotificationCenter.current().setBadgeCount(0)

        guard actionIdentifier != UNNotificationDismissActionIdentifier else { return }

        let lowerTarget = target.lowercased()
        let lowerDeepLink = deepLink.lowercased()

        let resolvedUrlString: String
        if actionIdentifier == Self.actionOpenReleases ||
           lowerTarget == "daily-releases" ||
           lowerDeepLink.contains("nouvelles-sorties") ||
           lowerDeepLink.contains("daily-releases") ||
           lowerDeepLink.contains("new-releases") {
            resolvedUrlString = "livriastore://nouvelles-sorties"
        } else if let bookId, bookId > 0 {
            resolvedUrlString = "livriastore://book/\(bookId)"
        } else if !deepLink.isEmpty {
            resolvedUrlString = deepLink
        } else {
            resolvedUrlString = "livriastore://nouvelles-sorties"
        }

        guard let url = URL(string: resolvedUrlString) else { return }
        if let store = attachedStore {
            store.handleIncomingURL(url)
        } else {
            defaults.set(resolvedUrlString, forKey: pendingDeepLinkKey)
        }
    }
}
