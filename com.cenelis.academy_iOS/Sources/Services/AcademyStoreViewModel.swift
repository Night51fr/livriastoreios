import Foundation
import SwiftUI

// MARK: - Énumérations de Navigation & Préférences d'Affichage

public enum AcademyMainTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Accueil"
    case courses = "Cours"
    case arcade = "Arcade"
    case resources = "Ressources"
    case passport = "Passeport"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .home: return "sparkles"
        case .courses: return "graduationcap.fill"
        case .arcade: return "gamecontroller.fill"
        case .resources: return "books.vertical.fill"
        case .passport: return "person.text.rectangle.fill"
        }
    }
}

public enum AcademyReaderStyle: String, CaseIterable, Identifiable, Sendable {
    case fluid = "Lecture Fluide"
    case focusDeck = "Cartes Focus"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .fluid: return "text.page.fill"
        case .focusDeck: return "rectangle.stack.fill"
        }
    }
}

public enum AcademyDeviceCaptureMode: String, CaseIterable, Identifiable, Sendable {
    case mobile = "Mobile"
    case pc = "Ordinateur"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .mobile: return "iphone"
        case .pc: return "desktopcomputer"
        }
    }
}

public struct LightboxShotContext: Identifiable, Sendable {
    public let id = UUID()
    public let path: String
    public let title: String
    public let caption: String
    public let pins: [AcademyShotPin]

    public init(path: String, title: String, caption: String, pins: [AcademyShotPin] = []) {
        self.path = path
        self.title = title
        self.caption = caption
        self.pins = pins
    }
}

public struct XPToastItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let amount: Int
    public let label: String
    public let isMajor: Bool
}

public struct GlobalSearchResult: Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let icon: String
    public let title: String
    public let snippet: String
    public let actionCourseId: String?
    public let actionPartIndex: Int?
    public let actionBubbleKey: String?
    public let actionDeepDiveId: String?
    public let actionResourceTabId: String?
}

public enum AcademySecurityGate: Equatable, Sendable {
    case booting
    case loginRequired
    case permissionDenied
    case cguAcceptanceRequired
    case pinVerificationRequired
    case unlocked
}

public struct PinSafariLaunchItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let nonce: String

    public init(url: URL, nonce: String) {
        self.id = nonce
        self.url = url
        self.nonce = nonce
    }
}

// MARK: - ViewModel Principal Cenelis Academy (État Réactif, Sécurité Cenelis Connect, CGU, Gamification & Sync Cloud)

@MainActor
public final class AcademyStoreViewModel: ObservableObject {
    @Published public var catalog: AcademyBootstrapPayload = AcademyBootstrapPayload()
    @Published public var progress: AcademyUserProgress = AcademyUserProgress()
    @Published public var learner: AcademyLearnerProfile = AcademyLearnerProfile()
    @Published public var mobileToken: String = ""

    @Published public var isInitialBooting: Bool = true
    @Published public var isSyncing: Bool = false
    @Published public var isOfflineMode: Bool = false
    @Published public var lastSyncStatus: String = "Synchronisation prête"

    // Sécurité Institutionnelle : Connexion obligatoire, Habilitation Interne/Externe, CGU & PIN Cenelis Connect à chaque lancement
    @Published public var cguDocument: AcademyCGUDocument = .embeddedFallback
    @Published public var serverCguAcceptance: AcademyCGUAcceptanceStatus? = nil
    @Published public var isShowingCGUReadSheet: Bool = false
    @Published public private(set) var isPinVerifiedForCurrentLaunch: Bool = false
    @Published public var activePinSafariItem: PinSafariLaunchItem? = nil
    @Published public var pinGateMessage: String? = nil
    @Published public var shouldForceFreshSSOLogin: Bool = false

    // Préférences d'interface & Rappels quotidiens (1×/jour)
    @Published public var themeMode: AcademyThemeMode = .system {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "ca.themeMode") }
    }
    @Published public var readerStyle: AcademyReaderStyle = .fluid {
        didSet { UserDefaults.standard.set(readerStyle.rawValue, forKey: "ca.readerStyle") }
    }
    @Published public var shotDeviceMode: AcademyDeviceCaptureMode = .mobile {
        didSet { UserDefaults.standard.set(shotDeviceMode.rawValue, forKey: "ca.shotDeviceMode") }
    }
    @Published public var dailyRemindersEnabled: Bool = true {
        didSet {
            AcademyHaptics.selection()
            AcademyNotificationManager.shared.dailyRemindersEnabled = dailyRemindersEnabled
            handleNotificationPreferencesUpdated()
        }
    }
    @Published public var reminderTimeSlot: AcademyReminderTimeSlot = .evening {
        didSet {
            AcademyHaptics.selection()
            AcademyNotificationManager.shared.reminderTimeSlot = reminderTimeSlot
            handleNotificationPreferencesUpdated()
        }
    }

    // Navigation principale & Lecteur Natif
    @Published public var activeTab: AcademyMainTab = .home
    @Published public var activeCourseId: String? = nil
    @Published public var activeStepIndex: Int = 0

    // Feuilles contextuelles (Bulles, Approfondissements, Lightbox @2x, Recherche, Connexion)
    @Published public var activeBubble: AcademyBubble? = nil
    @Published public var activeDeepDive: AcademyDeepDive? = nil
    @Published public var activeLightboxShot: LightboxShotContext? = nil
    @Published public var isShowingSearch: Bool = false
    @Published public var isShowingAuthSheet: Bool = false
    @Published public var preselectedResourceTabId: String? = nil

    // Célébrations Motion Design
    @Published public var xpToast: XPToastItem? = nil
    @Published public var confettiTrigger: Int = 0

    private let sharedSuite = UserDefaults(suiteName: "group.com.viplenetwork.shared")
    private var cloudPushTask: Task<Void, Never>?
    private var pinPollingTask: Task<Void, Never>?
    private var hasAutoOpenedPinInCurrentGateEntry: Bool = false
    private var isProcessingIncomingHandoff: Bool = false
    private var pendingDeepLinkItems: [String: String]? = nil

    public var requiresCGUAcceptance: Bool {
        guard learner.authenticated, !learner.email.isEmpty else { return true }
        let local = AcademyAPIClient.shared.loadLocalCGUAcceptance(forEmail: learner.email)
        let localMatches = (local?.version == cguDocument.version)
            && (local?.hash.lowercased() == cguDocument.contentHash.lowercased())
        if !localMatches {
            return true
        }
        if let srv = serverCguAcceptance, srv.requiresAcceptance {
            return true
        }
        return false
    }

    public var isCGUModifiedAfterPriorAcceptance: Bool {
        let local = AcademyAPIClient.shared.loadLocalCGUAcceptance(forEmail: learner.email)
        if let local, !local.version.isEmpty,
           (local.version != cguDocument.version || local.hash.lowercased() != cguDocument.contentHash.lowercased()) {
            return true
        }
        if let srv = serverCguAcceptance, !srv.acceptedVersion.isEmpty, srv.requiresAcceptance {
            return true
        }
        return false
    }

    public var activeSecurityGate: AcademySecurityGate {
        if isInitialBooting { return .booting }
        if !learner.authenticated || mobileToken.isEmpty { return .loginRequired }
        if !learner.hasCenelisAccess { return .permissionDenied }
        if requiresCGUAcceptance { return .cguAcceptanceRequired }
        if !isPinVerifiedForCurrentLaunch { return .pinVerificationRequired }
        return .unlocked
    }

    public init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "ca.themeMode"),
           let mode = AcademyThemeMode(rawValue: savedTheme) {
            self.themeMode = mode
        }
        if let savedReader = UserDefaults.standard.string(forKey: "ca.readerStyle"),
           let style = AcademyReaderStyle(rawValue: savedReader) {
            self.readerStyle = style
        }
        if let savedShot = UserDefaults.standard.string(forKey: "ca.shotDeviceMode"),
           let shot = AcademyDeviceCaptureMode(rawValue: savedShot) {
            self.shotDeviceMode = shot
        }
        self.dailyRemindersEnabled = AcademyNotificationManager.shared.dailyRemindersEnabled
        self.reminderTimeSlot = AcademyNotificationManager.shared.reminderTimeSlot

        // Récupérer le jeton mobile Cenelis / Viple Live ID
        let storedToken = UserDefaults.standard.string(forKey: "ca.mobileToken")
            ?? sharedSuite?.string(forKey: "ca.mobileToken")
            ?? ""
        self.mobileToken = storedToken

        if !storedToken.isEmpty,
           let savedEmail = UserDefaults.standard.string(forKey: "ca.learnerEmail"), !savedEmail.isEmpty {
            let savedName = UserDefaults.standard.string(forKey: "ca.learnerName") ?? savedEmail
            let savedCid = UserDefaults.standard.string(forKey: "ca.learnerCid") ?? ""
            let savedGroups = UserDefaults.standard.stringArray(forKey: "ca.learnerGroups") ?? []
            let savedAccess = UserDefaults.standard.bool(forKey: "ca.learnerHasAccess")
            let savedScope = UserDefaults.standard.string(forKey: "ca.learnerScope") ?? "none"
            let savedStatus = UserDefaults.standard.string(forKey: "ca.learnerRbacStatus") ?? "unregistered"
            self.learner = AcademyLearnerProfile(
                authenticated: true,
                email: savedEmail,
                displayName: savedName,
                cid: savedCid,
                groups: savedGroups,
                hasCenelisAccess: savedAccess,
                permissionScope: savedScope,
                rbacStatus: savedStatus
            )
        }

        // Initialiser immédiatement l'identité matérielle partagée (App Group cenelis.shared.physicalDeviceId.v1)
        _ = AcademyDeviceHardwareInfo.current()

        // Le code PIN Cenelis Connect n'est JAMAIS persisté d'un lancement à l'autre : il est exigé à CHAQUE lancement de l'application
        self.isPinVerifiedForCurrentLaunch = false

        if let localProg = AcademyAPIClient.shared.loadLocalProgress() {
            self.progress = localProg
        }
    }

    // MARK: - Démarrage Sécurisé & Vérification d'Accès avec https://academy.prod.cenelis.com

    public func bootstrapOnLaunch() async {
        // 1. Aucun jeton : charger les dernières CGU puis basculer immédiatement sur la connexion obligatoire
        if mobileToken.isEmpty {
            if let cguRes = try? await AcademyAPIClient.shared.fetchCGU(token: nil) {
                self.cguDocument = cguRes.cgu
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                self.isInitialBooting = false
            }
            return
        }

        // 2. Jeton présent : vérifier la session, l'habilitation interne/externe Cenelis et la version des CGU
        await refreshSessionAndCGU()

        withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
            self.isInitialBooting = false
        }

        triggerAutoPinIfNeeded()
    }

    public func refreshSessionAndCGU() async {
        guard !mobileToken.isEmpty else {
            learner = AcademyLearnerProfile()
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let me = try await AcademyAPIClient.shared.fetchMe(token: mobileToken)
            self.isOfflineMode = false
            if !me.authenticated {
                logout()
                return
            }
            let profile = me.learnerProfile
            self.learner = profile
            persistLearnerIdentity(profile, token: mobileToken)
            if let srvCgu = me.cgu {
                self.cguDocument = srvCgu
            }
            if let acc = me.cguAcceptance {
                self.serverCguAcceptance = acc
            }
        } catch let apiError as AcademyAPIError where apiError.isSessionTerminated {
            logout(remoteRevocationMessage: apiError.errorDescription)
        } catch {
            self.isOfflineMode = true
            self.pinGateMessage = "Connexion réseau requise pour vérifier votre habilitation et votre code PIN Cenelis Connect."
        }
    }

    public func refreshCatalogAndSync(silent: Bool = false) async {
        guard learner.authenticated, learner.hasCenelisAccess, !mobileToken.isEmpty else {
            return
        }
        if !silent { isSyncing = true }
        defer { isSyncing = false }

        do {
            let livePayload = try await AcademyAPIClient.shared.fetchBootstrap(
                token: mobileToken,
                includeHidden: true
            )
            self.catalog = livePayload
            self.isOfflineMode = false

            if let srvLearner = livePayload.learner, srvLearner.authenticated {
                self.learner = srvLearner
                persistLearnerIdentity(srvLearner, token: mobileToken)
            }
            if let srvCgu = livePayload.cgu {
                self.cguDocument = srvCgu
            }
            if let srvAcc = livePayload.cguAcceptance {
                self.serverCguAcceptance = srvAcc
            }
            if let cloudProg = livePayload.progress {
                self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
            }

            refreshDailyStreakOnVisit()
            evaluateTrophies(silent: true)
            AcademyAPIClient.shared.saveLocalProgress(self.progress)

            _ = await AcademyAPIClient.shared.pushCloudProgress(self.progress, token: mobileToken)
            self.lastSyncStatus = "Synchronisé · v\(livePayload.contentVersion.prefix(8))"
            refreshDailyNotificationState(requestAuthIfNeeded: true)
        } catch let apiError as AcademyAPIError where apiError.isSessionTerminated {
            logout(remoteRevocationMessage: apiError.errorDescription)
        } catch AcademyAPIError.forbiddenCenelisPermission(let srvProfile) {
            if let srvProfile {
                self.learner = srvProfile
            } else {
                self.learner.hasCenelisAccess = false
                self.learner.permissionScope = "none"
            }
            persistLearnerIdentity(self.learner, token: mobileToken)
        } catch {
            if self.catalog.courses.isEmpty, let cachedCat = AcademyAPIClient.shared.loadCachedBootstrap() {
                self.catalog = hydrateBubblesIfNeeded(cachedCat)
            }
            self.isOfflineMode = true
            self.lastSyncStatus = catalog.courses.isEmpty
                ? "Hors-ligne — vérifiez votre connexion Internet"
                : "Mode hors-ligne actif (cache local intégral)"
            refreshDailyNotificationState(requestAuthIfNeeded: false)
        }
    }

    private func hydrateBubblesIfNeeded(_ payload: AcademyBootstrapPayload) -> AcademyBootstrapPayload {
        var copy = payload
        var out: [String: AcademyBubble] = [:]
        for (k, var v) in copy.bubbles {
            v.key = k
            out[k] = v
        }
        copy.bubbles = out
        return copy
    }

    // MARK: - Acceptation Obligatoire des CGU (Premier Lancement ou Modification)

    public func acceptCurrentCGU() async throws {
        guard learner.authenticated, learner.hasCenelisAccess, !mobileToken.isEmpty else {
            throw AcademyAPIError.unauthorized
        }
        isSyncing = true
        defer { isSyncing = false }

        let targetVersion = cguDocument.version
        let targetHash = cguDocument.contentHash
        let res = try await AcademyAPIClient.shared.acceptCGU(
            version: targetVersion,
            contentHash: targetHash,
            token: mobileToken
        )

        let acceptedVer = res.acceptedVersion ?? targetVersion
        let acceptedHash = res.acceptedHash ?? targetHash
        let acceptedAt = res.acceptedAtUtc ?? ISO8601DateFormatter().string(from: Date())

        AcademyAPIClient.shared.saveLocalCGUAcceptance(
            forEmail: learner.email,
            version: acceptedVer,
            hash: acceptedHash,
            acceptedAt: acceptedAt
        )
        self.serverCguAcceptance = AcademyCGUAcceptanceStatus(
            accepted: true,
            requiresAcceptance: false,
            acceptedVersion: acceptedVer,
            acceptedHash: acceptedHash,
            acceptedAtUtc: acceptedAt
        )
        AcademyHaptics.success()

        if isPinVerifiedForCurrentLaunch {
            if catalog.courses.isEmpty {
                await refreshCatalogAndSync(silent: false)
            }
            if let deferred = pendingDeepLinkItems {
                pendingDeepLinkItems = nil
                applyDeepLinkNavigation(items: deferred)
            }
            return
        }

        // Dès l'acceptation des CGU, déclencher automatiquement l'ouverture du code PIN Cenelis Connect dans Safari In-App
        hasAutoOpenedPinInCurrentGateEntry = false
        triggerAutoPinIfNeeded()
    }

    // MARK: - Code PIN Cenelis Connect via Safari In-App (À CHAQUE LANCEMENT DE L'APPLICATION)

    public func triggerAutoPinIfNeeded() {
        guard !isProcessingIncomingHandoff else { return }
        guard activeSecurityGate == .pinVerificationRequired else { return }
        guard !hasAutoOpenedPinInCurrentGateEntry else { return }
        hasAutoOpenedPinInCurrentGateEntry = true
        openInAppCenelisConnectPin()
    }

    public func openInAppCenelisConnectPin() {
        guard learner.authenticated, learner.hasCenelisAccess, !mobileToken.isEmpty else { return }
        pinPollingTask?.cancel()
        pinGateMessage = nil

        let nonce = "iospin-" + UUID().uuidString.lowercased()
        guard let url = AcademyAPIClient.shared.buildPinLaunchURL(token: mobileToken, nonce: nonce) else {
            pinGateMessage = "Impossible d'initialiser l'URL Cenelis Connect PIN."
            return
        }

        activePinSafariItem = PinSafariLaunchItem(url: url, nonce: nonce)
        startPinVerificationWatcher(nonce: nonce)
    }

    public func handlePinSafariDismissedByUser() {
        pinPollingTask?.cancel()
        activePinSafariItem = nil
        if !isPinVerifiedForCurrentLaunch {
            pinGateMessage = "La validation de votre code PIN sur la page Cenelis Connect est requise à chaque ouverture de l'application pour accéder à Cenelis Academy."
        }
    }

    private func startPinVerificationWatcher(nonce: String) {
        let token = mobileToken
        pinPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.activePinSafariItem?.nonce == nonce else { return }

                if let status = await AcademyAPIClient.shared.checkPinLaunchStatus(nonce: nonce, token: token) {
                    if status.verified, let proof = status.proof, !proof.isEmpty {
                        await self.completePinUnlockForCurrentLaunch()
                        return
                    }
                    if status.expired == true {
                        self.activePinSafariItem = nil
                        self.pinGateMessage = "La demande de code PIN Cenelis Connect a expiré. Touchez le bouton ci-dessous pour rouvrir la page."
                        return
                    }
                }
            }
        }
    }

    private func completePinUnlockForCurrentLaunch() async {
        guard !isPinVerifiedForCurrentLaunch else { return }
        pinPollingTask?.cancel()
        AcademyHaptics.success()

        // Ferme automatiquement la page Safari In-App Cenelis Connect PIN et déverrouille l'accès !
        activePinSafariItem = nil
        pinGateMessage = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
            isPinVerifiedForCurrentLaunch = true
        }

        await refreshCatalogAndSync(silent: false)
        if let deferred = pendingDeepLinkItems {
            pendingDeepLinkItems = nil
            applyDeepLinkNavigation(items: deferred)
        }
    }

    // MARK: - Authentification Viple Live ID & SSO Mobile

    public func loginWithPassword(email: String, password: String) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let previousEmail = self.learner.email
        let res = try await AcademyAPIClient.shared.login(email: email, password: password)
        guard let token = res.token, !token.isEmpty else {
            throw AcademyAPIError.invalidResponse
        }

        self.shouldForceFreshSSOLogin = false
        self.isPinVerifiedForCurrentLaunch = false
        self.hasAutoOpenedPinInCurrentGateEntry = false
        self.mobileToken = token

        if let profile = res.learner {
            if !previousEmail.isEmpty && previousEmail.caseInsensitiveCompare(profile.email) != .orderedSame {
                self.progress = AcademyUserProgress()
                AcademyAPIClient.shared.saveLocalProgress(self.progress)
            }
            self.learner = profile
            persistLearnerIdentity(profile, token: token)
        }
        if let srvCgu = res.cgu {
            self.cguDocument = srvCgu
        }
        if let srvAcc = res.cguAcceptance {
            self.serverCguAcceptance = srvAcc
        }
        if let cloudProg = res.progress, self.learner.hasCenelisAccess {
            self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
            evaluateTrophies(silent: true)
            AcademyAPIClient.shared.saveLocalProgress(self.progress)
        }

        // Enregistrer immédiatement le nouvel apprenant actif sur cet appareil (purge tout ancien compte)
        if self.learner.hasCenelisAccess {
            await AcademyNotificationManager.shared.syncDeviceWithBackend(mobileToken: token, isExplicitLogin: true)
        }

        AcademyHaptics.success()
        isShowingAuthSheet = false
        triggerAutoPinIfNeeded()
    }

    public func handleSSOCallbackURL(_ url: URL) async {
        await handleIncomingURL(url)
    }

    public func handleIncomingURL(_ url: URL) async {
        guard url.scheme?.lowercased() == "cenelisacademy",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        let host = (url.host ?? "").lowercased()
        var items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if !host.isEmpty {
            items["__host"] = host
        }

        // 0. Inter-App SSO & Bypass silencieux du PIN depuis « Cenelis Workspace / Admin Hub »
        if let bypassToken = items["pin_bypass_token"], !bypassToken.isEmpty {
            isProcessingIncomingHandoff = true
            pinPollingTask?.cancel()
            activePinSafariItem = nil
            pinGateMessage = nil
            defer { isProcessingIncomingHandoff = false }

            do {
                let previousEmail = self.learner.email
                let res = try await AcademyAPIClient.shared.redeemPinBypassToken(bypassToken)
                if let token = res.token, !token.isEmpty {
                    self.mobileToken = token
                    if let profile = res.learner {
                        if !previousEmail.isEmpty && previousEmail.caseInsensitiveCompare(profile.email) != .orderedSame {
                            self.progress = AcademyUserProgress()
                            AcademyAPIClient.shared.saveLocalProgress(self.progress)
                        }
                        self.learner = profile
                        persistLearnerIdentity(profile, token: token)
                    }
                    if self.learner.hasCenelisAccess {
                        await AcademyNotificationManager.shared.syncDeviceWithBackend(mobileToken: token, isExplicitLogin: true)
                    }
                }
                if let srvCgu = res.cgu {
                    self.cguDocument = srvCgu
                }
                if let srvAcc = res.cguAcceptance {
                    self.serverCguAcceptance = srvAcc
                    if srvAcc.accepted, !self.learner.email.isEmpty {
                        AcademyAPIClient.shared.saveLocalCGUAcceptance(
                            forEmail: self.learner.email,
                            version: srvAcc.acceptedVersion,
                            hash: srvAcc.acceptedHash,
                            acceptedAt: srvAcc.acceptedAtUtc
                        )
                    }
                }
                if let cloudProg = res.progress, self.learner.hasCenelisAccess {
                    self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
                    AcademyAPIClient.shared.saveLocalProgress(self.progress)
                }

                self.shouldForceFreshSSOLogin = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                    self.isInitialBooting = false
                    self.isPinVerifiedForCurrentLaunch = true
                }
                AcademyHaptics.success()

                if !requiresCGUAcceptance {
                    if catalog.courses.isEmpty {
                        await refreshCatalogAndSync(silent: false)
                    } else {
                        Task { await refreshCatalogAndSync(silent: true) }
                    }
                    applyDeepLinkNavigation(items: items)
                } else {
                    pendingDeepLinkItems = items
                }
                return
            } catch AcademyAPIError.forbiddenCenelisPermission(let srvProfile) {
                if let srvProfile { self.learner = srvProfile }
                self.isInitialBooting = false
                return
            } catch {
                // Si le jeton à usage unique est expiré, basculer proprement sur la navigation différée après PIN normal
                pendingDeepLinkItems = items
                if !isInitialBooting {
                    triggerAutoPinIfNeeded()
                }
                return
            }
        }

        // Navigation directe vers un cours / une section / l'accueil (y compris au tap sur une notification quotidienne)
        if host == "handoff" || host == "open" || host == "course" || host == "home" {
            if activeSecurityGate == .unlocked {
                if catalog.courses.isEmpty {
                    await refreshCatalogAndSync(silent: false)
                }
                applyDeepLinkNavigation(items: items)
            } else {
                pendingDeepLinkItems = items
            }
            return
        }

        // 1. Retour de validation du code PIN Cenelis Connect (pont de secours cenelisacademy://pin-verified)
        if host == "pin-verified" {
            guard items["ok"] == "1",
                  let nonce = items["nonce"], !nonce.isEmpty,
                  let proof = items["proof"], !proof.isEmpty else {
                return
            }
            if let status = await AcademyAPIClient.shared.checkPinLaunchStatus(nonce: nonce, token: mobileToken),
               status.verified, status.proof == proof {
                await completePinUnlockForCurrentLaunch()
            }
            return
        }

        // 2. Retour de connexion SSO Viple Live ID / Cenelis Connect (cenelisacademy://auth)
        guard items["ok"] == "1", let token = items["token"], !token.isEmpty else {
            AcademyHaptics.warning()
            return
        }

        let previousEmail = self.learner.email
        let email = items["email"] ?? ""
        let name = items["name"]?.isEmpty == false ? items["name"]! : email
        let cid = items["cid"] ?? ""
        let groups = (items["groups"] ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let hasAccess = items["hasAccess"] == "1"
        let scope = items["scope"]?.isEmpty == false ? items["scope"]! : (hasAccess ? "interne" : "none")
        let rbacStatus = items["status"] ?? (hasAccess ? "approved" : "unregistered")

        let profile = AcademyLearnerProfile(
            authenticated: true,
            email: email,
            displayName: name,
            cid: cid,
            groups: groups,
            hasCenelisAccess: hasAccess,
            permissionScope: scope,
            rbacStatus: rbacStatus
        )

        if !previousEmail.isEmpty && !email.isEmpty && previousEmail.caseInsensitiveCompare(email) != .orderedSame {
            self.progress = AcademyUserProgress()
            AcademyAPIClient.shared.saveLocalProgress(self.progress)
        }

        self.shouldForceFreshSSOLogin = false
        self.isPinVerifiedForCurrentLaunch = false
        self.hasAutoOpenedPinInCurrentGateEntry = false
        self.mobileToken = token
        self.learner = profile
        persistLearnerIdentity(profile, token: token)

        // Enregistrer immédiatement le nouvel apprenant actif AVANT /me afin d'effacer toute ancienne révocation ou compte précédent
        if hasAccess {
            await AcademyNotificationManager.shared.syncDeviceWithBackend(mobileToken: token, isExplicitLogin: true)
        }

        await refreshSessionAndCGU()

        AcademyHaptics.success()
        isShowingAuthSheet = false
        triggerAutoPinIfNeeded()
    }

    private func clearStoredCredentialsOnly() {
        cloudPushTask?.cancel()
        pinPollingTask?.cancel()
        activePinSafariItem = nil
        isPinVerifiedForCurrentLaunch = false
        hasAutoOpenedPinInCurrentGateEntry = false
        mobileToken = ""
        learner = AcademyLearnerProfile()
        serverCguAcceptance = nil
        UserDefaults.standard.removeObject(forKey: "ca.mobileToken")
        UserDefaults.standard.removeObject(forKey: "ca.learnerEmail")
        UserDefaults.standard.removeObject(forKey: "ca.learnerName")
        UserDefaults.standard.removeObject(forKey: "ca.learnerCid")
        UserDefaults.standard.removeObject(forKey: "ca.learnerGroups")
        UserDefaults.standard.removeObject(forKey: "ca.learnerHasAccess")
        UserDefaults.standard.removeObject(forKey: "ca.learnerScope")
        UserDefaults.standard.removeObject(forKey: "ca.learnerRbacStatus")
        sharedSuite?.removeObject(forKey: "ca.mobileToken")
        sharedSuite?.removeObject(forKey: "viple.shared.email")
    }

    public func logout(remoteRevocationMessage: String? = nil) {
        AcademyHaptics.medium()
        // Capturer oldToken et oldEmail AVANT de vider mobileToken et l'identité locale
        let oldToken = mobileToken
        let oldEmail = learner.email
        let oldCid = learner.cid

        // Annuler immédiatement tous les rappels locaux hors-ligne (18h30), notifications délivrées, badge et BGAppRefreshTask
        AcademyNotificationManager.shared.cancelAllLocalNotificationsImmediately()

        activeCourseId = nil
        clearStoredCredentialsOnly()
        catalog = AcademyBootstrapPayload()
        shouldForceFreshSSOLogin = true

        Task {
            await AcademyNotificationManager.shared.unregisterDeviceOnLogout(
                token: oldToken,
                email: oldEmail,
                cid: oldCid
            )
        }

        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                let dom = cookie.domain.lowercased()
                if dom.contains("cenelis.") || dom.contains("viple") || dom.contains("livria") {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
        }
        lastSyncStatus = remoteRevocationMessage ?? "Session déconnectée"
    }

    private func persistLearnerIdentity(_ profile: AcademyLearnerProfile, token: String) {
        UserDefaults.standard.set(token, forKey: "ca.mobileToken")
        UserDefaults.standard.set(profile.email, forKey: "ca.learnerEmail")
        UserDefaults.standard.set(profile.displayName, forKey: "ca.learnerName")
        UserDefaults.standard.set(profile.cid, forKey: "ca.learnerCid")
        UserDefaults.standard.set(profile.groups, forKey: "ca.learnerGroups")
        UserDefaults.standard.set(profile.hasCenelisAccess, forKey: "ca.learnerHasAccess")
        UserDefaults.standard.set(profile.permissionScope, forKey: "ca.learnerScope")
        UserDefaults.standard.set(profile.rbacStatus, forKey: "ca.learnerRbacStatus")
        sharedSuite?.set(token, forKey: "ca.mobileToken")
        sharedSuite?.set(profile.email, forKey: "viple.shared.email")
    }

    // MARK: - Accès Rapides Catalogue & Cours

    public var visibleHomeCourses: [AcademyCourse] {
        catalog.courses.filter { !$0.hiddenFromHome }
    }

    public var customerGuideCourses: [AcademyCourse] {
        catalog.courses.filter { $0.hiddenFromHome || $0.isCustomerGuide }
    }

    public var activeCourse: AcademyCourse? {
        guard let id = activeCourseId else { return nil }
        return catalog.courses.first(where: { $0.id == id })
    }

    public var resumeCandidateCourse: AcademyCourse? {
        // Prioriser le dernier cours entamé non encore certifié à 100 %
        let visible = visibleHomeCourses
        if let inProgress = visible.first(where: { c in
            let done = c.parts.filter { progress.completedParts[$0.id] != nil }.count
            return done > 0 && courseConsolidatedPct(c) < 100
        }) {
            return inProgress
        }
        return visible.first(where: { $0.isFlagshipOnboarding }) ?? visible.first
    }

    public func openCourse(_ courseId: String, stepIndex: Int? = nil) {
        guard let course = catalog.courses.first(where: { $0.id == courseId }) else { return }
        AcademyHaptics.medium()
        let maxIdx = course.parts.count // parts.count == écran d'Évaluation Finale
        let target: Int
        if let stepIndex {
            target = min(max(0, stepIndex), maxIdx)
        } else if let saved = progress.lastStep[courseId] {
            target = min(max(0, saved), maxIdx)
        } else {
            target = 0
        }
        activeStepIndex = target
        progress.lastStep[courseId] = target
        activeCourseId = courseId
        saveAndScheduleCloudSync()
    }

    public func closeCourseReader() {
        AcademyHaptics.light()
        activeCourseId = nil
    }

    public func applyDeepLinkNavigation(items: [String: String]) {
        isShowingSearch = false
        activeBubble = nil
        activeDeepDive = nil

        let resolvedCourseId = [items["course"], items["id"], items["courseId"]]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        if let courseId = resolvedCourseId,
           let course = catalog.courses.first(where: { $0.id.caseInsensitiveCompare(courseId) == .orderedSame }) {
            var resolvedStep: Int? = nil

            if let section = items["section"], !section.isEmpty {
                if let partIdx = course.parts.firstIndex(where: { $0.id.caseInsensitiveCompare(section) == .orderedSame }) {
                    resolvedStep = partIdx
                } else if let numericStep = Int(section) {
                    resolvedStep = numericStep
                }
            }
            if resolvedStep == nil, let stepRaw = items["step"], let sIdx = Int(stepRaw) {
                resolvedStep = sIdx
            }
            if resolvedStep == nil, let chapRaw = items["chapter"], let chNum = Int(chapRaw),
               let chIdx = course.parts.firstIndex(where: { $0.chapter == chNum }) {
                resolvedStep = chIdx
            }

            activeTab = .courses
            openCourse(course.id, stepIndex: resolvedStep)
            return
        }

        if let diveId = items["deep_dive"], !diveId.isEmpty,
           let dive = catalog.deepDives.first(where: { $0.id.caseInsensitiveCompare(diveId) == .orderedSame }) {
            activeCourseId = nil
            activeTab = .home
            activeDeepDive = dive
            return
        }

        if let bubKey = items["bubble"], !bubKey.isEmpty,
           let bub = catalog.bubbles[bubKey] {
            activeCourseId = nil
            activeBubble = bub
            return
        }

        if let resTab = items["resource_tab"], !resTab.isEmpty {
            activeCourseId = nil
            preselectedResourceTabId = resTab
            activeTab = .resources
            return
        }

        if items["__host"] == "home" || items["tab"] == "home" {
            activeCourseId = nil
            activeTab = .home
            return
        }
    }

    public func setStepIndex(_ newIndex: Int, for course: AcademyCourse) {
        let clamped = min(max(0, newIndex), course.parts.count)
        activeStepIndex = clamped
        progress.lastStep[course.id] = clamped
        saveAndScheduleCloudSync()
    }

    // MARK: - Métriques de Maîtrise par Cours

    public func completedPartsCount(for course: AcademyCourse) -> Int {
        course.parts.filter { progress.completedParts[$0.id] != nil }.count
    }

    public func readingProgressFraction(for course: AcademyCourse) -> Double {
        guard !course.parts.isEmpty else { return 0 }
        let pagesRatio = Double(completedPartsCount(for: course)) / Double(course.parts.count)
        let quizBonus = isCourseCertified(course) ? 0.15 : 0.0
        return min(1.0, pagesRatio * 0.85 + quizBonus)
    }

    public func courseReadingPercent(_ course: AcademyCourse) -> Int {
        guard !course.parts.isEmpty else { return 0 }
        let pagesPct = Double(completedPartsCount(for: course)) / Double(course.parts.count) * 100.0
        return min(100, Int(pagesPct.rounded()))
    }

    public func courseConsolidatedPct(_ course: AcademyCourse) -> Int {
        if let rec = progress.courseScores[course.id] {
            return max(rec.consolidatedPct, rec.bestConsolidatedPct)
        }
        if let passed = progress.passedQuizzes[course.id] {
            return passed.effectivePct
        }
        return 0
    }

    public func isCourseCertified(_ course: AcademyCourse) -> Bool {
        if let rec = progress.courseScores[course.id], rec.apte {
            return true
        }
        if let passed = progress.passedQuizzes[course.id] {
            return passed.effectivePct >= course.passThresholdPct
        }
        return false
    }

    public func isPartCompleted(_ partId: String) -> Bool {
        progress.completedParts[partId] != nil
    }

    public func isPartMarkedUnclear(_ partId: String) -> Bool {
        progress.unclearPoints[partId] != nil
    }

    public func isPartBookmarked(_ partId: String) -> Bool {
        progress.bookmarkedParts[partId] == true
    }

    public func isVideoWatched(_ videoId: String) -> Bool {
        progress.watchedVideos[videoId] != nil
    }

    public func markVideoWatched(_ videoId: String) {
        guard !videoId.isEmpty else { return }
        let isFirst = (progress.watchedVideos[videoId] == nil)
        progress.watchedVideos[videoId] = Date().timeIntervalSince1970 * 1000
        if isFirst {
            AcademyHaptics.success()
            awardXP(30, reason: "Capsule vidéo visionnée", isMajor: false)
            evaluateTrophies(silent: false)
        }
        saveAndScheduleCloudSync()
    }

    // MARK: - Actions du Lecteur de Cours (Validation Page, Bulles, Approfondissements)

    public func completePartAndAdvance(in course: AcademyCourse) {
        guard course.parts.indices.contains(activeStepIndex) else { return }
        let part = course.parts[activeStepIndex]
        let isFirstTime = (progress.completedParts[part.id] == nil)

        progress.completedParts[part.id] = Date().timeIntervalSince1970 * 1000
        if isFirstTime {
            AcademyHaptics.success()
            awardXP(25, reason: "Page assimilée", isMajor: false)
        } else {
            AcademyHaptics.selection()
        }

        let nextIdx = min(activeStepIndex + 1, course.parts.count)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            activeStepIndex = nextIdx
        }
        progress.lastStep[course.id] = nextIdx
        evaluateTrophies(silent: false)
        refreshDailyNotificationState(requestAuthIfNeeded: false)
        saveAndScheduleCloudSync()
    }

    public func toggleUnclearPoint(_ partId: String) {
        AcademyHaptics.selection()
        if progress.unclearPoints[partId] != nil {
            progress.unclearPoints.removeValue(forKey: partId)
        } else {
            progress.unclearPoints[partId] = Date().timeIntervalSince1970 * 1000
        }
        saveAndScheduleCloudSync()
    }

    public func toggleBookmark(_ partId: String) {
        AcademyHaptics.light()
        if progress.bookmarkedParts[partId] == true {
            progress.bookmarkedParts.removeValue(forKey: partId)
        } else {
            progress.bookmarkedParts[partId] = true
        }
        saveAndScheduleCloudSync()
    }

    public func openBubble(key: String, fallbackLabel: String? = nil) {
        AcademyHaptics.light()
        let rawKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases: [String: String] = [
            "loi_lang": "prix_unique_livre"
        ]
        let cleanKey = aliases[rawKey] ?? rawKey
        if let found = catalog.bubbles[cleanKey] ?? catalog.bubbles[rawKey] {
            let firstDiscovery = progress.exploredBubbles[cleanKey] != true
            progress.exploredBubbles[cleanKey] = true
            activeBubble = found
            if firstDiscovery {
                awardXP(10, reason: "Bulle vulgarisée découverte", isMajor: false)
                evaluateTrophies(silent: false)
            } else {
                saveAndScheduleCloudSync()
            }
        } else if let fallbackLabel {
            activeBubble = AcademyBubble(
                key: cleanKey,
                q: "C'est quoi « \(fallbackLabel) » ?",
                title: fallbackLabel,
                analogy: "Un repère concret de l'écosystème Cenelis conçu pour rester simple et accessible à tous.",
                def: "Consultez le Glossaire A–Z dans l'onglet Ressources pour retrouver la définition complète associée à « \(fallbackLabel) ».",
                why: "Chez Cenelis, chaque terme technique est toujours accompagné d'une explication claire."
            )
        }
    }

    public func openDeepDive(id: String) {
        guard let found = catalog.deepDives.first(where: { $0.id == id }) else { return }
        AcademyHaptics.medium()
        activeDeepDive = found
    }

    public func completeDeepDiveLevel(dive: AcademyDeepDive, level: Int) {
        var rec = progress.deepDives[dive.id] ?? AcademyDeepDiveProgressRecord(maxLevel: 1, completed: [:])
        let key = "\(level)"
        let wasCompleted = rec.completed[key] != nil
        rec.completed[key] = Date().timeIntervalSince1970 * 1000
        rec.maxLevel = max(rec.maxLevel, min(dive.levels.count, level + 1))
        progress.deepDives[dive.id] = rec

        if !wasCompleted {
            AcademyHaptics.success()
            let bonus = (level == dive.levels.count) ? 65 : 35
            awardXP(bonus, reason: "Palier \(level)/\(dive.levels.count) débloqué", isMajor: level == dive.levels.count)
            if level == dive.levels.count {
                confettiTrigger += 1
            }
        } else {
            AcademyHaptics.selection()
        }

        evaluateTrophies(silent: false)
        saveAndScheduleCloudSync()
    }

    public func toggleSopStep(stepKey: String) {
        AcademyHaptics.selection()
        let wasChecked = progress.checkedSopSteps[stepKey] == true
        if wasChecked {
            progress.checkedSopSteps.removeValue(forKey: stepKey)
        } else {
            progress.checkedSopSteps[stepKey] = true
            awardXP(5, reason: "Étape SOP vérifiée", isMajor: false)
        }
        saveAndScheduleCloudSync()
    }

    // MARK: - Évaluation Finale, Notation 80 % « Apte » & Rattrapage Lacune par Lacune vers 100 %

    @discardableResult
    public func submitCourseQuiz(course: AcademyCourse, answers: [Int: Int]) -> AcademyCourseScoreRecord {
        let total = max(1, course.quiz.count)
        var directScore = 0
        var serializedAnswers: [String: Int] = [:]

        for (idx, q) in course.quiz.enumerated() {
            if let chosen = answers[idx] {
                serializedAnswers["\(idx)"] = chosen
                if chosen == q.correct {
                    directScore += 1
                }
            }
        }

        let prev = progress.courseScores[course.id]
        var remediated = prev?.remediatedIndices ?? [:]
        // Toute question désormais réussie en direct n'a plus besoin de rattrapage
        for (idx, q) in course.quiz.enumerated() where answers[idx] == q.correct {
            remediated.removeValue(forKey: "\(idx)")
        }

        var consolidatedScore = 0
        for (idx, q) in course.quiz.enumerated() {
            if answers[idx] == q.correct || remediated["\(idx)"] == true {
                consolidatedScore += 1
            }
        }

        let directPct = Int((Double(directScore) / Double(total) * 100.0).rounded())
        let consolidatedPct = Int((Double(consolidatedScore) / Double(total) * 100.0).rounded())
        let isApte = consolidatedPct >= course.passThresholdPct

        let record = AcademyCourseScoreRecord(
            lastDirectScore: directScore,
            lastDirectPct: directPct,
            consolidatedScore: consolidatedScore,
            consolidatedPct: consolidatedPct,
            total: total,
            bestDirectPct: max(prev?.bestDirectPct ?? 0, directPct),
            bestConsolidatedPct: max(prev?.bestConsolidatedPct ?? 0, consolidatedPct),
            apte: (prev?.apte == true) || isApte,
            attempts: (prev?.attempts ?? 0) + 1,
            remediatedIndices: remediated,
            lastAnswers: serializedAnswers,
            updatedAt: Date().timeIntervalSince1970 * 1000
        )

        progress.courseScores[course.id] = record

        if record.apte {
            progress.passedQuizzes[course.id] = AcademyPassedQuizRecord(
                score: consolidatedScore,
                total: total,
                pct: consolidatedPct
            )
        }

        let wasAlreadyCertified = prev?.apte == true
        if isApte && !wasAlreadyCertified {
            AcademyHaptics.success()
            confettiTrigger += 1
            awardXP(300, reason: "Apte à rejoindre Cenelis (\(consolidatedPct) %)", isMajor: true)
        } else if directScore > 0 {
            AcademyHaptics.medium()
            awardXP(90, reason: "Tentative d'évaluation complétée", isMajor: false)
        }

        evaluateTrophies(silent: false)
        saveAndScheduleCloudSync()
        return record
    }

    public func validateRemediationQuestion(course: AcademyCourse, questionIndex: Int, chosenOption: Int) -> Bool {
        guard course.quiz.indices.contains(questionIndex),
              let rem = course.quiz[questionIndex].remediation else {
            return false
        }

        guard chosenOption == rem.correct else {
            AcademyHaptics.error()
            return false
        }

        var rec = progress.courseScores[course.id] ?? AcademyCourseScoreRecord(total: course.quiz.count)
        let key = "\(questionIndex)"
        let alreadyRemediated = rec.remediatedIndices[key] == true
        rec.remediatedIndices[key] = true

        let total = max(1, course.quiz.count)
        var consolidated = 0
        for (idx, q) in course.quiz.enumerated() {
            let directChoice = rec.lastAnswers["\(idx)"]
            if directChoice == q.correct || rec.remediatedIndices["\(idx)"] == true {
                consolidated += 1
            }
        }

        let consolidatedPct = Int((Double(consolidated) / Double(total) * 100.0).rounded())
        let becameApte = !rec.apte && (consolidatedPct >= course.passThresholdPct)
        let reached100 = (rec.consolidatedPct < 100) && (consolidatedPct == 100)

        rec.consolidatedScore = consolidated
        rec.consolidatedPct = consolidatedPct
        rec.bestConsolidatedPct = max(rec.bestConsolidatedPct, consolidatedPct)
        if consolidatedPct >= course.passThresholdPct {
            rec.apte = true
            progress.passedQuizzes[course.id] = AcademyPassedQuizRecord(
                score: consolidated,
                total: total,
                pct: consolidatedPct
            )
        }
        rec.updatedAt = Date().timeIntervalSince1970 * 1000
        progress.courseScores[course.id] = rec

        AcademyHaptics.success()
        if !alreadyRemediated {
            if reached100 {
                confettiTrigger += 1
                awardXP(150, reason: "Maîtrise intégrale 100 % atteinte !", isMajor: true)
            } else if becameApte {
                confettiTrigger += 1
                awardXP(200, reason: "Seuil d'aptitude \(course.passThresholdPct) % franchi !", isMajor: true)
            } else {
                awardXP(40, reason: "Lacune comblée (+1 point consolidé)", isMajor: false)
            }
        }

        evaluateTrophies(silent: false)
        saveAndScheduleCloudSync()
        return true
    }

    // MARK: - Gamification : XP, Rangs, Série Quotidienne & Arcade Mini-Jeux

    public var currentRank: AcademyRank {
        AcademyRank.current(forXP: progress.xp)
    }

    public var todayKey: String {
        Self.dayString(from: Date())
    }

    public var todayEarnedXP: Int {
        progress.dailyXPEarnedByDay[todayKey] ?? 0
    }

    public var dailyGoalFraction: Double {
        let goal = max(30, progress.dailyGoalXP)
        return min(1.0, Double(todayEarnedXP) / Double(goal))
    }

    public func awardXP(_ amount: Int, reason: String, isMajor: Bool) {
        guard amount > 0 else { return }
        let oldRank = currentRank
        progress.xp += amount
        let day = todayKey
        progress.dailyXPEarnedByDay[day, default: 0] += amount
        refreshDailyStreakOnVisit()

        let newRank = currentRank
        if newRank.level > oldRank.level {
            confettiTrigger += 1
            showXPToast(amount: amount, label: "Nouveau rang : \(newRank.title) !", isMajor: true)
        } else {
            showXPToast(amount: amount, label: reason, isMajor: isMajor)
        }
        refreshDailyNotificationState(requestAuthIfNeeded: false)
    }

    public func recordMiniGameCompletion(kind: MiniGameKind, score: Int, maxCombo: Int, accuracyPct: Int) {
        var rec = progress.miniGameRecords[kind.rawValue] ?? MiniGameScoreRecord()
        rec.plays += 1
        rec.highScore = max(rec.highScore, score)
        rec.bestStreak = max(rec.bestStreak, maxCombo)
        rec.lastPlayedDay = todayKey
        progress.miniGameRecords[kind.rawValue] = rec

        let accuracyBonus = max(0, (accuracyPct - 50))
        let earnedXP = max(35, kind.baseXPReward + accuracyBonus)

        if accuracyPct >= 80 {
            AcademyHaptics.success()
            confettiTrigger += 1
        } else {
            AcademyHaptics.medium()
        }

        awardXP(earnedXP, reason: "\(kind.title) terminé", isMajor: accuracyPct >= 80)
        evaluateTrophies(silent: false)
        saveAndScheduleCloudSync()
    }

    private func refreshDailyStreakOnVisit() {
        let today = todayKey
        if progress.lastActiveDay == today { return }

        if progress.lastActiveDay.isEmpty {
            progress.streakDays = max(1, progress.streakDays)
            progress.lastActiveDay = today
            return
        }

        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"

        if let prevDate = fmt.date(from: progress.lastActiveDay),
           let curDate = fmt.date(from: today) {
            let diff = Calendar(identifier: .gregorian).dateComponents([.day], from: prevDate, to: curDate).day ?? 0
            if diff == 1 {
                progress.streakDays += 1
            } else if diff == 2 && progress.streakShields > 0 {
                // Bouclier de série bienveillant : sauve automatiquement 1 journée d'absence
                progress.streakShields -= 1
                progress.streakDays += 1
            } else if diff > 1 {
                progress.streakDays = 1
            }
        } else {
            progress.streakDays = max(1, progress.streakDays)
        }
        progress.lastActiveDay = today
    }

    private func evaluateTrophies(silent: Bool) {
        let nowMs = Date().timeIntervalSince1970 * 1000
        var newlyUnlocked: [AcademyTrophy] = []

        func check(_ id: String, condition: Bool) {
            guard condition, progress.unlockedBadges[id] == nil else { return }
            progress.unlockedBadges[id] = nowMs
            if let trophy = AcademyTrophy.catalog.first(where: { $0.id == id }) {
                newlyUnlocked.append(trophy)
            }
        }

        let pagesCount = progress.completedParts.count
        let bubblesCount = progress.exploredBubbles.values.filter { $0 }.count
        let hasTier5 = progress.deepDives.values.contains { $0.completed.count >= 5 }
        let totalArcadePlays = progress.miniGameRecords.values.reduce(0) { $0 + $1.plays }
        let bestSwipeCombo = progress.miniGameRecords[MiniGameKind.swipeBlitz.rawValue]?.bestStreak ?? 0
        let playedAll5Games = MiniGameKind.allCases.allSatisfy { (progress.miniGameRecords[$0.rawValue]?.plays ?? 0) >= 1 }
        let hasApte80 = progress.courseScores.values.contains { $0.apte && $0.bestConsolidatedPct >= 80 }
            || progress.passedQuizzes.values.contains { $0.effectivePct >= 80 }
        let hasMastery100 = progress.courseScores.values.contains { $0.bestConsolidatedPct >= 100 }
        let mainCourses = visibleHomeCourses
        let allCertified = !mainCourses.isEmpty && mainCourses.allSatisfy { isCourseCertified($0) }

        check("first_page", condition: pagesCount >= 1)
        check("curious_bubbles_5", condition: bubblesCount >= 5)
        check("pages_20", condition: pagesCount >= 20)
        check("streak_3", condition: progress.streakDays >= 3)
        check("deepdive_tier5", condition: hasTier5)
        check("arcade_first_win", condition: totalArcadePlays >= 1)
        check("swipe_combo_8", condition: bestSwipeCombo >= 8)
        check("apte_80", condition: hasApte80)
        check("mastery_100", condition: hasMastery100)
        check("arcade_all_5", condition: playedAll5Games)
        check("pages_72", condition: pagesCount >= 72)
        check("all_courses_certified", condition: allCertified)

        if !newlyUnlocked.isEmpty {
            let bonusSum = newlyUnlocked.reduce(0) { $0 + $1.xpBonus }
            progress.xp += bonusSum
            if !silent, let first = newlyUnlocked.first {
                confettiTrigger += 1
                showXPToast(amount: bonusSum, label: "Trophée : \(first.title)", isMajor: true)
            }
        }
    }

    private func showXPToast(amount: Int, label: String, isMajor: Bool) {
        let item = XPToastItem(amount: amount, label: label, isMajor: isMajor)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            xpToast = item
        }
        let itemId = item.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if self.xpToast?.id == itemId {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.xpToast = nil
                }
            }
        }
    }

    private func saveAndScheduleCloudSync() {
        AcademyAPIClient.shared.saveLocalProgress(progress)
        guard learner.authenticated, learner.hasCenelisAccess, isPinVerifiedForCurrentLaunch, !mobileToken.isEmpty else { return }

        cloudPushTask?.cancel()
        let snapshot = progress
        let token = mobileToken
        cloudPushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            let ok = await AcademyAPIClient.shared.pushCloudProgress(snapshot, token: token)
            if ok {
                self.lastSyncStatus = "Progression sauvegardée dans le Cloud Cenelis"
            }
        }
    }

    // MARK: - Synchronisation des Rappels Quotidiens & APNs (.p8)

    public func refreshDailyNotificationState(requestAuthIfNeeded: Bool) {
        let isAuthorizedLearner = learner.authenticated && learner.hasCenelisAccess
        AcademyNotificationManager.shared.refreshLocalDailyReminder(
            catalog: catalog,
            progress: progress,
            isAuthenticated: isAuthorizedLearner
        )
        AcademyNotificationManager.shared.scheduleNextBackgroundRefresh()

        guard isAuthorizedLearner, !mobileToken.isEmpty else { return }
        let token = mobileToken
        if requestAuthIfNeeded && activeSecurityGate == .unlocked {
            Task { @MainActor in
                await AcademyNotificationManager.shared.requestPermissionsAndRegisterIfNeeded(mobileToken: token)
            }
        }
    }

    private func handleNotificationPreferencesUpdated() {
        refreshDailyNotificationState(requestAuthIfNeeded: dailyRemindersEnabled)
        guard learner.authenticated, learner.hasCenelisAccess, !mobileToken.isEmpty else { return }
        let token = mobileToken
        Task { @MainActor in
            await AcademyNotificationManager.shared.syncDeviceWithBackend(mobileToken: token, isExplicitLogin: false)
        }
    }

    // MARK: - Recherche Globale Instantanée (Cours, Bulles, Approfondissements, Encyclopédie & Glossaire)

    public func searchEverywhere(query: String) -> [GlobalSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let needle = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))

        func matches(_ text: String) -> Bool {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).contains(needle)
        }

        var results: [GlobalSearchResult] = []

        // 1. Bulles vulgarisées « C'est quoi … ? »
        for (key, bubble) in catalog.bubbles {
            if matches(bubble.title) || matches(bubble.q) || matches(bubble.def) || matches(bubble.analogy) {
                results.append(GlobalSearchResult(
                    id: "bub-\(key)",
                    kind: "Bulle vulgarisée",
                    icon: "text.bubble.fill",
                    title: bubble.title.isEmpty ? bubble.q : bubble.title,
                    snippet: AcademyRichTextParser.plainText(bubble.analogy),
                    actionCourseId: nil,
                    actionPartIndex: nil,
                    actionBubbleKey: key,
                    actionDeepDiveId: nil,
                    actionResourceTabId: nil
                ))
            }
        }

        // 2. Pages de cours & Capsules vidéo
        for course in catalog.courses {
            for (idx, part) in course.parts.enumerated() {
                let bodyConcat = part.blocks.flatMap { b in
                    [b.heading ?? "", b.title ?? "", b.intro ?? "", b.text ?? ""] + b.paragraphs
                }.joined(separator: " ")
                let videoConcat = [part.video?.title ?? "", part.video?.transcript ?? ""].joined(separator: " ")

                if matches(part.title) || matches(part.summary) || matches(bodyConcat) || matches(videoConcat) {
                    results.append(GlobalSearchResult(
                        id: "part-\(course.id)-\(part.id)",
                        kind: course.number,
                        icon: AcademyIcons.sfSymbol(for: course.icon),
                        title: AcademyRichTextParser.plainText(part.title),
                        snippet: AcademyRichTextParser.plainText(part.summary),
                        actionCourseId: course.id,
                        actionPartIndex: idx,
                        actionBubbleKey: nil,
                        actionDeepDiveId: nil,
                        actionResourceTabId: nil
                    ))
                }
                if results.count >= 45 { break }
            }
        }

        // 3. Dossiers d'approfondissement (5 paliers)
        for dive in catalog.deepDives {
            if matches(dive.title) || matches(dive.subtitle) {
                results.append(GlobalSearchResult(
                    id: "dd-\(dive.id)",
                    kind: "Approfondissement 5 paliers",
                    icon: AcademyIcons.sfSymbol(for: dive.icon),
                    title: AcademyRichTextParser.plainText(dive.title),
                    snippet: AcademyRichTextParser.plainText(dive.subtitle),
                    actionCourseId: nil,
                    actionPartIndex: nil,
                    actionBubbleKey: nil,
                    actionDeepDiveId: dive.id,
                    actionResourceTabId: nil
                ))
            }
        }

        // 4. Encyclopédie & Glossaire A–Z
        for tab in catalog.resources {
            for card in tab.cards where matches(card.title) || matches(card.url) || matches(card.rbac) {
                results.append(GlobalSearchResult(
                    id: "rescard-\(tab.id)-\(card.id)",
                    kind: "Console /admin · \(tab.label)",
                    icon: "terminal.fill",
                    title: card.title,
                    snippet: "\(card.url) — \(card.rbac)",
                    actionCourseId: nil,
                    actionPartIndex: nil,
                    actionBubbleKey: nil,
                    actionDeepDiveId: nil,
                    actionResourceTabId: tab.id
                ))
            }
            for g in tab.glossary where matches(g.term) || matches(g.def) {
                results.append(GlobalSearchResult(
                    id: "glo-\(g.term)",
                    kind: "Glossaire · \(g.cat)",
                    icon: "character.book.closed.fill",
                    title: g.term,
                    snippet: g.def,
                    actionCourseId: nil,
                    actionPartIndex: nil,
                    actionBubbleKey: nil,
                    actionDeepDiveId: nil,
                    actionResourceTabId: tab.id
                ))
            }
        }

        return Array(results.prefix(50))
    }

    // MARK: - Fusion Non-Destructive Locale + Cloud

    public static func mergeProgress(local: AcademyUserProgress, cloud: AcademyUserProgress) -> AcademyUserProgress {
        var out = local

        for (k, v) in cloud.completedParts {
            out.completedParts[k] = max(out.completedParts[k] ?? 0, v)
        }
        for (k, v) in cloud.passedQuizzes {
            if let cur = out.passedQuizzes[k] {
                out.passedQuizzes[k] = v.effectivePct >= cur.effectivePct ? v : cur
            } else {
                out.passedQuizzes[k] = v
            }
        }
        for (k, v) in cloud.lastStep {
            out.lastStep[k] = max(out.lastStep[k] ?? 0, v)
        }
        for (k, v) in cloud.courseScores {
            if let cur = out.courseScores[k] {
                out.courseScores[k] = v.updatedAt >= cur.updatedAt ? v : cur
            } else {
                out.courseScores[k] = v
            }
        }
        for (k, v) in cloud.unclearPoints {
            out.unclearPoints[k] = v
        }
        for (k, v) in cloud.deepDives {
            if var cur = out.deepDives[k] {
                cur.maxLevel = max(cur.maxLevel, v.maxLevel)
                for (lk, lv) in v.completed { cur.completed[lk] = lv }
                out.deepDives[k] = cur
            } else {
                out.deepDives[k] = v
            }
        }

        out.xp = max(local.xp, cloud.xp)
        out.streakDays = max(local.streakDays, cloud.streakDays)
        if cloud.lastActiveDay > local.lastActiveDay {
            out.lastActiveDay = cloud.lastActiveDay
        }
        for (day, val) in cloud.dailyXPEarnedByDay {
            out.dailyXPEarnedByDay[day] = max(out.dailyXPEarnedByDay[day] ?? 0, val)
        }
        for (b, ts) in cloud.unlockedBadges {
            out.unlockedBadges[b] = min(out.unlockedBadges[b] ?? ts, ts)
        }
        for (g, rec) in cloud.miniGameRecords {
            if let cur = out.miniGameRecords[g] {
                out.miniGameRecords[g] = MiniGameScoreRecord(
                    highScore: max(cur.highScore, rec.highScore),
                    plays: max(cur.plays, rec.plays),
                    bestStreak: max(cur.bestStreak, rec.bestStreak),
                    lastPlayedDay: max(cur.lastPlayedDay, rec.lastPlayedDay)
                )
            } else {
                out.miniGameRecords[g] = rec
            }
        }
        for (b, seen) in cloud.exploredBubbles where seen { out.exploredBubbles[b] = true }
        for (b, mark) in cloud.bookmarkedParts where mark { out.bookmarkedParts[b] = true }
        for (s, chk) in cloud.checkedSopSteps where chk { out.checkedSopSteps[s] = true }
        for (vid, ts) in cloud.watchedVideos {
            out.watchedVideos[vid] = max(out.watchedVideos[vid] ?? 0, ts)
        }

        let floorXP = (out.completedParts.count * 25) + (out.passedQuizzes.count * 250) + (out.watchedVideos.count * 30)
        out.xp = max(out.xp, floorXP)
        return out
    }

    private static func dayString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
