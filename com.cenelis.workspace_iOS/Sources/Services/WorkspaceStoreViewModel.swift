import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel Principal « Cenelis Workspace / Admin Hub »

@MainActor
public final class WorkspaceStoreViewModel: ObservableObject {
    // 1. État de Sécurité & Authentification Viple Live ID + Cenelis Connect PIN
    @Published public var isBooting: Bool = true
    @Published public var workspaceToken: String = ""
    @Published public var operatorProfile: WorkspaceOperatorProfile = WorkspaceOperatorProfile()
    @Published public var rbacSnapshot: WorkspaceRbacSnapshot = WorkspaceRbacSnapshot()

    /// Verrouillage natif Cenelis Connect PIN : exigé à CHAQUE lancement ET à chaque retour d'arrière-plan
    @Published public private(set) var isPinUnlocked: Bool = false
    @Published public private(set) var pinProofToken: String = ""
    @Published public var pinErrorMessage: String? = nil
    @Published public var isVerifyingPin: Bool = false

    // 2. Navigation Centrale : Hub d'Accueil <-> Panel Web Encapsulé
    @Published public var isShowingHub: Bool = true
    @Published public var activePanel: AdminPanelItem? = nil
    public let webController = PanelWebController()

    // 3. Menu Flottant Natif `/admin` (Pastille Hamburger + Masquage Swipe Droite + Réaffichage Appui Long 2s)
    @Published public var isShowingNativeAdminSheet: Bool = false
    @Published public var isFloatingBurgerHidden: Bool = false
    @Published public var showHiddenBurgerHintToast: Bool = false

    // 3b. Lecteur Matériel Natif de Codes-Barres / ISBN (`window.webkit.messageHandlers.barcodeScanner` · Wingman)
    @Published public var activeBarcodeScanRequest: NativeBarcodeScanRequest? = nil

    // 4. Annuaire des Panels, Statuts de Santé & Recherche Multi-Onglets (Panels / Fonctions / Aide Academy)
    @Published public var allPanels: [AdminPanelItem] = EcosystemCatalogRegistry.fallbackPanels
    @Published public var panelHealthMap: [String: AdminPanelHealthStatus] = [:]
    @Published public var selectedCategory: String = "Tous"
    @Published public var hubDisplayAsList: Bool = false

    @Published public var searchQuery: String = "" {
        didSet {
            handleSearchQueryChanged()
        }
    }
    @Published public var searchScope: WorkspaceSearchScope = .panels {
        didSet {
            if searchScope == .academyHelp {
                triggerAcademyHelpSearch(immediate: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @Published public var academyHelpResults: [AcademyHelpSearchResult] = []
    @Published public var isSearchingAcademy: Bool = false
    @Published public var academyInstallAlertShown: Bool = false

    // Tâches de fond : Keepalive anti-coupure 1h, Recherche debouncée & Jeton Bypass PIN pré-chauffé
    private var hasEnteredBackgroundAtLeastOnce: Bool = false
    private var keepaliveTask: Task<Void, Never>?
    private var academySearchTask: Task<Void, Never>?
    private var prewarmedAcademyBypassToken: String? = nil
    private var prewarmedBypassCreatedAt: Date? = nil

    public var activeSecurityState: WorkspaceSecurityState {
        if isBooting { return .booting }
        if !operatorProfile.authenticated || workspaceToken.isEmpty { return .loginRequired }
        if !operatorProfile.isAdmin && !rbacSnapshot.isApprovedOperator { return .accessDenied }
        if !isPinUnlocked { return .pinLocked }
        return .unlocked
    }

    public init() {
        // Restaurer la session persistante Viple Live ID depuis le Trousseau Keychain, tout en laissant `isPinUnlocked = false`
        if let saved = WorkspaceWebSessionPool.shared.loadSavedWorkspaceCredentials() {
            self.workspaceToken = saved.token
            self.operatorProfile = saved.profile
        }
        self.isPinUnlocked = false
    }

    // MARK: - Démarrage & Cycle de Vie iOS (`scenePhase`)

    public func bootstrapOnLaunch() async {
        await WorkspaceWebSessionPool.shared.restoreMasterCookiesFromKeychainIfNeeded()

        // Synchroniser la liste exhaustive des panels `/admin` en parallèle
        async let directoryFetch = WorkspaceAPIClient.shared.fetchAdminDirectory()

        if !workspaceToken.isEmpty {
            await refreshOperatorAndRbacSession()
        }

        if let livePanels = await directoryFetch, !livePanels.isEmpty {
            self.allPanels = livePanels
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            self.isBooting = false
        }
    }

    public func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            hasEnteredBackgroundAtLeastOnce = true
            lockForBackgroundTransition()

        case .active:
            if hasEnteredBackgroundAtLeastOnce {
                hasEnteredBackgroundAtLeastOnce = false
                // Exiger systématiquement le code PIN Cenelis Connect au retour au premier plan
                if operatorProfile.authenticated && !workspaceToken.isEmpty {
                    isPinUnlocked = false
                    pinProofToken = ""
                    prewarmedAcademyBypassToken = nil
                    isShowingNativeAdminSheet = false
                }
            }

        case .inactive:
            break

        @unknown default:
            break
        }
    }

    private func lockForBackgroundTransition() {
        guard operatorProfile.authenticated, !workspaceToken.isEmpty else { return }
        keepaliveTask?.cancel()
        keepaliveTask = nil
        isShowingNativeAdminSheet = false
        activeBarcodeScanRequest = nil
        isPinUnlocked = false
        pinProofToken = ""
        prewarmedAcademyBypassToken = nil

        let tokenCopy = workspaceToken
        Task {
            await WorkspaceAPIClient.shared.lockPinSession(token: tokenCopy)
            await WorkspaceWebSessionPool.shared.backupMasterCookiesToKeychain()
        }
    }

    // MARK: - Rafraîchissement Session Opérateur & Droits RBAC

    public func refreshOperatorAndRbacSession(extraCookieHeader: String? = nil) async {
        do {
            let env = try await WorkspaceAPIClient.shared.fetchSession(
                token: workspaceToken.isEmpty ? nil : workspaceToken,
                extraCookieHeader: extraCookieHeader
            )
            guard env.authenticated == true, let email = env.email, !email.isEmpty else {
                await clearLocalSessionStateOnly()
                return
            }

            if let freshToken = env.workspaceToken, !freshToken.isEmpty {
                self.workspaceToken = freshToken
            }

            let ps = env.pinState
            let updatedProfile = WorkspaceOperatorProfile(
                authenticated: true,
                email: email,
                displayName: env.displayName ?? email,
                cid: env.cid ?? "",
                isAdmin: ps?.isAdmin ?? false,
                status: ps?.status ?? "unregistered",
                isSuperAdmin: ps?.isSuperAdmin ?? false,
                groups: ps?.groups ?? [],
                hasPinConfigured: ps?.hasPin ?? false,
                pinLength: ps?.pinLength ?? 6
            )
            self.operatorProfile = updatedProfile
            WorkspaceWebSessionPool.shared.saveWorkspaceCredentials(token: self.workspaceToken, profile: updatedProfile)
            WorkspaceWebSessionPool.shared.warmUpSSOBridgeIfNeeded(ssoBridgeURLString: env.ssoBridgeUrl)

            if let rbac = await WorkspaceAPIClient.shared.fetchEffectiveRbac(email: email) {
                self.rbacSnapshot = rbac
            }
        } catch WorkspaceAPIError.unauthorized {
            await clearLocalSessionStateOnly()
        } catch {
            // En cas d'aléa réseau ponctuel au boot, conserver les identifiants Keychain et re-tenter les droits RBAC
            if !operatorProfile.email.isEmpty,
               let rbac = await WorkspaceAPIClient.shared.fetchEffectiveRbac(email: operatorProfile.email) {
                self.rbacSnapshot = rbac
            }
        }
    }

    // MARK: - Connexion Viple Live ID (Native & Pont SSO)

    public func signInWithCredentials(identifier: String, password: String) async throws {
        let env = try await WorkspaceAPIClient.shared.login(identifier: identifier, password: password)
        guard let token = env.workspaceToken, !token.isEmpty,
              let email = env.email, !email.isEmpty else {
            throw WorkspaceAPIError.invalidCredentials("Réponse d'authentification incomplète.")
        }

        let ps = env.pinState
        let profile = WorkspaceOperatorProfile(
            authenticated: true,
            email: email,
            displayName: env.displayName ?? email,
            cid: env.cid ?? "",
            isAdmin: ps?.isAdmin ?? false,
            status: ps?.status ?? "unregistered",
            isSuperAdmin: ps?.isSuperAdmin ?? false,
            groups: ps?.groups ?? [],
            hasPinConfigured: ps?.hasPin ?? false,
            pinLength: ps?.pinLength ?? 6
        )

        self.workspaceToken = token
        self.operatorProfile = profile
        self.isPinUnlocked = false
        self.pinProofToken = ""
        self.pinErrorMessage = nil

        WorkspaceWebSessionPool.shared.saveWorkspaceCredentials(token: token, profile: profile)
        WorkspaceWebSessionPool.shared.warmUpSSOBridgeIfNeeded(ssoBridgeURLString: env.ssoBridgeUrl)

        if let rbac = await WorkspaceAPIClient.shared.fetchEffectiveRbac(email: email) {
            self.rbacSnapshot = rbac
        }
        WorkspaceHaptics.success()
    }

    public func completeSSOWebLogin(cookieHeader: String) async {
        await refreshOperatorAndRbacSession(extraCookieHeader: cookieHeader)
        if operatorProfile.authenticated {
            WorkspaceHaptics.success()
        }
    }

    // MARK: - Validation & Création Native du Code PIN Cenelis Connect

    public func submitPinVerification(_ pinCode: String) async -> Bool {
        guard !workspaceToken.isEmpty else { return false }
        isVerifyingPin = true
        pinErrorMessage = nil
        defer { isVerifyingPin = false }

        do {
            let res = try await WorkspaceAPIClient.shared.verifyPin(pin: pinCode, token: workspaceToken)
            if res.needsSetup == true {
                operatorProfile.hasPinConfigured = false
                pinErrorMessage = "Veuillez configurer votre code PIN Cenelis Connect."
                return false
            }
            guard res.ok, let proof = res.pinProofToken, !proof.isEmpty else {
                WorkspaceHaptics.error()
                pinErrorMessage = res.error ?? "Code PIN incorrect. Veuillez réessayer."
                return false
            }

            await finalizePinUnlock(proof: proof, ssoBridgeUrl: res.ssoBridgeUrl, updatedPinLength: res.pinLength)
            return true
        } catch WorkspaceAPIError.unauthorized {
            await clearLocalSessionStateOnly()
            return false
        } catch {
            WorkspaceHaptics.error()
            pinErrorMessage = error.localizedDescription
            return false
        }
    }

    public func submitInitialPinSetup(pin: String, confirmPin: String) async -> Bool {
        guard !workspaceToken.isEmpty else { return false }
        isVerifyingPin = true
        pinErrorMessage = nil
        defer { isVerifyingPin = false }

        do {
            let res = try await WorkspaceAPIClient.shared.setupPin(pin: pin, confirmPin: confirmPin, token: workspaceToken)
            guard res.ok, let proof = res.pinProofToken, !proof.isEmpty else {
                WorkspaceHaptics.error()
                pinErrorMessage = res.error ?? "Impossible d'enregistrer ce code PIN."
                return false
            }

            operatorProfile.hasPinConfigured = true
            if let len = res.pinLength {
                operatorProfile.pinLength = (len == 4) ? 4 : 6
            }
            WorkspaceWebSessionPool.shared.saveWorkspaceCredentials(token: workspaceToken, profile: operatorProfile)
            await finalizePinUnlock(proof: proof, ssoBridgeUrl: res.ssoBridgeUrl, updatedPinLength: res.pinLength)
            return true
        } catch {
            WorkspaceHaptics.error()
            pinErrorMessage = error.localizedDescription
            return false
        }
    }

    private func finalizePinUnlock(proof: String, ssoBridgeUrl: String?, updatedPinLength: Int?) async {
        self.pinProofToken = proof
        if let len = updatedPinLength {
            self.operatorProfile.pinLength = (len == 4) ? 4 : 6
        }
        WorkspaceWebSessionPool.shared.warmUpSSOBridgeIfNeeded(ssoBridgeURLString: ssoBridgeUrl)

        withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
            self.isPinUnlocked = true
        }
        WorkspaceHaptics.success()

        startRollingPinKeepaliveLoop()
        Task {
            await self.refreshAllPanelHealthProbes()
        }
        Task {
            await self.replenishAcademyBypassToken()
        }
        if searchScope == .academyHelp && academyHelpResults.isEmpty {
            triggerAcademyHelpSearch(immediate: true)
        }
    }

    /// Maintient la session PIN serveur active en continu pendant que l'opérateur travaille dans l'app (0 redemande toutes les 1h)
    private func startRollingPinKeepaliveLoop() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12 * 60 * 1_000_000_000) // Toutes les 12 minutes
                guard !Task.isCancelled, let self else { return }
                guard self.isPinUnlocked, !self.workspaceToken.isEmpty, !self.pinProofToken.isEmpty else { return }
                _ = await WorkspaceAPIClient.shared.keepalivePinSession(
                    token: self.workspaceToken,
                    pinProof: self.pinProofToken
                )
            }
        }
    }

    public func handleUnexpectedWebPinRedirect(intendedURL: URL?) {
        guard isPinUnlocked, !workspaceToken.isEmpty, !pinProofToken.isEmpty else {
            isPinUnlocked = false
            return
        }
        Task { @MainActor in
            let renewed = await WorkspaceAPIClient.shared.keepalivePinSession(
                token: workspaceToken,
                pinProof: pinProofToken
            )
            if renewed {
                if let target = intendedURL {
                    webController.load(url: target)
                } else {
                    webController.reload()
                }
            } else {
                isPinUnlocked = false
            }
        }
    }

    // MARK: - Déconnexion Complète & Changement de Compte

    public func performFullLogout() async {
        WorkspaceHaptics.medium()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        academySearchTask?.cancel()

        isShowingNativeAdminSheet = false
        let tokenCopy = workspaceToken

        // 1. Révoquer la session PIN & les cookies SSO côté serveur
        await WorkspaceAPIClient.shared.lockPinSession(token: tokenCopy)
        await WorkspaceAPIClient.shared.revokeGlobalWebSSOSessions()

        // 2. Purger intégralement WKWebsiteDataStore, cookies, cache et Keychain
        webController.resetStateOnLogout()
        await WorkspaceWebSessionPool.shared.purgeAllSessionsAndWebsiteData()

        // 3. Réinitialiser tout l'état applicatif et renvoyer vers la connexion Viple Live ID
        await clearLocalSessionStateOnly()
    }

    private func clearLocalSessionStateOnly() async {
        keepaliveTask?.cancel()
        keepaliveTask = nil
        workspaceToken = ""
        pinProofToken = ""
        prewarmedAcademyBypassToken = nil
        isPinUnlocked = false
        activePanel = nil
        isShowingHub = true
        isShowingNativeAdminSheet = false
        activeBarcodeScanRequest = nil
        searchQuery = ""
        academyHelpResults = []
        operatorProfile = WorkspaceOperatorProfile()
        rbacSnapshot = WorkspaceRbacSnapshot()
    }

    // MARK: - Filtrage RBAC des Panels & des Fonctions

    public var authorizedPanels: [AdminPanelItem] {
        allPanels.filter { panel in
            if operatorProfile.isSuperAdmin || rbacSnapshot.isSuperAdmin {
                return true
            }
            if rbacSnapshot.registered {
                return rbacSnapshot.isPanelAuthorized(panel.id)
            }
            return operatorProfile.isAdmin
        }
    }

    public var filteredHubPanels: [AdminPanelItem] {
        let base = authorizedPanels.filter { panel in
            selectedCategory == "Tous" || panel.category == selectedCategory
        }
        let q = foldedQuery(searchQuery)
        guard !q.isEmpty else { return base }

        return base.filter { p in
            foldedQuery(p.name).contains(q)
                || foldedQuery(p.fullTitle).contains(q)
                || foldedQuery(p.domainLabel).contains(q)
                || foldedQuery(p.category).contains(q)
                || foldedQuery(p.description).contains(q)
        }
    }

    public var filteredFunctions: [PanelFunctionItem] {
        let allowed = EcosystemCatalogRegistry.allFunctions.filter { fn in
            if operatorProfile.isSuperAdmin || rbacSnapshot.isSuperAdmin {
                return true
            }
            if rbacSnapshot.registered {
                return rbacSnapshot.isFunctionAuthorized(fn)
            }
            return operatorProfile.isAdmin
        }

        let q = foldedQuery(searchQuery)
        guard !q.isEmpty else { return allowed }

        return allowed.filter { fn in
            foldedQuery(fn.title).contains(q)
                || foldedQuery(fn.subtitle).contains(q)
                || foldedQuery(fn.panelName).contains(q)
                || fn.keywords.contains(where: { foldedQuery($0).contains(q) })
        }
    }

    public func panelsGroupedByCategory(_ list: [AdminPanelItem]) -> [(category: String, items: [AdminPanelItem])] {
        let cats = EcosystemCatalogRegistry.allCategoriesOrdered.filter { $0 != "Tous" }
        var grouped: [(String, [AdminPanelItem])] = []
        for cat in cats {
            let matches = list.filter { $0.category == cat }
            if !matches.isEmpty {
                grouped.append((cat, matches))
            }
        }
        let knownSet = Set(cats)
        let extras = list.filter { !knownSet.contains($0.category) }
        if !extras.isEmpty {
            grouped.append(("Autres Consoles", extras))
        }
        return grouped
    }

    // MARK: - Sondes de Statut Temps Réel des Panels

    public func refreshAllPanelHealthProbes() async {
        let targets = authorizedPanels
        for p in targets where panelHealthMap[p.id] == nil {
            panelHealthMap[p.id] = .checking
        }

        await withTaskGroup(of: (String, AdminPanelHealthStatus).self) { group in
            for panel in targets {
                group.addTask {
                    let status = await WorkspaceAPIClient.shared.probePanelHealth(panel: panel)
                    return (panel.id, status)
                }
            }
            for await (panelId, status) in group {
                self.panelHealthMap[panelId] = status
            }
        }
    }

    // MARK: - Ouverture d'un Panel ou d'une Fonction dans la WebView Encapsulée

    public func openPanel(_ panel: AdminPanelItem) {
        isShowingNativeAdminSheet = false

        // Règle stricte §5 : Cenelis Academy s'ouvre TOUJOURS dans l'application iOS native avec bypass PIN
        if panel.isCenelisAcademyNativeApp {
            Task {
                await openCenelisAcademyNativeApp()
            }
            return
        }

        guard let url = panel.normalizedAdminURL else { return }
        WorkspaceHaptics.medium()
        activePanel = panel
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isShowingHub = false
        }
        webController.load(url: url, postLoadJS: nil)
    }

    public func openPanelFunction(_ fn: PanelFunctionItem) {
        if fn.panelId == "cenelis-academy" {
            Task {
                await openCenelisAcademyNativeApp()
            }
            return
        }

        guard let targetURL = fn.targetURL else { return }
        WorkspaceHaptics.medium()

        if let matchingPanel = allPanels.first(where: { $0.id == fn.panelId }) {
            activePanel = matchingPanel
        }
        isShowingNativeAdminSheet = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isShowingHub = false
        }
        webController.load(url: targetURL, postLoadJS: fn.postLoadJavaScript)
    }

    public func returnToHub() {
        WorkspaceHaptics.light()
        isShowingNativeAdminSheet = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isShowingHub = true
        }
    }

    // MARK: - Masquage / Réaffichage du Bouton Hamburger Natif (§3)

    public func hideFloatingBurgerButton() {
        guard !isFloatingBurgerHidden else { return }
        WorkspaceHaptics.light()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isFloatingBurgerHidden = true
            showHiddenBurgerHintToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                self.showHiddenBurgerHintToast = false
            }
        }
    }

    public func revealFloatingBurgerButtonAfterLongPress() {
        guard isFloatingBurgerHidden else { return }
        WorkspaceHaptics.heavy()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) {
            isFloatingBurgerHidden = false
            showHiddenBurgerHintToast = false
        }
    }

    // MARK: - Recherche Live « Aide (Cenelis Academy) » & Handoff Natif avec Bypass PIN (§2.3 & §5)

    private func handleSearchQueryChanged() {
        if searchScope == .academyHelp {
            triggerAcademyHelpSearch(immediate: false)
        }
    }

    public func triggerAcademyHelpSearch(immediate: Bool) {
        academySearchTask?.cancel()
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = workspaceToken
        guard !token.isEmpty else { return }

        academySearchTask = Task { @MainActor [weak self] in
            if !immediate {
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            self.isSearchingAcademy = true
            let results = await WorkspaceAPIClient.shared.searchCenelisAcademy(query: q, token: token)
            guard !Task.isCancelled else { return }
            self.academyHelpResults = results
            self.isSearchingAcademy = false
        }
    }

    private func replenishAcademyBypassToken() async {
        guard isPinUnlocked, !workspaceToken.isEmpty, !pinProofToken.isEmpty else { return }
        if let token = await WorkspaceAPIClient.shared.issueAcademyPinBypassToken(
            token: workspaceToken,
            pinProof: pinProofToken
        ) {
            self.prewarmedAcademyBypassToken = token
            self.prewarmedBypassCreatedAt = Date()
        }
    }

    private func consumeOrMintSingleUseBypassToken() async -> String? {
        if let cached = prewarmedAcademyBypassToken,
           let createdAt = prewarmedBypassCreatedAt,
           Date().timeIntervalSince(createdAt) < 480 {
            prewarmedAcademyBypassToken = nil
            prewarmedBypassCreatedAt = nil
            Task { await self.replenishAcademyBypassToken() }
            return cached
        }

        let fresh = await WorkspaceAPIClient.shared.issueAcademyPinBypassToken(
            token: workspaceToken,
            pinProof: pinProofToken
        )
        Task { await self.replenishAcademyBypassToken() }
        return fresh
    }

    public func openAcademyHelpResult(_ item: AcademyHelpSearchResult) async {
        await openCenelisAcademyNativeApp(
            courseId: item.courseId,
            sectionId: item.sectionId,
            stepIndex: item.stepIndex,
            bubbleKey: item.bubbleKey,
            deepDiveId: item.deepDiveId,
            resourceTabId: item.resourceTabId
        )
    }

    public func handleInterceptedWebAcademyURL(_ url: URL) {
        Task { @MainActor in
            var courseId: String? = nil
            var sectionId: String? = nil
            var stepIndex: Int? = nil
            var deepDiveId: String? = nil
            var bubbleKey: String? = nil
            var resourceTabId: String? = nil

            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let qMap = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

            if url.scheme?.lowercased() == "cenelisacademy" {
                courseId = qMap["course"]
                sectionId = qMap["section"]
                stepIndex = qMap["step"].flatMap { Int($0) }
                deepDiveId = qMap["deep_dive"]
                bubbleKey = qMap["bubble"]
                resourceTabId = qMap["resource_tab"]
            } else {
                // Extraction depuis une URL web https://academy.prod.cenelis.com/cours/{slug}?part={idx}
                let pathParts = url.pathComponents.filter { $0 != "/" }
                if pathParts.count >= 2 && (pathParts[0].lowercased() == "cours" || pathParts[0].lowercased() == "course") {
                    courseId = pathParts[1]
                } else if let cQuery = qMap["course"] ?? qMap["cours"], !cQuery.isEmpty {
                    courseId = cQuery
                }
                if let pRaw = qMap["part"] ?? qMap["section"] {
                    if let idx = Int(pRaw) {
                        stepIndex = idx
                    } else {
                        sectionId = pRaw
                    }
                }
            }

            await openCenelisAcademyNativeApp(
                courseId: courseId,
                sectionId: sectionId,
                stepIndex: stepIndex,
                bubbleKey: bubbleKey,
                deepDiveId: deepDiveId,
                resourceTabId: resourceTabId
            )
        }
    }

    public func openCenelisAcademyNativeApp(
        courseId: String? = nil,
        sectionId: String? = nil,
        stepIndex: Int? = nil,
        bubbleKey: String? = nil,
        deepDiveId: String? = nil,
        resourceTabId: String? = nil
    ) async {
        WorkspaceHaptics.medium()
        let bypassToken = await consumeOrMintSingleUseBypassToken()

        var comps = URLComponents()
        comps.scheme = "cenelisacademy"
        comps.host = "handoff"

        var queryItems: [URLQueryItem] = []
        if let bypassToken, !bypassToken.isEmpty {
            queryItems.append(URLQueryItem(name: "pin_bypass_token", value: bypassToken))
        }
        if let courseId, !courseId.isEmpty {
            queryItems.append(URLQueryItem(name: "course", value: courseId))
        }
        if let sectionId, !sectionId.isEmpty {
            queryItems.append(URLQueryItem(name: "section", value: sectionId))
        }
        if let stepIndex {
            queryItems.append(URLQueryItem(name: "step", value: String(stepIndex)))
        }
        if let bubbleKey, !bubbleKey.isEmpty {
            queryItems.append(URLQueryItem(name: "bubble", value: bubbleKey))
        }
        if let deepDiveId, !deepDiveId.isEmpty {
            queryItems.append(URLQueryItem(name: "deep_dive", value: deepDiveId))
        }
        if let resourceTabId, !resourceTabId.isEmpty {
            queryItems.append(URLQueryItem(name: "resource_tab", value: resourceTabId))
        }
        comps.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let deepLinkURL = comps.url else { return }

        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(deepLinkURL) {
            await UIApplication.shared.open(deepLinkURL)
        } else {
            // Tenter malgré tout l'ouverture directe (au cas où le cache LSApplicationQueriesSchemes rafraîchit)
            let opened = await UIApplication.shared.open(deepLinkURL)
            if !opened {
                academyInstallAlertShown = true
            }
        }
        #endif
    }

    // MARK: - Pont Matériel Codes-Barres / ISBN Wingman (`barcodeScanner` <-> `window.onNativeBarcodeScanned`)

    public func handleWebBarcodeScannerBridge(action: String, request: NativeBarcodeScanRequest?) {
        guard isPinUnlocked else { return }
        if action == "stop" {
            activeBarcodeScanRequest = nil
            return
        }
        isShowingNativeAdminSheet = false
        WorkspaceHaptics.medium()
        activeBarcodeScanRequest = request ?? NativeBarcodeScanRequest()
    }

    public func forwardScannedBarcodeToWeb(
        code: String,
        symbology: String,
        mode: NativeBarcodeScanMode,
        totalCount: Int,
        fieldContext: String
    ) {
        webController.deliverScannedBarcode(
            code: code,
            symbology: symbology,
            mode: mode,
            totalCount: totalCount,
            fieldContext: fieldContext
        )
    }

    public func handleBarcodeScannerClosed(mode: NativeBarcodeScanMode, entries: [ScannedBarcodeEntry]) {
        activeBarcodeScanRequest = nil
        webController.notifyBarcodeScannerClosed(mode: mode, entries: entries)
    }

    // MARK: - Normalisation Recherche Française Sans Accents

    private func foldedQuery(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
    }
}
