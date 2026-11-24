import Foundation
import SwiftUI
import UserNotifications
import Security
#if canImport(UIKit)
import UIKit
#endif
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

// MARK: - Créneaux Horaires du Rappel Quotidien Cenelis Academy (Heure de Paris)

public enum AcademyReminderTimeSlot: String, CaseIterable, Identifiable, Sendable {
    case midday = "12:30"
    case evening = "18:30"
    case night = "20:30"

    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .midday: return "12h30"
        case .evening: return "18h30"
        case .night: return "20h30"
        }
    }

    public var hour: Int {
        switch self {
        case .midday: return 12
        case .evening: return 18
        case .night: return 20
        }
    }

    public var minute: Int { 30 }
}

#if canImport(BackgroundTasks)
private final class SendableBGTaskBox: @unchecked Sendable {
    let task: BGTask
    init(_ task: BGTask) {
        self.task = task
    }
}
#endif

// MARK: - Gestionnaire Centralisé des Notifications Quotidiennes (APNs .p8 + BGAppRefreshTask + Rappel Local Hors-Ligne)

@MainActor
public final class AcademyNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = AcademyNotificationManager()

    public nonisolated static let bgRefreshTaskId = "com.cenelis.academy.bgrefresh"
    public nonisolated static let dailyLocalReminderId = "cenelis.academy.daily.reminder"
    public nonisolated static let dailyCategoryId = "CENELIS_ACADEMY_DAILY"
    public nonisolated static let dailyThreadId = "cenelis-academy-daily"

    private enum Keys {
        static let dailyEnabled = "ca.notif.dailyEnabled"
        static let reminderSlot = "ca.notif.reminderSlot"
        static let deviceId = "ca.notif.deviceId"
        static let apnsToken = "ca.notif.apnsToken"
        static let lastDeliveredParisDay = "ca.notif.lastDeliveredParisDay"
        static let seenNudgeIds = "ca.notif.seenNudgeIds"
        static let detectedTeamId = "ca.detectedAppleTeamId"
    }

    @Published public private(set) var authorizationGranted: Bool = false
    @Published public private(set) var apnsTokenHex: String = ""

    public var dailyRemindersEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.dailyEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.dailyEnabled)
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Keys.dailyEnabled)
        }
    }

    public var reminderTimeSlot: AcademyReminderTimeSlot {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.reminderSlot),
               let slot = AcademyReminderTimeSlot(rawValue: raw) {
                return slot
            }
            return .evening
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.reminderSlot)
        }
    }

    private weak var boundStore: AcademyStoreViewModel?
    private var pendingNotificationURL: URL?
    private var hasRegisteredBGTask: Bool = false
    private var hasRequestedAuthorizationThisSession: Bool = false

    private override init() {
        self.apnsTokenHex = UserDefaults.standard.string(forKey: Keys.apnsToken) ?? ""
        super.init()
    }

    // MARK: - Liaison avec AcademyStoreViewModel & Routage Deep-Link Différé (Compatible Gate PIN)

    public func bind(to store: AcademyStoreViewModel) {
        self.boundStore = store
        clearBadgeCount()

        if let pending = pendingNotificationURL {
            pendingNotificationURL = nil
            Task { @MainActor in
                await store.handleIncomingURL(pending)
            }
        }
    }

    public func clearBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    public func configureNotificationCategories() {
        let openCourseAction = UNNotificationAction(
            identifier: "OPEN_ACADEMY_COURSE",
            title: "Continuer mon parcours",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.dailyCategoryId,
            actions: [openCourseAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Demande d'Autorisation iOS & Enregistrement APNs (.p8)

    public func requestPermissionsAndRegisterIfNeeded(mobileToken: String) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            guard dailyRemindersEnabled, !hasRequestedAuthorizationThisSession else {
                authorizationGranted = false
                return
            }
            hasRequestedAuthorizationThisSession = true
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            authorizationGranted = granted
            if granted {
                #if canImport(UIKit)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
        case .authorized, .provisional, .ephemeral:
            authorizationGranted = true
            #if canImport(UIKit)
            UIApplication.shared.registerForRemoteNotifications()
            #endif
        case .denied:
            authorizationGranted = false
        @unknown default:
            authorizationGranted = false
        }

        await syncDeviceWithBackend(mobileToken: mobileToken, isExplicitLogin: false)
    }

    public func handleDidRegisterForRemoteNotifications(tokenHex: String) async {
        let clean = tokenHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return }
        self.apnsTokenHex = clean
        UserDefaults.standard.set(clean, forKey: Keys.apnsToken)

        let token = boundStore?.mobileToken
            ?? UserDefaults.standard.string(forKey: "ca.mobileToken")
            ?? ""
        let email = boundStore?.learner.email
            ?? UserDefaults.standard.string(forKey: "ca.learnerEmail")
            ?? ""
        if !token.isEmpty && !email.isEmpty {
            await syncDeviceWithBackend(mobileToken: token, isExplicitLogin: false)
        }
    }

    public func handleRemoteRegistrationFailure(message: String) {
        // Sur simulateur ou réseau restreint, le planificateur local + BGAppRefreshTask assurent la continuité 1×/jour
        _ = message
    }

    public func syncDeviceWithBackend(mobileToken: String, isExplicitLogin: Bool = true) async {
        guard !mobileToken.isEmpty else { return }
        let hw = AcademyDeviceHardwareInfo.current()
        let slot = reminderTimeSlot
        let enabled = dailyRemindersEnabled
        let teamId = Self.detectAppleTeamIdFromKeychain()
        let env = Self.detectApnsEnvironment()

        let res = await AcademyAPIClient.shared.registerPushDevice(
            deviceId: hw.deviceId,
            physicalDeviceId: hw.physicalDeviceId,
            apnsToken: apnsTokenHex,
            apnsEnvironment: env,
            appleTeamId: teamId,
            notificationsEnabled: enabled,
            preferredHourParis: slot.hour,
            preferredMinuteParis: slot.minute,
            isExplicitLogin: isExplicitLogin,
            token: mobileToken
        )

        if res.sessionRevoked {
            boundStore?.logout(remoteRevocationMessage: "Cet appareil a été déconnecté à distance.")
        }
    }

    public func cancelAllLocalNotificationsImmediately() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyLocalReminderId])
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        clearBadgeCount()
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgRefreshTaskId)
        #endif
        UserDefaults.standard.removeObject(forKey: "ca.mobileToken")
        UserDefaults(suiteName: AcademyDeviceHardwareInfo.sharedSuiteName)?.removeObject(forKey: "ca.mobileToken")
    }

    public func unregisterDeviceOnLogout(token: String, email: String = "", cid: String = "") async {
        cancelAllLocalNotificationsImmediately()
        let hw = AcademyDeviceHardwareInfo.current()
        _ = await AcademyAPIClient.shared.unregisterPushDevice(
            deviceId: hw.deviceId,
            physicalDeviceId: hw.physicalDeviceId,
            apnsToken: apnsTokenHex,
            token: token,
            email: email,
            cid: cid
        )
    }

    public func persistentDeviceId() -> String {
        AcademyDeviceHardwareInfo.resolveOrCreateLocalDeviceId()
    }

    public func sharedPhysicalDeviceId() -> String {
        let devId = AcademyDeviceHardwareInfo.resolveOrCreateLocalDeviceId()
        return AcademyDeviceHardwareInfo.resolveOrPersistSharedPhysicalDeviceId(fallbackDeviceId: devId)
    }

    // MARK: - Détection Automatique de l'Apple Team ID depuis le Trousseau (Keychain Access Group Prefix)

    public nonisolated static func detectAppleTeamIdFromKeychain() -> String? {
        if let cached = UserDefaults.standard.string(forKey: Keys.detectedTeamId),
           cached.count == 10,
           cached.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return cached
        }

        let account = "cenelis.academy.teamid.probe"
        let service = "com.cenelis.academy.teamid"

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        var readQuery = baseQuery
        readQuery[kSecReturnAttributes as String] = kCFBooleanTrue
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        var status = SecItemCopyMatching(readQuery as CFDictionary, &item)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            addQuery[kSecReturnAttributes as String] = kCFBooleanTrue
            status = SecItemAdd(addQuery as CFDictionary, &item)
        }

        guard status == errSecSuccess,
              let attrs = item as? [String: Any],
              let accessGroup = attrs[kSecAttrAccessGroup as String] as? String else {
            return nil
        }

        let parts = accessGroup.split(separator: ".")
        guard let prefix = parts.first,
              prefix.count == 10,
              prefix.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return nil
        }

        let teamId = String(prefix).uppercased()
        UserDefaults.standard.set(teamId, forKey: Keys.detectedTeamId)
        return teamId
    }

    public nonisolated static func detectApnsEnvironment() -> String {
        #if targetEnvironment(simulator)
        return "development"
        #else
        guard let provisionURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let rawData = try? Data(contentsOf: provisionURL),
              let content = String(data: rawData, encoding: .isoLatin1) else {
            #if DEBUG
            return "development"
            #else
            return "production"
            #endif
        }
        if content.contains("<key>aps-environment</key>") && content.contains("<string>production</string>") {
            return "production"
        }
        return "development"
        #endif
    }

    // MARK: - Planificateur Local Intelligent 1×/jour (Hors-Ligne & Zéro Doublon avec le Push Serveur)

    public func refreshLocalDailyReminder(
        catalog: AcademyBootstrapPayload,
        progress: AcademyUserProgress,
        isAuthenticated: Bool,
        forceSkipToday: Bool = false
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyLocalReminderId])

        guard dailyRemindersEnabled, isAuthenticated else {
            return
        }

        let parisTZ = TimeZone(identifier: "Europe/Paris") ?? .current
        var parisCal = Calendar(identifier: .gregorian)
        parisCal.timeZone = parisTZ

        let now = Date()
        let todayParis = Self.parisDayKey(for: now, timeZone: parisTZ)
        let studiedToday = (progress.lastActiveDay == todayParis)
        let alreadyNotifiedToday = forceSkipToday || hasDeliveredNudgeToday(parisDay: todayParis)

        let slot = reminderTimeSlot
        let nowComps = parisCal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        let slotMinutes = slot.hour * 60 + slot.minute

        let visibleCourses = catalog.courses.filter { !$0.hiddenFromHome && !$0.isCustomerGuide }

        let inProgressCourse = visibleCourses.first { course in
            let doneCount = course.parts.filter { progress.completedParts[$0.id] != nil }.count
            let hasSavedStep = (progress.lastStep[course.id] ?? 0) > 0
            let isCertified = Self.isCourseCertified(course, progress: progress)
            return (doneCount > 0 || hasSavedStep) && !isCertified
        }

        let nextCourse = visibleCourses.first { course in
            !Self.isCourseCertified(course, progress: progress)
        } ?? visibleCourses.first

        let streak = progress.streakDays
        let dayOrdinal = parisCal.ordinality(of: .day, in: .year, for: now) ?? 1

        let title: String
        let subtitle: String
        let body: String
        let targetCourseId: String
        let deepLink: String
        let variant: String

        if streak >= 2 && (inProgressCourse == nil || dayOrdinal % 2 == 1) {
            let cleanCourseTitle = inProgressCourse.map { Self.shortCourseTitle($0.title) }
            title = "🔥 Continuez votre flamme de \(streak) jours !"
            subtitle = cleanCourseTitle.map { "Cours en cours : \($0)" } ?? "Objectif quotidien Cenelis Academy"
            body = cleanCourseTitle.map { "5 minutes sur « \($0) » suffisent aujourd'hui pour valider votre série et vos XP." }
                ?? "Validez une étape aujourd'hui sur Cenelis Academy pour maintenir votre série d'apprentissage !"
            targetCourseId = inProgressCourse?.id ?? ""
            deepLink = inProgressCourse.map { "cenelisacademy://course?id=\(Self.urlEncode($0.id))" } ?? "cenelisacademy://home"
            variant = "streak"
        } else if let course = inProgressCourse {
            let cleanTitle = Self.shortCourseTitle(course.title)
            let doneCount = course.parts.filter { progress.completedParts[$0.id] != nil }.count
            let pct = course.parts.isEmpty ? 10 : max(1, min(99, Int((Double(doneCount) / Double(course.parts.count) * 100.0).rounded())))
            title = "🎓 Avancez sur votre cours : \(cleanTitle)"
            subtitle = "Progression : \(pct)% · Flamme \(max(1, streak)) j 🔥"
            body = "Reprenez exactement là où vous vous êtes arrêté et débloquez la suite de votre parcours."
            targetCourseId = course.id
            deepLink = "cenelisacademy://course?id=\(Self.urlEncode(course.id))"
            variant = "course"
        } else if let next = nextCourse {
            let cleanTitle = Self.shortCourseTitle(next.title)
            title = "🚀 Démarrez votre cours : \(cleanTitle)"
            subtitle = "Maintenez votre flamme (\(max(1, streak)) j 🔥)"
            body = "Quelques minutes suffisent aujourd'hui pour progresser et enrichir votre Passeport Cenelis."
            targetCourseId = next.id
            deepLink = "cenelisacademy://course?id=\(Self.urlEncode(next.id))"
            variant = "discover"
        } else {
            title = streak >= 1 ? "🔥 Gardez votre flamme allumée !" : "🎓 Votre session quotidienne Cenelis Academy"
            subtitle = "Maintenez votre flamme (\(max(1, streak)) j 🔥)"
            body = "Quelques minutes suffisent aujourd'hui pour progresser et enrichir votre Passeport Cenelis."
            targetCourseId = ""
            deepLink = "cenelisacademy://home"
            variant = "discover"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.dailyCategoryId
        content.threadIdentifier = Self.dailyThreadId
        content.userInfo = [
            "courseId": targetCourseId,
            "deepLink": deepLink,
            "variant": variant,
            "source": "local_daily_reminder"
        ]

        let trigger: UNCalendarNotificationTrigger
        if (studiedToday || alreadyNotifiedToday) && nowMinutes < slotMinutes,
           let tomorrow = parisCal.date(byAdding: .day, value: 1, to: now) {
            // L'apprenant a déjà étudié aujourd'hui ou le push serveur du jour a déjà été reçu avant l'heure locale :
            // on programme le prochain rappel directement pour DEMAIN afin d'avoir 0 doublon aujourd'hui !
            var comps = parisCal.dateComponents([.year, .month, .day], from: tomorrow)
            comps.timeZone = parisTZ
            comps.hour = slot.hour
            comps.minute = slot.minute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else {
            var comps = DateComponents()
            comps.timeZone = parisTZ
            comps.hour = slot.hour
            comps.minute = slot.minute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }

        let req = UNNotificationRequest(
            identifier: Self.dailyLocalReminderId,
            content: content,
            trigger: trigger
        )
        center.add(req) { _ in }
    }

    // MARK: - BGAppRefreshTask (Réveil Arrière-Plan iOS -> GET /api/mobile/v1/notifications/daily-nudge)

    public func registerBackgroundTasksIfNeeded() {
        #if canImport(BackgroundTasks)
        guard !hasRegisteredBGTask else { return }
        hasRegisteredBGTask = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgRefreshTaskId, using: nil) { task in
            let box = SendableBGTaskBox(task)
            let runner = Task { @MainActor in
                AcademyNotificationManager.shared.scheduleNextBackgroundRefresh()
                let ok = await AcademyNotificationManager.shared.performBackgroundDailyNudgeCheck()
                box.task.setTaskCompleted(success: ok)
            }
            task.expirationHandler = {
                runner.cancel()
                box.task.setTaskCompleted(success: false)
            }
        }
        #endif
    }

    public func scheduleNextBackgroundRefresh() {
        #if canImport(BackgroundTasks)
        let activeToken = boundStore?.mobileToken
            ?? UserDefaults.standard.string(forKey: "ca.mobileToken")
            ?? ""
        let activeEmail = boundStore?.learner.email
            ?? UserDefaults.standard.string(forKey: "ca.learnerEmail")
            ?? ""
        guard dailyRemindersEnabled, !activeToken.isEmpty, !activeEmail.isEmpty else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgRefreshTaskId)
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    public func performBackgroundDailyNudgeCheck() async -> Bool {
        let token = boundStore?.mobileToken
            ?? UserDefaults.standard.string(forKey: "ca.mobileToken")
            ?? ""
        let email = boundStore?.learner.email
            ?? UserDefaults.standard.string(forKey: "ca.learnerEmail")
            ?? ""

        guard !token.isEmpty, !email.isEmpty else {
            cancelAllLocalNotificationsImmediately()
            return true
        }

        guard dailyRemindersEnabled else { return true }

        let nudgeOpt: AcademyDailyNudgeResponse?
        do {
            nudgeOpt = try await AcademyAPIClient.shared.fetchDailyNudge(token: token)
        } catch let apiError as AcademyAPIError where apiError.isSessionTerminated {
            if let store = boundStore {
                store.logout(remoteRevocationMessage: apiError.errorDescription)
            } else {
                cancelAllLocalNotificationsImmediately()
                UserDefaults.standard.removeObject(forKey: "ca.learnerEmail")
                UserDefaults.standard.removeObject(forKey: "ca.learnerName")
                UserDefaults.standard.removeObject(forKey: "ca.learnerCid")
                UserDefaults.standard.removeObject(forKey: "ca.learnerGroups")
                UserDefaults.standard.removeObject(forKey: "ca.learnerHasAccess")
                UserDefaults.standard.removeObject(forKey: "ca.learnerScope")
                UserDefaults.standard.removeObject(forKey: "ca.learnerRbacStatus")
            }
            return true
        } catch {
            return false
        }

        guard let nudge = nudgeOpt, nudge.ok else {
            return true
        }

        if nudge.isSignedIn == false || nudge.notificationsEnabled == false {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyLocalReminderId])
            return true
        }

        // Si le serveur a déjà envoyé le push APNs aujourd'hui, enregistrer l'état et reprogrammer le rappel local à demain
        if nudge.alreadyPushedToday == true {
            recordNudgeSeen(nudgeId: nudge.nudgeId, parisDay: nudge.dateParis)
            postponeLocalReminderToTomorrowIfNeeded()
            return true
        }

        if nudge.studiedToday || hasSeenNudge(nudgeId: nudge.nudgeId, parisDay: nudge.dateParis) {
            return true
        }

        let parisTZ = TimeZone(identifier: "Europe/Paris") ?? .current
        var parisCal = Calendar(identifier: .gregorian)
        parisCal.timeZone = parisTZ
        let nowComps = parisCal.dateComponents([.hour, .minute], from: Date())
        let nowMinutes = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        let slot = reminderTimeSlot
        let targetMinutes = slot.hour * 60 + slot.minute

        // Respecter la fenêtre quotidienne 09h30–21h00 et l'heure préférée de l'utilisateur
        guard nowMinutes >= targetMinutes && nowMinutes <= (21 * 60) else {
            return true
        }

        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.subtitle = nudge.subtitle
        content.body = nudge.body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = nudge.category ?? Self.dailyCategoryId
        content.threadIdentifier = nudge.threadId ?? Self.dailyThreadId
        content.userInfo = [
            "notificationId": nudge.nudgeId,
            "courseId": nudge.courseId,
            "deepLink": nudge.deepLink,
            "variant": nudge.variant
        ]

        let req = UNNotificationRequest(identifier: nudge.nudgeId, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)

        recordNudgeSeen(nudgeId: nudge.nudgeId, parisDay: nudge.dateParis)
        postponeLocalReminderToTomorrowIfNeeded()
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate (Swift 6 Strict Concurrency : nonisolated + Task @MainActor)

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let activeToken = UserDefaults.standard.string(forKey: "ca.mobileToken") ?? ""
        let activeEmail = UserDefaults.standard.string(forKey: "ca.learnerEmail") ?? ""
        guard !activeToken.isEmpty, !activeEmail.isEmpty else {
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            completionHandler([])
            return
        }

        let info = notification.request.content.userInfo
        let nudgeId = (info["notificationId"] as? String) ?? notification.request.identifier
        let isLocalDaily = (notification.request.identifier == Self.dailyLocalReminderId)

        completionHandler([.banner, .list, .sound])

        Task { @MainActor in
            let todayParis = Self.parisDayKey(for: Date())
            AcademyNotificationManager.shared.recordNudgeSeen(nudgeId: nudgeId, parisDay: todayParis)
            if !isLocalDaily {
                AcademyNotificationManager.shared.postponeLocalReminderToTomorrowIfNeeded()
            }
        }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let deepLinkRaw = info["deepLink"] as? String
        let courseIdRaw = info["courseId"] as? String
        let nudgeId = (info["notificationId"] as? String) ?? response.notification.request.identifier

        completionHandler()

        Task { @MainActor in
            let todayParis = Self.parisDayKey(for: Date())
            AcademyNotificationManager.shared.recordNudgeSeen(nudgeId: nudgeId, parisDay: todayParis)
            AcademyNotificationManager.shared.postponeLocalReminderToTomorrowIfNeeded()
            AcademyNotificationManager.shared.clearBadgeCount()
            AcademyNotificationManager.shared.handleNotificationTap(deepLinkRaw: deepLinkRaw, courseIdRaw: courseIdRaw)
        }
    }

    // MARK: - Résolution Deep-Link au Tap & Anti-Doublon Quotidien

    private func handleNotificationTap(deepLinkRaw: String?, courseIdRaw: String?) {
        let resolvedURL: URL?
        if let raw = deepLinkRaw?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            resolvedURL = url
        } else if let cid = courseIdRaw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !cid.isEmpty {
            resolvedURL = URL(string: "cenelisacademy://course?id=\(Self.urlEncode(cid))")
        } else {
            resolvedURL = URL(string: "cenelisacademy://home")
        }

        guard let targetURL = resolvedURL else { return }

        if let store = boundStore {
            Task { @MainActor in
                await store.handleIncomingURL(targetURL)
            }
        } else {
            pendingNotificationURL = targetURL
        }
    }

    private func postponeLocalReminderToTomorrowIfNeeded() {
        if let store = boundStore {
            refreshLocalDailyReminder(
                catalog: store.catalog,
                progress: store.progress,
                isAuthenticated: store.learner.authenticated && store.learner.hasCenelisAccess,
                forceSkipToday: true
            )
        } else if let cachedCat = AcademyAPIClient.shared.loadCachedBootstrap(),
                  let cachedProg = AcademyAPIClient.shared.loadLocalProgress() {
            let hasToken = !(UserDefaults.standard.string(forKey: "ca.mobileToken") ?? "").isEmpty
            refreshLocalDailyReminder(
                catalog: cachedCat,
                progress: cachedProg,
                isAuthenticated: hasToken,
                forceSkipToday: true
            )
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyLocalReminderId])
        }
    }

    private func hasDeliveredNudgeToday(parisDay: String) -> Bool {
        UserDefaults.standard.string(forKey: Keys.lastDeliveredParisDay) == parisDay
    }

    private func hasSeenNudge(nudgeId: String, parisDay: String) -> Bool {
        if hasDeliveredNudgeToday(parisDay: parisDay) {
            return true
        }
        let seen = UserDefaults.standard.stringArray(forKey: Keys.seenNudgeIds) ?? []
        return seen.contains(nudgeId)
    }

    private func recordNudgeSeen(nudgeId: String, parisDay: String) {
        if !parisDay.isEmpty {
            UserDefaults.standard.set(parisDay, forKey: Keys.lastDeliveredParisDay)
        }
        guard !nudgeId.isEmpty else { return }
        var seen = UserDefaults.standard.stringArray(forKey: Keys.seenNudgeIds) ?? []
        if !seen.contains(nudgeId) {
            seen.append(nudgeId)
            if seen.count > 24 {
                seen = Array(seen.suffix(24))
            }
            UserDefaults.standard.set(seen, forKey: Keys.seenNudgeIds)
        }
    }

    // MARK: - Utilitaires Purs

    private nonisolated static func parisDayKey(for date: Date, timeZone: TimeZone? = TimeZone(identifier: "Europe/Paris")) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = timeZone ?? .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func isCourseCertified(_ course: AcademyCourse, progress: AcademyUserProgress) -> Bool {
        if let rec = progress.courseScores[course.id], rec.apte {
            return true
        }
        if let passed = progress.passedQuizzes[course.id], passed.effectivePct >= course.passThresholdPct {
            return true
        }
        return false
    }

    private static func shortCourseTitle(_ raw: String) -> String {
        let plain = AcademyRichTextParser.plainText(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return "Parcours Cenelis" }
        if plain.count > 58 {
            if let colonRange = plain.range(of: ":") {
                let prefix = String(plain[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if prefix.count >= 14 && prefix.count <= 56 {
                    return prefix
                }
            }
            return String(plain.prefix(55)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return plain
    }

    private static func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

// MARK: - UIApplicationDelegate Adaptor (APNs Device Token + BGTaskScheduler)

#if canImport(UIKit)
@MainActor
public final class AcademyAppDelegate: NSObject, UIApplicationDelegate {
    public override init() {
        super.init()
    }

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = AcademyNotificationManager.shared
        AcademyNotificationManager.shared.configureNotificationCategories()
        AcademyNotificationManager.shared.registerBackgroundTasksIfNeeded()
        AcademyNotificationManager.shared.scheduleNextBackgroundRefresh()
        return true
    }

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            await AcademyNotificationManager.shared.handleDidRegisterForRemoteNotifications(tokenHex: hex)
        }
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AcademyNotificationManager.shared.handleRemoteRegistrationFailure(message: error.localizedDescription)
    }

    public func applicationDidEnterBackground(_ application: UIApplication) {
        AcademyNotificationManager.shared.scheduleNextBackgroundRefresh()
    }
}
#endif
