import Foundation
import SwiftUI
import StoreKit

// MARK: - ViewModel Principal « Livria Store » (App Store ID : 6825159743 • iOS 18+ / iOS 26+)

@MainActor
public final class LivriaStoreViewModel: ObservableObject {
    public static let loobyPlusProductID = "store.livria.loobyplus.monthly"

    // Navigation & UI
    @Published public var selectedMainTab: Int = 0
    @Published public var isShowingCartSheet: Bool = false
    @Published public var isShowingCheckoutSheet: Bool = false
    @Published public var isShowingAuthSheet: Bool = false
    @Published public var isShowingTermsReviewSheet: Bool = false
    @Published public var isShowingISBNScannerSheet: Bool = false
    @Published public var scannedBookForDetail: LivriaBook? = nil
    @Published public var pendingDeepLinkedBookId: Int? = nil
    @Published public var activeToastMessage: String? = nil
    @Published public var isInitialBootstrapping: Bool = true
    @Published public var isLoading: Bool = false
    @Published public var authErrorMessage: String? = nil
    @Published public var applePasswordSetupNotice: String? = nil

    // Onboarding Sign in with Apple (Uniquement à la 1re inscription Apple : Nom, Prénom, Pseudo & @viplemail.fr obligatoire)
    @Published public var pendingAppleOnboardingUserId: String? = nil
    @Published public var pendingAppleOnboardingEmail: String? = nil
    @Published public var pendingAppleSuggestedFirstName: String = ""
    @Published public var pendingAppleSuggestedLastName: String = ""

    // In-App Purchase StoreKit 2 Looby+
    @Published public var isPurchasingLoobyPlus: Bool = false
    @Published public var isShowingLoobyPlusUnavailableAlert: Bool = false
    @Published public var loobyPlusUnavailableMessage: String = "L'abonnement Looby+ (3,50 € / mois) est en cours de synchronisation avec l'App Store. Veuillez vérifier votre connexion App Store et réessayer."
    @Published public var loobyPlusStoreKitProduct: Product? = nil
    @Published public var hasLocalStoreKitLoobyPlusEntitlement: Bool = false

    // État Serveur Indisponible / Timeout 20s / HTTP 503
    @Published public var isServerUnreachable: Bool = false
    @Published public var serverUnreachableMessage: String = LivriaAPIClient.serverLunchBreakMessage

    // Conditions Générales d'Utilisation & de Vente (obligatoires au 1er lancement)
    @Published public var hasAcceptedTermsOfUse: Bool = false

    // Thème persistant sur toutes les pages de l'application sans exception
    @Published public var selectedThemeId: String = "default"

    // Session Viple Live ID ou Session Invité (Commande sans compte autorisée)
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: LivriaUserProfile? = nil

    // Détection Automatique de Compte Viple Inter-Application (Livria Social <-> Livria Store)
    @Published public var detectedCrossAppAccount: LivriaCrossAppAccount? = nil
    @Published public var isShowingCrossAppSSOPrompt: Bool = false
    @Published public var isAcceptingCrossAppSSO: Bool = false
    private var dismissedCrossAppUserIds: Set<Int> = []
    private let sharedGroupDefaults = UserDefaults(suiteName: "group.store.livria.shared")

    // Données Globales synchronisées avec https://livria.store/api/mobile/v1/bootstrap
    @Published public var homeData: LivriaHomeSection? = nil
    @Published public var books: [LivriaBook] = []
    @Published public var genres: [String] = []
    @Published public var shelf: [LivriaShelfEntry] = []
    @Published public var cart: [LivriaCartItem] = []
    @Published public var orders: [LivriaOrder] = []
    @Published public var trades: LivriaTradesBundle? = nil
    @Published public var loobyPlus: LivriaLoobyPlusState? = nil
    @Published public var relays: LivriaRelaysBundle? = nil
    @Published public var games: LivriaGamesData? = nil
    @Published public var supportTickets: [LivriaSupportTicket] = []
    @Published public var paymentSettings: LivriaPaymentSettings = LivriaPaymentSettings()
    @Published public var takerApplication: LivriaVipleTakerApplication? = nil

    // Recherche de membres (section Membres de la barre de recherche -> redirige vers Livria Social)
    @Published public var searchedMembers: [LivriaMemberSearchResult] = []

    // Sélection Point Relais pour le Checkout (mis par défaut dans le Checkout lorsqu'il est choisi dans Points Relais)
    @Published public var selectedRelayForCheckout: String? = nil
    @Published public var selectedCommunityRelayId: Int? = nil
    @Published public var selectedUpsPointForCheckout: LivriaUpsPickupPoint? = nil
    @Published public var selectedCommunityRelayForCheckout: LivriaCommunityRelay? = nil

    // Favoris ❤️, Récemment Consultés, Recherches Récentes & Notes de Lecture Personnelles (Persistance Locale Prod)
    @Published public var favoriteBookIds: Set<Int> = []
    @Published public var recentlyViewedBookIds: [Int] = []
    @Published public var recentSearchQueries: [String] = []
    @Published public var bookReadingNotes: [Int: String] = [:]
    @Published public var readingMinutesByBook: [Int: Int] = [:]

    // Suivi Natif Viple Delivery Intégré (Sans ouvrir Safari)
    @Published public var activeTrackingResult: LivriaVipleDeliveryTrackResponse? = nil
    @Published public var isTrackingLoading: Bool = false
    @Published public var isShowingVipleDeliverySheet: Bool = false
    @Published public var userShipments: [LivriaVipleDeliveryTrackResponse] = []

    // Préférences Avancées, Confidentialité RGPD & Diagnostics
    @Published public var userPreferences: LivriaUserPreferences = LivriaUserPreferences()
    @Published public var lastDiagnosticsPing: LivriaDiagnosticsPingResponse? = nil

    private let defaults = UserDefaults.standard
    private let acceptedTermsKey = "livria.store.ios.acceptedCGU.v1"
    private let savedThemeKey = "livria.store.ios.selectedThemeId.v2"
    private let savedEmailKey = "livria.store.ios.vipleLiveEmail"
    private let savedUserIdKey = "livria.store.ios.vipleLiveUserId"
    private let savedGuestEmailKey = "livria.store.ios.guestEmail"
    private let savedUpsRelayDataKey = "livria.store.ios.selectedUpsRelay.v1"
    private let savedFavoritesKey = "livria.store.ios.favoriteBookIds.v1"
    private let savedRecentlyViewedKey = "livria.store.ios.recentlyViewedBookIds.v1"
    private let savedRecentSearchesKey = "livria.store.ios.recentSearches.v1"
    private let savedReadingNotesKey = "livria.store.ios.readingNotes.v1"
    private let savedReadingMinutesKey = "livria.store.ios.readingMinutes.v1"
    private let savedPreferencesKey = "livria.store.ios.userPreferences.v1"

    public init() {
        self.hasAcceptedTermsOfUse = defaults.bool(forKey: acceptedTermsKey)
        if let persistedTheme = defaults.string(forKey: savedThemeKey), !persistedTheme.isEmpty {
            self.selectedThemeId = persistedTheme
        }
        if let data = defaults.data(forKey: savedUpsRelayDataKey),
           let decoded = try? JSONDecoder().decode(LivriaUpsPickupPoint.self, from: data) {
            self.selectedUpsPointForCheckout = decoded
            self.selectedRelayForCheckout = "\(decoded.name) — \(decoded.address), \(decoded.postalCode) \(decoded.city)"
        }
        if let favArray = defaults.array(forKey: savedFavoritesKey) as? [Int] {
            self.favoriteBookIds = Set(favArray)
        }
        if let recentIds = defaults.array(forKey: savedRecentlyViewedKey) as? [Int] {
            self.recentlyViewedBookIds = recentIds
        }
        if let searches = defaults.stringArray(forKey: savedRecentSearchesKey) {
            self.recentSearchQueries = searches
        }
        if let notesData = defaults.data(forKey: savedReadingNotesKey),
           let decodedNotes = try? JSONDecoder().decode([Int: String].self, from: notesData) {
            self.bookReadingNotes = decodedNotes
        }
        if let minsData = defaults.data(forKey: savedReadingMinutesKey),
           let decodedMins = try? JSONDecoder().decode([Int: Int].self, from: minsData) {
            self.readingMinutesByBook = decodedMins
        }
        if let prefsData = defaults.data(forKey: savedPreferencesKey),
           let decodedPrefs = try? JSONDecoder().decode(LivriaUserPreferences.self, from: prefsData) {
            self.userPreferences = decodedPrefs
        }

        let savedEmail = defaults.string(forKey: savedEmailKey)
        let savedUid = defaults.integer(forKey: savedUserIdKey)

        if let email = savedEmail, !email.isEmpty, !email.lowercased().hasSuffix("@guest.livria.store") {
            self.isAuthenticated = true
            Task {
                async let minSplashDelay: Void = {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                }()
                await preloadLoobyPlusStoreKitProductAndEntitlements()
                await refreshBootstrap(email: email, userId: savedUid > 0 ? savedUid : nil)
                _ = await minSplashDelay
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.isInitialBootstrapping = false
                }
                await checkCrossAppVipleAccount()
            }
        } else {
            let guestEmail = getOrCreateGuestEmail()
            self.isAuthenticated = false
            Task {
                async let minSplashDelay: Void = {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                }()
                await preloadLoobyPlusStoreKitProductAndEntitlements()
                await refreshBootstrap(email: guestEmail, userId: savedUid > 0 ? savedUid : nil)
                _ = await minSplashDelay
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.isInitialBootstrapping = false
                }
                await checkCrossAppVipleAccount()
            }
        }
    }

    public func acceptTermsOfUse() {
        defaults.set(true, forKey: acceptedTermsKey)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            hasAcceptedTermsOfUse = true
        }
        Task {
            await checkCrossAppVipleAccount()
        }
    }

    public func setTheme(_ themeId: String) {
        let normalized = themeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : themeId
        self.selectedThemeId = normalized
        defaults.set(normalized, forKey: savedThemeKey)
        self.currentUser?.themeId = normalized
    }

    public func selectUpsRelayForDefaultCheckout(_ ups: LivriaUpsPickupPoint) {
        self.selectedUpsPointForCheckout = ups
        self.selectedCommunityRelayForCheckout = nil
        self.selectedCommunityRelayId = nil
        self.selectedRelayForCheckout = "\(ups.name) — \(ups.address), \(ups.postalCode) \(ups.city)"
        if let encoded = try? JSONEncoder().encode(ups) {
            defaults.set(encoded, forKey: savedUpsRelayDataKey)
        }
    }

    public func selectCommunityRelayForDefaultCheckout(_ relay: LivriaCommunityRelay) {
        self.selectedCommunityRelayForCheckout = relay
        self.selectedCommunityRelayId = relay.id
        self.selectedUpsPointForCheckout = nil
        self.selectedRelayForCheckout = "\(relay.name) — \(relay.address), \(relay.postalCode) \(relay.city)"
        defaults.removeObject(forKey: savedUpsRelayDataKey)
    }

    private func getOrCreateGuestEmail() -> String {
        if let existing = defaults.string(forKey: savedGuestEmailKey), !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        let generated = "guest-ios-\(token)@guest.livria.store"
        defaults.set(generated, forKey: savedGuestEmailKey)
        return generated
    }

    public var isGuestSession: Bool {
        !isAuthenticated || currentUser?.isGuestAccount == true
    }

    public var currentThemeId: String {
        selectedThemeId
    }

    public var cartItemsCount: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    public var cartSubtotal: Double {
        cart.reduce(0.0) { $0 + $1.lineTotal }
    }

    public var hasLoobyPlusInCart: Bool {
        cart.contains(where: { $0.isLoobyPlusSubscription })
    }

    public var cartShippingCost: Double {
        if cart.isEmpty { return 0.0 }
        let onlyDigitalOrSub = cart.allSatisfy { $0.format == "Numérique" || $0.format == "Audio" || $0.isLoobyPlusSubscription }
        if onlyDigitalOrSub { return 0.0 }
        if currentUser?.isLivriaPlus == true || hasLoobyPlusInCart || cartSubtotal >= 35.0 {
            return 0.0
        }
        return 0.0 // Livraison UPS Standard offerte sur Livria Store
    }

    public var cartTotal: Double {
        cartSubtotal + cartShippingCost
    }

    public var isBuyGodUser: Bool {
        guard let u = currentUser else { return false }
        return (u.isBuyGod == true) || (u.role?.lowercased() == "buygod")
    }

    public var newestCatalogBooks: [LivriaBook] {
        if let newest = homeData?.newest, !newest.isEmpty {
            return newest
        }
        return books.sorted { $0.id > $1.id }
    }

    /// Algorithme de recommandation : si l'algorithme a moins de 5 livres à proposer, affiche les plus récemment ajoutés
    public var smartRecommendationResult: (books: [LivriaBook], isFallbackToRecent: Bool, subtitle: String) {
        let favGenres = (currentUser?.favoriteGenres ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        var algoBooks: [LivriaBook] = []
        if !favGenres.isEmpty {
            algoBooks = books.filter { b in
                favGenres.contains(b.genre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
        if algoBooks.count < 5, let serverRecs = homeData?.recommended, serverRecs.count >= 5 {
            algoBooks = serverRecs
        }
        if algoBooks.count < 5 {
            return (
                books: Array(newestCatalogBooks.prefix(12)),
                isFallbackToRecent: true,
                subtitle: "Découvrez les derniers ouvrages fraîchement arrivés dans le catalogue Livria"
            )
        }
        return (
            books: Array(algoBooks.prefix(12)),
            isFallbackToRecent: false,
            subtitle: "Sélection personnalisée selon vos genres favoris et vos lectures"
        )
    }

    /// Recherche un ISBN directement dans le catalogue Livria (local puis serveur Livria)
    public func findBookInLivriaCatalog(isbn rawIsbn: String) async -> LivriaBook? {
        let clean = rawIsbn.filter { $0.isNumber || $0 == "X" || $0 == "x" }.uppercased()
        guard !clean.isEmpty else { return nil }

        if let localMatch = books.first(where: {
            $0.isbn.filter({ $0.isNumber || $0 == "X" || $0 == "x" }).uppercased() == clean
        }) {
            return localMatch
        }

        if let res = try? await LivriaAPIClient.shared.lookupISBN(clean),
           res.inCatalog,
           let catBook = res.catalogBook {
            return catBook
        }
        return nil
    }

    public func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activeToastMessage = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if activeToastMessage == text {
                withAnimation {
                    activeToastMessage = nil
                }
            }
        }
    }

    // MARK: - 1. Authentification Native Viple Live ID & Sign in with Apple

    private var currentGuestUserIdForMerge: Int? {
        if let u = currentUser, u.isGuestAccount {
            return u.id
        }
        return nil
    }

    private var currentGuestEmailForMerge: String? {
        if let g = defaults.string(forKey: savedGuestEmailKey), !g.isEmpty {
            return g
        }
        if let u = currentUser, u.isGuestAccount {
            return u.email
        }
        return nil
    }

    public func signIn(email: String, password: String) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.loginVipleLiveID(
                email: email,
                password: password,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            if res.requiresApplePasswordSetup == true {
                applePasswordSetupNotice = res.error ?? "Vous vous êtes inscrit avec Apple et n'avez pas encore défini de mot de passe. Un e-mail vient d'être envoyé sur votre boîte mail iCloud (\(res.icloudEmail ?? "iCloud")) avec un lien pour créer votre mot de passe."
                return
            }
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Identifiant Viple Live ID ou mot de passe incorrect."
                return
            }
            self.currentUser = user
            self.isAuthenticated = !user.isGuestAccount
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            isShowingAuthSheet = false
            showToast("Connecté avec votre compte Viple Live ID (\(user.displayName))")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func registerAccount(
        emailMode: String,
        emailUser: String,
        customEmail: String,
        password: String,
        firstName: String,
        lastName: String,
        displayName: String
    ) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.registerVipleLiveID(
                emailMode: emailMode,
                emailUser: emailUser,
                customEmail: customEmail,
                password: password,
                firstName: firstName,
                lastName: lastName,
                displayName: displayName,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Impossible de créer le compte Viple Live ID."
                return
            }
            self.currentUser = user
            self.isAuthenticated = true
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            isShowingAuthSheet = false
            showToast("Bienvenue sur Livria Store, \(user.displayName) ! Compte Viple Live ID créé.")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func handleSignInWithApple(
        appleUserId: String,
        identityToken: String?,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.signInWithApple(
                appleUserId: appleUserId,
                identityToken: identityToken,
                email: email,
                firstName: firstName,
                lastName: lastName,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            if res.needsOnboarding == true {
                self.pendingAppleOnboardingUserId = res.appleUserId ?? appleUserId
                self.pendingAppleOnboardingEmail = res.appleEmail ?? email
                self.pendingAppleSuggestedFirstName = res.suggestedFirstName ?? firstName ?? ""
                self.pendingAppleSuggestedLastName = res.suggestedLastName ?? lastName ?? ""
                return
            }
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Connexion avec Apple indisponible."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            self.currentUser = user
            self.isAuthenticated = true
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            isShowingAuthSheet = false
            showToast("Connecté avec Apple sur votre compte Viple Live ID (\(user.displayName))")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func completeAppleOnboarding(
        firstName: String,
        lastName: String,
        displayName: String,
        vipleMailUser: String
    ) async {
        guard let appleId = pendingAppleOnboardingUserId, !appleId.isEmpty else { return }
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.completeAppleSignup(
                appleUserId: appleId,
                appleEmail: pendingAppleOnboardingEmail,
                firstName: firstName,
                lastName: lastName,
                displayName: displayName,
                vipleMailUser: vipleMailUser,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Impossible de finaliser l'inscription Apple."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            self.currentUser = user
            self.isAuthenticated = true
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            isShowingAuthSheet = false
            showToast("Bienvenue \(user.displayName) ! Votre identifiant \(user.email) est associé à votre compte Apple.")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func linkAppleToExistingAccount(
        email: String,
        password: String
    ) async {
        guard let appleId = pendingAppleOnboardingUserId, !appleId.isEmpty else { return }
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.linkAppleToExistingAccount(
                appleUserId: appleId,
                appleEmail: pendingAppleOnboardingEmail,
                email: email,
                password: password,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Identifiant Viple Live ID ou mot de passe incorrect."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            self.currentUser = user
            self.isAuthenticated = true
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            isShowingAuthSheet = false
            showToast("Votre compte Viple Live ID (\(user.displayName)) est désormais associé à votre compte Apple !")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func deleteVipleAccount() async {
        guard let u = currentUser, !u.isGuestAccount else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.deleteVipleAccount(
                userId: u.id,
                email: u.email,
                cid: u.cid
            )
            let msg = (res["message"] as? String) ?? "Votre compte Viple Live ID a été définitivement supprimé."
            defaults.removeObject(forKey: savedEmailKey)
            defaults.removeObject(forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            clearLocalCrossAppSession()
            let freshGuest = getOrCreateGuestEmail()
            isAuthenticated = false
            currentUser = nil
            shelf = []
            cart = []
            orders = []
            selectedMainTab = 0
            showToast(msg)
            await LivriaAPIClient.shared.clearCrossAppSession()
            await refreshBootstrap(email: freshGuest, userId: nil)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func signOut() {
        defaults.removeObject(forKey: savedEmailKey)
        defaults.removeObject(forKey: savedUserIdKey)
        defaults.removeObject(forKey: savedGuestEmailKey)
        clearLocalCrossAppSession()
        let guestEmail = getOrCreateGuestEmail()
        isAuthenticated = false
        currentUser = nil
        cart = []
        orders = []
        showToast("Vous naviguez désormais en mode Invité sur Livria Store.")
        Task {
            await LivriaAPIClient.shared.clearCrossAppSession()
            await refreshBootstrap(email: guestEmail, userId: nil)
        }
    }

    // MARK: - 1b. Connexion Automatique Inter-Applications Viple Live ID (Livria Social <-> Livria Store)

    private func saveLocalCrossAppSession(user: LivriaUserProfile) {
        guard !user.isGuestAccount else { return }
        let account = LivriaCrossAppAccount(
            sourceApp: "Livria Store",
            userId: user.id,
            email: user.email,
            displayName: user.displayName,
            firstName: user.firstName,
            lastName: user.lastName,
            avatarUrl: user.avatarUrl,
            level: user.level,
            xp: user.xp,
            isLivriaPlus: user.isLivriaPlus
        )
        if let data = try? JSONEncoder().encode(account) {
            sharedGroupDefaults?.set(data, forKey: "viple.crossapp.store.account")
        }
    }

    private func clearLocalCrossAppSession() {
        sharedGroupDefaults?.removeObject(forKey: "viple.crossapp.store.account")
    }

    public func checkCrossAppVipleAccount(forcePrompt: Bool = false) async {
        // Si l'utilisateur est déjà connecté à un vrai compte Viple (non invité), on annonce sa session
        if isAuthenticated, let u = currentUser, !u.isGuestAccount {
            saveLocalCrossAppSession(user: u)
            await LivriaAPIClient.shared.announceCrossAppSession(userId: u.id, email: u.email)
        }

        // Recherche d'un compte Viple actif sur l'autre application (Livria Social)
        var candidate: LivriaCrossAppAccount? = await LivriaAPIClient.shared.discoverCrossAppAccount()

        if candidate == nil,
           let sharedData = sharedGroupDefaults?.data(forKey: "viple.crossapp.social.account"),
           let localDecoded = try? JSONDecoder().decode(LivriaCrossAppAccount.self, from: sharedData) {
            candidate = localDecoded
        }

        guard let found = candidate,
              found.userId > 0,
              !found.email.isEmpty,
              !found.email.lowercased().hasSuffix("@guest.livria.store") else {
            return
        }

        // Si on est déjà connecté au même compte Viple sur Livria Store, ne rien proposer
        if isAuthenticated, let current = currentUser, !current.isGuestAccount {
            if current.id == found.userId || current.email.lowercased() == found.email.lowercased() {
                if detectedCrossAppAccount?.userId == found.userId {
                    isShowingCrossAppSSOPrompt = false
                    detectedCrossAppAccount = nil
                }
                return
            }
        }

        self.detectedCrossAppAccount = found
        if forcePrompt || !dismissedCrossAppUserIds.contains(found.userId) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                self.isShowingCrossAppSSOPrompt = true
            }
        }
    }

    public func acceptDetectedCrossAppAccount() async {
        guard let account = detectedCrossAppAccount else { return }
        isAcceptingCrossAppSSO = true
        authErrorMessage = nil
        defer { isAcceptingCrossAppSSO = false }

        do {
            let res = try await LivriaAPIClient.shared.acceptCrossAppAccount(
                userId: account.userId,
                email: account.email,
                guestUserId: currentGuestUserIdForMerge,
                guestEmail: currentGuestEmailForMerge
            )
            guard res.ok, let user = res.user else {
                showToast(res.error ?? "Impossible de synchroniser le compte Viple Live ID.")
                return
            }
            self.currentUser = user
            self.isAuthenticated = !user.isGuestAccount
            defaults.set(user.email, forKey: savedEmailKey)
            defaults.set(user.id, forKey: savedUserIdKey)
            defaults.removeObject(forKey: savedGuestEmailKey)
            saveLocalCrossAppSession(user: user)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                self.isShowingCrossAppSSOPrompt = false
                self.isShowingAuthSheet = false
            }
            showToast("Connecté automatiquement à \(user.displayName) depuis \(account.sourceApp) ✨")
            await refreshBootstrap(email: user.email, userId: user.id)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func dismissCrossAppPrompt() {
        if let uid = detectedCrossAppAccount?.userId {
            dismissedCrossAppUserIds.insert(uid)
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            isShowingCrossAppSSOPrompt = false
        }
    }

    // MARK: - Abonnement Looby+ par Achat Intégré Apple (StoreKit 2 In-App Purchase - Sans obligation d'inscription préalable)

    public func preloadLoobyPlusStoreKitProductAndEntitlements() async {
        do {
            let products = try await Product.products(for: [Self.loobyPlusProductID])
            if let product = products.first {
                self.loobyPlusStoreKitProduct = product
            }
        } catch {
            print("[StoreKit] Impossible de précharger le produit Looby+: \(error.localizedDescription)")
        }

        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.loobyPlusProductID {
                self.hasLocalStoreKitLoobyPlusEntitlement = true
                let targetUid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
                let targetEmail = currentUser?.email ?? defaults.string(forKey: savedEmailKey) ?? getOrCreateGuestEmail()
                _ = try? await LivriaAPIClient.shared.activateLoobyPlusIap(
                    userId: targetUid,
                    email: targetEmail,
                    cid: currentUser?.cid,
                    productId: transaction.productID,
                    transactionId: String(transaction.id)
                )
                break
            }
        }
    }

    public func purchaseLoobyPlusInApp() async {
        // Guideline 5.1.1(v) : L'achat In-App Looby+ est accessible immédiatement sans obliger l'utilisateur à créer un compte au préalable.
        isPurchasingLoobyPlus = true
        defer { isPurchasingLoobyPlus = false }

        let targetUid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        let targetEmail = currentUser?.email ?? defaults.string(forKey: savedEmailKey) ?? getOrCreateGuestEmail()
        let targetCid = currentUser?.cid

        do {
            let product: Product
            if let cached = loobyPlusStoreKitProduct {
                product = cached
            } else {
                let products = try await Product.products(for: [Self.loobyPlusProductID])
                guard let firstProduct = products.first else {
                    loobyPlusUnavailableMessage = "Le produit d'abonnement App Store (\(Self.loobyPlusProductID) — 3,50 € / mois) est en cours de chargement auprès d'Apple. Veuillez vérifier votre connexion à l'App Store et réessayer."
                    isShowingLoobyPlusUnavailableAlert = true
                    return
                }
                self.loobyPlusStoreKitProduct = firstProduct
                product = firstProduct
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.hasLocalStoreKitLoobyPlusEntitlement = true
                    if var updatedUser = currentUser {
                        updatedUser.isLivriaPlus = true
                        currentUser = updatedUser
                    }
                    if var updatedPlus = loobyPlus {
                        updatedPlus.isSubscribed = true
                        loobyPlus = updatedPlus
                    }
                    let res = try? await LivriaAPIClient.shared.activateLoobyPlusIap(
                        userId: targetUid,
                        email: targetEmail,
                        cid: targetCid,
                        productId: product.id,
                        transactionId: String(transaction.id)
                    )
                    showToast((res?["message"] as? String) ?? "Abonnement Looby+ activé via l'App Store !")
                    await refreshBootstrap()
                case .unverified(_, _):
                    showToast("La vérification de la transaction App Store a échoué.")
                }
            case .userCancelled:
                break
            case .pending:
                showToast("Votre achat Looby+ est en attente de validation App Store.")
            @unknown default:
                break
            }
        } catch {
            loobyPlusUnavailableMessage = "Impossible de finaliser l'achat sur l'App Store : \(error.localizedDescription)"
            isShowingLoobyPlusUnavailableAlert = true
        }
    }

    public func restoreLoobyPlusPurchases() async {
        // Guideline 5.1.1(v) : La restauration d'un abonnement App Store ne nécessite pas d'inscription obligatoire.
        isPurchasingLoobyPlus = true
        defer { isPurchasingLoobyPlus = false }

        let targetUid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        let targetEmail = currentUser?.email ?? defaults.string(forKey: savedEmailKey) ?? getOrCreateGuestEmail()
        let targetCid = currentUser?.cid

        do {
            try await AppStore.sync()
            var foundActive = false
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let transaction) = entitlement,
                   transaction.productID == Self.loobyPlusProductID {
                    foundActive = true
                    self.hasLocalStoreKitLoobyPlusEntitlement = true
                    if var updatedUser = currentUser {
                        updatedUser.isLivriaPlus = true
                        currentUser = updatedUser
                    }
                    if var updatedPlus = loobyPlus {
                        updatedPlus.isSubscribed = true
                        loobyPlus = updatedPlus
                    }
                    _ = try? await LivriaAPIClient.shared.activateLoobyPlusIap(
                        userId: targetUid,
                        email: targetEmail,
                        cid: targetCid,
                        productId: transaction.productID,
                        transactionId: String(transaction.id)
                    )
                    break
                }
            }
            if foundActive {
                showToast("Votre abonnement Looby+ a bien été restauré !")
                await refreshBootstrap()
            } else {
                showToast("Aucun abonnement Looby+ actif n'a été trouvé sur ce compte Apple.")
            }
        } catch {
            showToast("Impossible de restaurer les achats : \(error.localizedDescription)")
        }
    }

    public func cancelLoobyPlusSubscription() async -> Bool {
        isPurchasingLoobyPlus = true
        defer { isPurchasingLoobyPlus = false }

        do {
            let res = try await LivriaAPIClient.shared.postRaw("/loobyplus/cancel", body: userAuthFields)
            self.hasLocalStoreKitLoobyPlusEntitlement = false
            if var updatedUser = currentUser {
                updatedUser.isLivriaPlus = false
                currentUser = updatedUser
            }
            if var updatedPlus = loobyPlus {
                updatedPlus.isSubscribed = false
                loobyPlus = updatedPlus
            }
            showToast((res["message"] as? String) ?? "Votre abonnement Looby+ a bien été résilié.")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - 2. Synchronisation Globale (/api/mobile/v1/bootstrap)

    public func refreshBootstrap(email: String? = nil, userId: Int? = nil) async {
        let activeEmail = email
            ?? (isAuthenticated ? defaults.string(forKey: savedEmailKey) : nil)
            ?? currentUser?.email
            ?? getOrCreateGuestEmail()
        let activeUid = userId ?? currentUser?.id

        do {
            let boot = try await LivriaAPIClient.shared.fetchBootstrap(email: activeEmail, userId: (activeUid ?? 0) > 0 ? activeUid : nil)
            var incomingUser = boot.user
            let localSavedTheme = defaults.string(forKey: savedThemeKey)
            if let localSavedTheme, !localSavedTheme.isEmpty {
                self.selectedThemeId = localSavedTheme
                incomingUser.themeId = localSavedTheme
            } else if !incomingUser.themeId.isEmpty && incomingUser.themeId != "none" && incomingUser.themeId != "default" {
                self.selectedThemeId = incomingUser.themeId
                defaults.set(incomingUser.themeId, forKey: savedThemeKey)
            }

            if self.hasLocalStoreKitLoobyPlusEntitlement {
                incomingUser.isLivriaPlus = true
            }

            self.currentUser = incomingUser
            self.isAuthenticated = !incomingUser.isGuestAccount
            self.homeData = boot.home
            self.books = boot.books
            self.genres = boot.genres
            if let pendingId = self.pendingDeepLinkedBookId,
               let targetBook = boot.books.first(where: { $0.id == pendingId }) {
                self.pendingDeepLinkedBookId = nil
                self.scannedBookForDetail = targetBook
            }
            self.cart = boot.cart
            self.orders = boot.orders
            self.shelf = Self.mergeShelfAndOrders(serverShelf: boot.shelf ?? [], orders: boot.orders, catalogBooks: boot.books)
            self.trades = boot.trades
            var incomingPlus = boot.loobyPlus
            if self.hasLocalStoreKitLoobyPlusEntitlement {
                incomingPlus?.isSubscribed = true
            }
            self.loobyPlus = incomingPlus
            self.relays = boot.relays
            self.games = boot.games
            self.supportTickets = boot.supportTickets
            if let ps = boot.paymentSettings {
                self.paymentSettings = ps
            }

            if !incomingUser.isGuestAccount {
                defaults.set(incomingUser.email, forKey: savedEmailKey)
                saveLocalCrossAppSession(user: incomingUser)
            }
            defaults.set(incomingUser.id, forKey: savedUserIdKey)
            self.isServerUnreachable = false
        } catch {
            print("[LivriaStore.iOS] Erreur bootstrap: \(error.localizedDescription)")
            self.serverUnreachableMessage = LivriaAPIClient.serverLunchBreakMessage
            self.isServerUnreachable = true
            self.showToast(LivriaAPIClient.serverLunchBreakMessage)
        }
    }

    public func refreshPaymentSettings() async {
        if let settings: LivriaPaymentSettings = try? await LivriaAPIClient.shared.getJSON("/payment-settings") {
            self.paymentSettings = settings
        }
    }

    private var userAuthFields: [String: Any] {
        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey) ?? getOrCreateGuestEmail()
        let uid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        return [
            "userId": uid,
            "email": email
        ]
    }

    // MARK: - 3. Boutique, Recherche Membres, Scanner ISBN & Avis

    public func submitBookReview(bookId: Int, rating: Int, comment: String) async -> Bool {
        var payload = userAuthFields
        payload["rating"] = rating
        payload["comment"] = comment
        do {
            _ = try await LivriaAPIClient.shared.postRaw("/books/\(bookId)/review", body: payload)
            showToast("Merci ! Votre avis a été publié (+15 XP).")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func lookupISBN(_ isbn: String) async -> LivriaIsbnLookupResponse? {
        do {
            return try await LivriaAPIClient.shared.lookupISBN(isbn)
        } catch {
            showToast("ISBN non reconnu : \(error.localizedDescription)")
            return nil
        }
    }

    public func lookupBookByISBN(isbn: String) async -> LivriaIsbnLookupResponse? {
        await lookupISBN(isbn)
    }

    public func performMemberSearch(query: String) async {
        do {
            let res = try await LivriaAPIClient.shared.searchMembersResponse(query: query)
            searchedMembers = res.members
            if let redirectEnabled = res.loobySocialAppStoreRedirectEnabled {
                paymentSettings.loobySocialAppStoreRedirectEnabled = redirectEnabled
            }
            if let appStoreUrl = res.loobySocialAppStoreUrl, !appStoreUrl.isEmpty {
                paymentSettings.loobySocialAppStoreUrl = appStoreUrl
            }
        } catch {
            searchedMembers = []
        }
    }

    public func searchMembers(query: String) async {
        await performMemberSearch(query: query)
    }

    // MARK: - 4. Panier (Neuf & Occasion), Abonnement Looby+ & Checkout (Achat avec ou sans compte Viple Live ID — Guideline 5.1.1(v))

    @discardableResult
    public func requireAuthenticationForPurchase(reason: String = "acheter sur Livria Store") -> Bool {
        // Guideline 5.1.1(v) : L'application autorise l'achat et l'abonnement sans inscription obligatoire.
        return true
    }

    public func addToCart(bookId: Int, format: String = "Broché", quantity: Int = 1) async {
        var payload = userAuthFields
        payload["bookId"] = bookId
        payload["format"] = format
        payload["quantity"] = quantity
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/cart/add", body: payload)
            let msg = (res["message"] as? String) ?? "Ajouté au panier (\(format)) !"
            showToast(msg)
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func updateCartItem(bookId: Int, format: String, quantity: Int) async {
        var payload = userAuthFields
        payload["bookId"] = bookId
        payload["format"] = format
        payload["quantity"] = quantity
        do {
            _ = try await LivriaAPIClient.shared.postRaw("/cart/update", body: payload)
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func addLoobyPlusSubscriptionToCart(openCheckoutImmediately: Bool = false) async {
        // Sur iOS, l'abonnement Looby+ passe exclusivement par l'achat intégré Apple StoreKit 2 (Guideline 3.1.1 / 3.1.2)
        await purchaseLoobyPlusInApp()
    }

    public func createPayPalExpressSession(walletSource: String, amount: Double) async -> LivriaPayPalCreateResponse? {
        do {
            return try await LivriaAPIClient.shared.createPayPalExpressOrder(amount: max(0.50, amount), walletSource: walletSource)
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    public func placeOrder(
        email: String = "",
        guestEmail: String = "",
        firstName: String,
        lastName: String,
        phone: String,
        address: String,
        postalCode: String,
        city: String,
        paymentMethod: String = "PayPal",
        pointsToSpend: Int,
        cashbackToSpend: Double,
        isGiftWrapped: Bool,
        giftMessage: String,
        isZeroWaste: Bool,
        isClickAndCollect: Bool,
        relayId: Int?,
        walletSource: String = "paypal",
        payPalOrderId: String? = nil,
        addSuspendedBook: Bool = false
    ) async -> LivriaCheckoutResponse? {
        let fallbackEmail = currentUser?.email ?? getOrCreateGuestEmail()
        let resolvedEmail = !guestEmail.isEmpty ? guestEmail : (!email.isEmpty ? email : fallbackEmail)
        let resolvedWallet: String = {
            if paymentMethod.lowercased().contains("apple") { return "apple_pay" }
            if paymentMethod.lowercased().contains("google") { return "google_pay" }
            return walletSource
        }()
        var payload = userAuthFields
        payload["guestEmail"] = resolvedEmail
        payload["email"] = resolvedEmail
        payload["firstName"] = firstName
        payload["lastName"] = lastName
        payload["phone"] = phone
        payload["address"] = address
        payload["postalCode"] = postalCode
        payload["city"] = city
        payload["pointsToSpend"] = pointsToSpend
        payload["cashbackToSpend"] = cashbackToSpend
        payload["isGiftWrapped"] = isGiftWrapped
        payload["giftMessage"] = giftMessage
        payload["isZeroWaste"] = isZeroWaste
        payload["isClickAndCollect"] = isClickAndCollect
        payload["walletSource"] = resolvedWallet
        payload["addSuspendedBook"] = addSuspendedBook
        if let payPalOrderId, !payPalOrderId.isEmpty {
            payload["payPalOrderId"] = payPalOrderId
        }
        if let relayId {
            payload["relayId"] = relayId
        }

        do {
            let res: LivriaCheckoutResponse = try await LivriaAPIClient.shared.postJSON("/checkout", body: payload)
            if res.ok {
                showToast(res.message ?? "Commande validée avec succès !")
                await refreshBootstrap()
            } else {
                showToast(res.error ?? "Erreur lors de la validation de la commande.")
            }
            return res
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    public func finalizePostCheckoutAccount(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        phone: String,
        address: String,
        postalCode: String,
        city: String,
        orderReference: String
    ) async -> Bool {
        let digits = orderReference.filter { $0.isNumber }
        let orderId = Int(digits)
        let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let res = await finalizeGuestPostOrderAccount(
            guestUserId: currentUser?.id,
            orderId: orderId,
            email: email,
            displayName: displayName.isEmpty ? "Membre Viple Live ID" : displayName,
            password: password,
            mode: "create"
        )
        if res?.ok == true {
            return true
        }
        authErrorMessage = res?.error ?? "Impossible d'activer le compte."
        return false
    }

    /// Activation ou connexion en 1 clic après une commande sans compte (Email & Nom pré-remplis, seul le mot de passe est saisi)
    public func finalizeGuestPostOrderAccount(
        guestUserId: Int?,
        orderId: Int?,
        email: String,
        displayName: String,
        password: String,
        mode: String
    ) async -> LivriaFinalizeAccountResponse? {
        do {
            let res = try await LivriaAPIClient.shared.finalizePostOrderGuestAccount(
                guestUserId: guestUserId ?? currentUser?.id,
                orderId: orderId,
                email: email,
                displayName: displayName,
                password: password,
                mode: mode
            )
            if res.ok, let user = res.user {
                self.currentUser = user
                self.isAuthenticated = true
                defaults.set(user.email, forKey: savedEmailKey)
                defaults.set(user.id, forKey: savedUserIdKey)
                showToast(res.message ?? "Compte activé et commande rattachée !")
                await refreshBootstrap(email: user.email, userId: user.id)
            }
            return res
        } catch {
            return LivriaFinalizeAccountResponse(ok: false, error: error.localizedDescription)
        }
    }

    public func cancelOrder(orderId: Int) async {
        var payload = userAuthFields
        payload["orderId"] = orderId
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/orders/cancel", body: payload)
            showToast((res["message"] as? String) ?? "Commande annulée.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 5. Troc de Livres (avec auto-remplissage ISBN Google Books / OpenLibrary)

    public func createTradeOffer(
        title: String,
        author: String,
        condition: String,
        wants: String,
        description: String,
        coverUrl: String? = nil
    ) async {
        var payload = userAuthFields
        payload["title"] = title
        payload["author"] = author
        payload["condition"] = condition
        payload["wants"] = wants
        payload["description"] = description
        if let coverUrl, !coverUrl.isEmpty {
            payload["coverUrl"] = coverUrl
        }
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/trades/offer", body: payload)
            showToast((res["message"] as? String) ?? "Offre de troc publiée (+10 XP) !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func removeTradeOffer(offerId: Int) async {
        var payload = userAuthFields
        payload["offerId"] = offerId
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/trades/offer/remove", body: payload)
            showToast((res["message"] as? String) ?? "Offre retirée.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func proposeTrade(offerId: Int, proposedBook: String, message: String) async {
        var payload = userAuthFields
        payload["offerId"] = offerId
        payload["proposedBook"] = proposedBook
        payload["message"] = message
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/trades/request", body: payload)
            showToast((res["message"] as? String) ?? "Proposition d'échange envoyée !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func respondToTrade(requestId: Int, accept: Bool) async {
        var payload = userAuthFields
        payload["requestId"] = requestId
        payload["accept"] = accept
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/trades/respond", body: payload)
            showToast((res["message"] as? String) ?? (accept ? "Troc accepté !" : "Demande déclinée."))
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 6. Looby+ (Box Surprise, Famille, Crédit Audio)

    public func saveBoxPreferences(genres: String, dislikedTropes: String, notes: String, address: String) async {
        var payload = userAuthFields
        payload["preferredGenres"] = genres
        payload["dislikedTropes"] = dislikedTropes
        payload["specialNotes"] = notes
        payload["shippingAddress"] = address
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/loobyplus/box", body: payload)
            showToast((res["message"] as? String) ?? "Préférences Box Surprise enregistrées !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func addFamilyMember(name: String, isKidsMode: Bool) async {
        var payload = userAuthFields
        payload["name"] = name
        payload["avatar"] = "👨‍👩‍👧‍👦"
        payload["isKidsMode"] = isKidsMode
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/loobyplus/family/add", body: payload)
            showToast((res["message"] as? String) ?? "Membre ajouté au partage familial Looby+ !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func removeFamilyMember(memberId: Int) async {
        var payload = userAuthFields
        payload["memberId"] = memberId
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/loobyplus/family/remove", body: payload)
            showToast((res["message"] as? String) ?? "Membre retiré.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func redeemAudioCredit(bookId: Int) async {
        var payload = userAuthFields
        payload["bookId"] = bookId
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/loobyplus/redeem-audio", body: payload)
            showToast((res["message"] as? String) ?? "Livre audio débloqué avec votre crédit Looby+ !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 7. Points Relais Communautaires & UPS Access Point™

    public func searchUpsRelays(
        query: String? = nil,
        cp: String? = nil,
        ville: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil
    ) async -> [LivriaUpsPickupPoint] {
        do {
            let res = try await LivriaAPIClient.shared.searchUpsRelays(query: query, cp: cp, ville: ville, lat: lat, lon: lon)
            if !res.points.isEmpty {
                if var currentRelays = self.relays {
                    currentRelays.upsPoints = res.points
                    self.relays = currentRelays
                }
            }
            return res.points
        } catch {
            return relays?.upsPoints ?? []
        }
    }

    public func searchUpsRelaysDetailed(
        query: String? = nil,
        cp: String? = nil,
        ville: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil
    ) async -> LivriaUpsSearchResponse? {
        do {
            let res = try await LivriaAPIClient.shared.searchUpsRelays(query: query, cp: cp, ville: ville, lat: lat, lon: lon)
            if !res.points.isEmpty, var currentRelays = self.relays {
                currentRelays.upsPoints = res.points
                self.relays = currentRelays
            }
            return res
        } catch {
            return nil
        }
    }

    public func createCommunityRelay(
        name: String,
        type: String,
        address: String,
        city: String,
        postalCode: String,
        openingHours: String,
        description: String
    ) async {
        var payload = userAuthFields
        payload["name"] = name
        payload["type"] = type
        payload["address"] = address
        payload["city"] = city
        payload["postalCode"] = postalCode
        payload["openingHours"] = openingHours
        payload["description"] = description
        payload["latitude"] = 48.8566
        payload["longitude"] = 2.3522
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/relays/community/create", body: payload)
            showToast((res["message"] as? String) ?? "Point relais communautaire ajouté !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 7b. Candidature & Statut « Devenir Viple Taker » (Point Relais Particulier — 1,00 € / colis)

    public func fetchTakerApplicationStatus() async {
        var items: [URLQueryItem] = []
        if let email = currentUser?.email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let uid = currentUser?.id, uid > 0 {
            items.append(URLQueryItem(name: "userId", value: String(uid)))
        }
        do {
            let res: LivriaTakerStatusResponse = try await LivriaAPIClient.shared.getJSON("/taker/status", queryItems: items)
            self.takerApplication = res.application
        } catch { }
    }

    public func submitTakerApplication(
        firstName: String,
        lastName: String,
        phone: String,
        relayName: String,
        address: String,
        postalCode: String,
        city: String,
        housingType: String,
        storageCapacity: String,
        openingHours: String,
        motivationAndAccessNotes: String,
        supplementaryResponse: String = ""
    ) async -> Bool {
        var payload = userAuthFields
        payload["applicationId"] = takerApplication?.id ?? 0
        payload["displayName"] = currentUser?.displayName ?? "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        payload["firstName"] = firstName
        payload["lastName"] = lastName
        payload["phone"] = phone
        payload["relayName"] = relayName
        payload["address"] = address
        payload["postalCode"] = postalCode
        payload["city"] = city
        payload["housingType"] = housingType
        payload["storageCapacity"] = storageCapacity
        payload["openingHours"] = openingHours
        payload["motivationAndAccessNotes"] = motivationAndAccessNotes
        payload["supplementaryResponse"] = supplementaryResponse
        payload["sourceApp"] = "Livria Store"

        do {
            let res = try await LivriaAPIClient.shared.postRaw("/taker/apply", body: payload)
            let msg = (res["message"] as? String) ?? "Votre candidature Viple Taker (1 €/colis) a été envoyée !"
            showToast(msg)
            await fetchTakerApplicationStatus()
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func cancelTakerApplication() async -> Bool {
        var payload = userAuthFields
        payload["applicationId"] = takerApplication?.id ?? 0
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/taker/cancel", body: payload)
            let msg = (res["message"] as? String) ?? "Votre demande Viple Taker a été annulée."
            showToast(msg)
            await fetchTakerApplicationStatus()
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func uploadCroppedAvatar(imageData: Data) async -> Bool {
        var payload = userAuthFields
        payload["extension"] = "jpg"
        payload["base64Data"] = imageData.base64EncodedString()
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/profile/avatar", body: payload)
            if let avatarUrl = res["avatarUrl"] as? String, !avatarUrl.isEmpty {
                self.currentUser?.avatarUrl = avatarUrl
            }
            showToast((res["message"] as? String) ?? "Photo de profil recadrée et enregistrée !")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func openLivriaMarketplaceApp() {
        #if canImport(UIKit)
        var components = URLComponents(string: "livriamarketplace://home")!
        if isAuthenticated, let user = currentUser, !user.isGuestAccount {
            components.queryItems = [
                URLQueryItem(name: "ssoUid", value: String(user.id)),
                URLQueryItem(name: "ssoEmail", value: user.email),
                URLQueryItem(name: "ssoName", value: user.displayName),
                URLQueryItem(name: "ssoAvatar", value: user.avatarUrl),
                URLQueryItem(name: "ssoSource", value: "Livria Store")
            ]
        }
        if let appUrl = components.url {
            UIApplication.shared.open(appUrl, options: [:]) { success in
                if !success, let webFallback = URL(string: "https://livria.store") {
                    UIApplication.shared.open(webFallback)
                }
            }
        }
        #endif
    }

    public func openLivriaSocialApp() {
        #if canImport(UIKit)
        var components = URLComponents(string: "livriasocial://feed")!
        if isAuthenticated, let user = currentUser, !user.isGuestAccount {
            components.queryItems = [
                URLQueryItem(name: "ssoUid", value: String(user.id)),
                URLQueryItem(name: "ssoEmail", value: user.email),
                URLQueryItem(name: "ssoName", value: user.displayName),
                URLQueryItem(name: "ssoAvatar", value: user.avatarUrl),
                URLQueryItem(name: "ssoSource", value: "Livria Store")
            ]
        }
        if let appUrl = components.url {
            UIApplication.shared.open(appUrl, options: [:]) { success in
                if !success, let webFallback = URL(string: "https://livria.store/communaute") {
                    UIApplication.shared.open(webFallback)
                }
            }
        }
        #endif
    }

    // MARK: - 8. Jeux Littéraires XP

    public func claimDailyGameBonus() async {
        let payload = userAuthFields
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/games/daily-claim", body: payload)
            showToast((res["message"] as? String) ?? "Bonus quotidien réclamé !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func spinFortuneWheel() async -> String? {
        let payload = userAuthFields
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/games/wheel-spin", body: payload)
            let reward = (res["prizeLabel"] as? String) ?? (res["rewardLabel"] as? String) ?? (res["message"] as? String) ?? "Gain crédité !"
            showToast(reward)
            await refreshBootstrap()
            return reward
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    public func submitGameScore(game: String, score: Int, xp: Int) async {
        var payload = userAuthFields
        payload["game"] = game
        payload["score"] = score
        payload["xp"] = xp
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/games/submit", body: payload)
            showToast((res["message"] as? String) ?? "+\(xp) XP gagnés !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 9. Assistance Synchronisée avec VipleAPI (assistance.viplenetwork.com)

    public func fetchSupportTicketDetail(ticketId: Int) async -> LivriaSupportTicket? {
        do {
            let res: LivriaSupportTicketDetailResponse = try await LivriaAPIClient.shared.getJSON("/support/ticket/\(ticketId)")
            return res.ticket
        } catch {
            return nil
        }
    }

    public func createSupportTicket(subject: String, category: String, body: String) async -> Bool {
        var payload = userAuthFields
        payload["subject"] = subject
        payload["category"] = category
        payload["body"] = body
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/support/create", body: payload)
            showToast((res["message"] as? String) ?? "Ticket créé et synchronisé avec assistance.viplenetwork.com !")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func replyToSupportTicket(ticketId: Int, body: String) async -> Bool {
        var payload = userAuthFields
        payload["ticketId"] = ticketId
        payload["body"] = body
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/support/reply", body: payload)
            showToast((res["message"] as? String) ?? "Réponse envoyée au support Viple !")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - 10. Profil Livria Store & Thème d'Arrière-Plan

    public func updateProfile(
        displayName: String,
        bio: String,
        motto: String,
        favoriteGenres: String,
        yearlyGoal: Int,
        themeId: String,
        themeOpacity: Int = 72,
        firstName: String,
        lastName: String,
        phone: String,
        address: String,
        postalCode: String,
        city: String
    ) async {
        setTheme(themeId)
        var payload = userAuthFields
        payload["displayName"] = displayName
        payload["bio"] = bio
        payload["motto"] = motto
        payload["favoriteGenres"] = favoriteGenres
        payload["yearlyGoal"] = yearlyGoal
        payload["themeId"] = themeId
        payload["themeOpacity"] = themeOpacity
        payload["firstName"] = firstName
        payload["lastName"] = lastName
        payload["phone"] = phone
        payload["address"] = address
        payload["postalCode"] = postalCode
        payload["city"] = city

        do {
            let res = try await LivriaAPIClient.shared.postRaw("/profile/update", body: payload)
            showToast((res["message"] as? String) ?? "Profil Livria Store mis à jour !")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 11. Ouverture Directe d'un Livre depuis Livria Social (livriastore://book/{id})

    public func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "livriastore" || scheme == "https" || scheme == "http" else { return }

        let host = url.host?.lowercased() ?? ""
        let pathParts = url.pathComponents.filter { $0 != "/" }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        // Si Livria Social transmet le compte Viple actif dans les paramètres du lien, on le propose immédiatement
        if let ssoUidStr = queryItems.first(where: { $0.name == "ssoUid" })?.value,
           let ssoUid = Int(ssoUidStr),
           ssoUid > 0,
           let ssoEmail = queryItems.first(where: { $0.name == "ssoEmail" })?.value,
           !ssoEmail.isEmpty,
           !ssoEmail.lowercased().hasSuffix("@guest.livria.store") {
            let ssoName = queryItems.first(where: { $0.name == "ssoName" })?.value ?? "Lecteur Viple"
            let ssoAvatar = queryItems.first(where: { $0.name == "ssoAvatar" })?.value ?? ""
            let ssoSource = queryItems.first(where: { $0.name == "ssoSource" })?.value ?? "Livria Social"
            let incomingAccount = LivriaCrossAppAccount(
                sourceApp: ssoSource,
                userId: ssoUid,
                email: ssoEmail,
                displayName: ssoName,
                firstName: "",
                lastName: "",
                avatarUrl: ssoAvatar,
                level: 1,
                xp: 100,
                isLivriaPlus: false
            )
            let isAlreadySameUser = isAuthenticated
                && currentUser?.isGuestAccount == false
                && (currentUser?.id == ssoUid || currentUser?.email.lowercased() == ssoEmail.lowercased())
            if !isAlreadySameUser {
                self.detectedCrossAppAccount = incomingAccount
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    self.isShowingCrossAppSSOPrompt = true
                }
            }
        }

        Task {
            await checkCrossAppVipleAccount(forcePrompt: true)
        }

        // Ouverture directe de l'onglet Troc depuis Livria Marketplace (livriastore://troc)
        if host == "troc" || host == "trades" || pathParts.contains(where: { $0.lowercased() == "troc" || $0.lowercased() == "trades" }) {
            selectedMainTab = 2
            return
        }
        if host == "taker" || host == "relays" || pathParts.contains(where: { $0.lowercased() == "taker" || $0.lowercased() == "relays" }) {
            selectedMainTab = 4
            return
        }

        var extractedBookId: Int? = nil
        if (host == "book" || host == "livre" || host == "books"),
           let first = pathParts.first,
           let id = Int(first) {
            extractedBookId = id
        } else if let idx = pathParts.firstIndex(where: {
            let p = $0.lowercased()
            return p == "book" || p == "livre" || p == "books"
        }), pathParts.count > idx + 1, let id = Int(pathParts[idx + 1]) {
            extractedBookId = id
        } else if let idStr = queryItems.first(where: { $0.name == "id" || $0.name == "bookId" })?.value,
                  let id = Int(idStr) {
            extractedBookId = id
        } else if scheme == "livriastore", let id = Int(host) {
            extractedBookId = id
        }

        guard let bookId = extractedBookId, bookId > 0 else { return }

        if let found = books.first(where: { $0.id == bookId }) {
            pendingDeepLinkedBookId = nil
            scannedBookForDetail = found
        } else {
            pendingDeepLinkedBookId = bookId
            Task {
                await refreshBootstrap()
            }
        }
    }

    // MARK: - 12. Favoris ❤️, Récemment Consultés, Recherches Récentes & Notes de Lecture Personnelles

    public func triggerHaptic() {
        guard userPreferences.hapticFeedback else { return }
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    public func isFavoriteBook(_ bookId: Int) -> Bool {
        favoriteBookIds.contains(bookId)
    }

    public func toggleFavoriteBook(_ book: LivriaBook) {
        triggerHaptic()
        if favoriteBookIds.contains(book.id) {
            favoriteBookIds.remove(book.id)
            showToast("Retiré de vos coups de cœur (\(book.title))")
        } else {
            favoriteBookIds.insert(book.id)
            showToast("❤️ Ajouté à vos coups de cœur (\(book.title))")
        }
        defaults.set(Array(favoriteBookIds), forKey: savedFavoritesKey)
    }

    public var favoriteBooks: [LivriaBook] {
        books.filter { favoriteBookIds.contains($0.id) }
    }

    public func recordBookViewed(_ bookId: Int) {
        guard bookId > 0 else { return }
        var updated = recentlyViewedBookIds.filter { $0 != bookId }
        updated.insert(bookId, at: 0)
        if updated.count > 20 {
            updated = Array(updated.prefix(20))
        }
        recentlyViewedBookIds = updated
        defaults.set(updated, forKey: savedRecentlyViewedKey)
    }

    public func clearRecentlyViewedBooks() {
        recentlyViewedBookIds = []
        defaults.removeObject(forKey: savedRecentlyViewedKey)
        showToast("Historique des livres récemment consultés effacé.")
    }

    public var recentlyViewedBooks: [LivriaBook] {
        recentlyViewedBookIds.compactMap { id in
            books.first(where: { $0.id == id })
        }
    }

    public func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        var updated = recentSearchQueries.filter { $0.localizedCaseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > 12 {
            updated = Array(updated.prefix(12))
        }
        recentSearchQueries = updated
        defaults.set(updated, forKey: savedRecentSearchesKey)
    }

    public func removeRecentSearch(_ query: String) {
        recentSearchQueries.removeAll { $0 == query }
        defaults.set(recentSearchQueries, forKey: savedRecentSearchesKey)
    }

    public func clearRecentSearches() {
        recentSearchQueries = []
        defaults.removeObject(forKey: savedRecentSearchesKey)
    }

    public func readingNote(for bookId: Int) -> String {
        bookReadingNotes[bookId] ?? ""
    }

    public func saveReadingNote(bookId: Int, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            bookReadingNotes.removeValue(forKey: bookId)
        } else {
            bookReadingNotes[bookId] = trimmed
        }
        if let encoded = try? JSONEncoder().encode(bookReadingNotes) {
            defaults.set(encoded, forKey: savedReadingNotesKey)
        }
        triggerHaptic()
        showToast("Note de lecture personnelle enregistrée.")
    }

    public func addReadingMinutes(bookId: Int, minutes: Int) {
        guard minutes > 0 else { return }
        let current = readingMinutesByBook[bookId] ?? 0
        readingMinutesByBook[bookId] = current + minutes
        if let encoded = try? JSONEncoder().encode(readingMinutesByBook) {
            defaults.set(encoded, forKey: savedReadingMinutesKey)
        }
        triggerHaptic()
        showToast("+\(minutes) min ajoutées à votre journal de lecture !")
    }

    public var totalReadingMinutes: Int {
        readingMinutesByBook.values.reduce(0, +)
    }

    // MARK: - 13. Suivi Natif Viple Delivery Intégré (Sans ouvrir Safari)

    public func trackOrderInApp(order: LivriaOrder) async {
        isTrackingLoading = true
        defer { isTrackingLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.trackVipleDelivery(
                trackingNumber: order.trackingNumber,
                orderId: order.id,
                reference: order.reference
            )
            self.activeTrackingResult = res
            self.isShowingVipleDeliverySheet = true
        } catch {
            // Fallback local immédiat à partir de la commande pour garantir l'ouverture même si le réseau est lent
            let fallbackSteps = [
                LivriaVipleDeliveryStep(index: 0, label: "Validée", subtitle: "Commande enregistrée", isCompleted: true, isCurrent: order.status == "Pending"),
                LivriaVipleDeliveryStep(index: 1, label: "Préparation", subtitle: "Bordereau Viple Delivery édité", isCompleted: order.status != "Pending", isCurrent: order.status == "Paid" || order.status == "Processing"),
                LivriaVipleDeliveryStep(index: 2, label: "En transit", subtitle: "Pris en charge par \(order.carrier)", isCompleted: order.status == "Shipped" || order.status == "Delivered", isCurrent: order.status == "Shipped"),
                LivriaVipleDeliveryStep(index: 3, label: "Livrée", subtitle: "Colis remis au destinataire", isCompleted: order.status == "Delivered", isCurrent: order.status == "Delivered")
            ]
            self.activeTrackingResult = LivriaVipleDeliveryTrackResponse(
                ok: true,
                found: true,
                error: nil,
                source: "LivriaStore",
                orderId: order.id,
                reference: order.reference,
                trackingNumber: order.trackingNumber ?? order.reference,
                vipleDeliveryBarcode: order.effectiveVipleBarcode,
                carrier: order.carrier,
                statusCode: order.status,
                statusLabel: order.status == "Delivered" ? "Livrée" : (order.status == "Shipped" ? "Expédiée • En transit" : "En préparation Viple Delivery"),
                currentStepIndex: order.currentStepIndex ?? (order.status == "Delivered" ? 3 : (order.status == "Shipped" ? 2 : 1)),
                totalSteps: 4,
                createdAt: order.createdAt,
                estimatedDelivery: order.estimatedDelivery ?? "Sous 48h ouvrées",
                shippingAddress: order.shippingAddress,
                isRelayDelivery: order.isClickAndCollect,
                relayBadge: order.isClickAndCollect ? "Point Relais / Viple Taker" : "Livraison à domicile",
                totalAmount: order.total,
                labelUrl: order.effectiveLabelUrl,
                canCancel: order.status != "Delivered" && order.status != "Cancelled",
                steps: fallbackSteps,
                events: [
                    LivriaVipleDeliveryEvent(
                        timestamp: order.createdAt,
                        statusLabel: "Suivi Viple Delivery actif",
                        location: order.shippingAddress.isEmpty ? "Plateforme Logistique Livria" : order.shippingAddress,
                        description: "Suivi en direct de votre commande \(order.reference).",
                        isHighlight: true
                    )
                ],
                items: order.items.map {
                    LivriaVipleDeliveryItemSummary(
                        title: $0.title,
                        author: $0.author,
                        coverUrl: $0.coverUrl,
                        quantity: $0.quantity,
                        format: $0.format,
                        unitPrice: $0.unitPrice
                    )
                }
            )
            self.isShowingVipleDeliverySheet = true
        }
    }

    public func trackParcelByCodeInApp(_ rawCode: String) async {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            showToast("Saisissez un numéro de commande (#LIV-...) ou de suivi (1Z... / VD-...).")
            return
        }
        isTrackingLoading = true
        defer { isTrackingLoading = false }
        do {
            let res = try await LivriaAPIClient.shared.trackVipleDelivery(
                trackingNumber: code,
                orderId: nil,
                reference: code
            )
            if res.found {
                self.activeTrackingResult = res
                self.isShowingVipleDeliverySheet = true
            } else {
                showToast(res.error ?? "Aucun colis trouvé pour ce numéro.")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func refreshUserShipments() async {
        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey)
        let uid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        if let res = try? await LivriaAPIClient.shared.fetchUserShipments(userId: uid > 0 ? uid : nil, email: email) {
            self.userShipments = res.shipments
        }
    }

    // MARK: - 14. Préférences Synchronisées, Cache, RGPD & Diagnostics

    public func saveAndSyncPreferences(_ updated: LivriaUserPreferences) async {
        self.userPreferences = updated
        if let encoded = try? JSONEncoder().encode(updated) {
            defaults.set(encoded, forKey: savedPreferencesKey)
        }
        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey)
        let uid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        if let res = try? await LivriaAPIClient.shared.saveUserPreferences(
            userId: uid > 0 ? uid : nil,
            email: email,
            preferences: updated
        ) {
            self.userPreferences = res.preferences
        }
        triggerHaptic()
    }

    public func clearLocalCache() {
        URLCache.shared.removeAllCachedResponses()
        clearRecentSearches()
        clearRecentlyViewedBooks()
        triggerHaptic()
        showToast("Cache réseau et historique local nettoyés avec succès.")
    }

    public func runDiagnosticsCheck() async {
        if let res = try? await LivriaAPIClient.shared.pingDiagnostics() {
            self.lastDiagnosticsPing = res
            showToast("Serveur Livria opérationnel (\(res.dbLatencyMs ?? 1) ms • API \(res.apiVersion))")
        } else {
            showToast("Diagnostic : impossible de joindre le serveur.")
        }
    }

    // MARK: - 15. Ma Bibliothèque & Lecteur Numérique / Audio (Uniquement pour les livres détenus en Numérique / Audio)

    private static func mergeShelfAndOrders(
        serverShelf: [LivriaShelfEntry],
        orders: [LivriaOrder],
        catalogBooks: [LivriaBook]
    ) -> [LivriaShelfEntry] {
        var byBookId: [Int: LivriaShelfEntry] = [:]
        for entry in serverShelf where entry.bookId > 0 {
            byBookId[entry.bookId] = entry
        }

        let validOrders = orders.filter { $0.status.lowercased() != "cancelled" }
        for order in validOrders {
            for item in order.items where item.bookId > 0 {
                let lowerFmt = item.format.lowercased()
                let isDigital = lowerFmt.contains("numérique") || lowerFmt.contains("numerique") || lowerFmt.contains("epub") || lowerFmt.contains("e-book")
                let isAudio = lowerFmt.contains("audio")
                let isPhysical = !isDigital && !isAudio

                if var existing = byBookId[item.bookId] {
                    if isDigital {
                        existing.ownsDigital = true
                        if !existing.ownedFormats.contains("Numérique") {
                            existing.ownedFormats.append("Numérique")
                        }
                    }
                    if isAudio {
                        existing.ownsAudio = true
                        if !existing.ownedFormats.contains("Audio") {
                            existing.ownedFormats.append("Audio")
                        }
                    }
                    if isPhysical {
                        existing.ownsPhysical = true
                        if !existing.ownedFormats.contains("Broché") {
                            existing.ownedFormats.append("Broché")
                        }
                    }
                    existing.isPurchased = true
                    byBookId[item.bookId] = existing
                } else {
                    let catBook = catalogBooks.first(where: { $0.id == item.bookId })
                    var formats: [String] = []
                    if isDigital { formats.append("Numérique") }
                    if isAudio { formats.append("Audio") }
                    if isPhysical || formats.isEmpty { formats.append("Broché") }

                    byBookId[item.bookId] = LivriaShelfEntry(
                        id: 100000 + item.bookId,
                        bookId: item.bookId,
                        title: item.title,
                        author: item.author.isEmpty ? (catBook?.author ?? "Auteur Livria") : item.author,
                        genre: catBook?.displayGenre ?? "Roman",
                        coverUrl: item.coverUrl.isEmpty ? (catBook?.coverUrl ?? "") : item.coverUrl,
                        status: "WantToRead",
                        rating: 5,
                        progress: 0,
                        format: isDigital && isAudio ? "Numérique & Audio" : (isDigital ? "Numérique" : (isAudio ? "Audio" : "Broché")),
                        addedAt: order.createdAt,
                        finishedAt: "",
                        ownsDigital: isDigital,
                        ownsAudio: isAudio,
                        ownsPhysical: isPhysical,
                        ownedFormats: formats,
                        isPurchased: true,
                        hasEpubInCatalog: catBook?.hasEpub ?? isDigital,
                        hasAudioInCatalog: catBook?.hasAudio ?? isAudio,
                        ambientSoundtrack: catBook?.ambientSoundtrack
                    )
                }
            }
        }

        return Array(byBookId.values).sorted { $0.id > $1.id }
    }

    public func shelfEntry(for bookId: Int) -> LivriaShelfEntry? {
        shelf.first(where: { $0.bookId == bookId })
    }

    public func ownsDigitalFormat(for bookId: Int) -> Bool {
        shelfEntry(for: bookId)?.ownsDigital == true
    }

    public func ownsAudioFormat(for bookId: Int) -> Bool {
        shelfEntry(for: bookId)?.ownsAudio == true
    }

    public func updateShelf(
        bookId: Int,
        status: String? = nil,
        rating: Int? = nil,
        progress: Double? = nil,
        format: String? = nil
    ) async {
        if let idx = shelf.firstIndex(where: { $0.bookId == bookId }) {
            if let status { shelf[idx].status = status }
            if let rating { shelf[idx].rating = max(1, min(5, rating)) }
            if let progress {
                shelf[idx].progress = max(0, min(100, progress))
                if progress >= 100 {
                    shelf[idx].status = "Read"
                } else if progress > 0 && shelf[idx].status == "WantToRead" {
                    shelf[idx].status = "Reading"
                }
            }
        } else if let catBook = books.first(where: { $0.id == bookId }) {
            let newEntry = LivriaShelfEntry(
                id: Int.random(in: 200000...999999),
                bookId: catBook.id,
                title: catBook.title,
                author: catBook.author,
                genre: catBook.displayGenre,
                coverUrl: catBook.coverUrl,
                status: status ?? "WantToRead",
                rating: rating ?? 5,
                progress: progress ?? 0,
                format: format ?? "Broché",
                addedAt: "Aujourd'hui",
                ownsDigital: false,
                ownsAudio: false,
                ownsPhysical: true,
                ownedFormats: ["Broché"],
                isPurchased: false,
                hasEpubInCatalog: catBook.hasEpub,
                hasAudioInCatalog: catBook.hasAudio,
                ambientSoundtrack: catBook.ambientSoundtrack
            )
            shelf.insert(newEntry, at: 0)
        }

        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey)
        let cid = currentUser?.cid
        _ = try? await LivriaAPIClient.shared.updateShelfEntry(
            email: email,
            cid: cid,
            bookId: bookId,
            status: status,
            rating: rating,
            progress: progress,
            format: format
        )
        triggerHaptic()
    }

    public func removeFromShelf(bookId: Int) async {
        shelf.removeAll { $0.bookId == bookId && !$0.isPurchased }
        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey)
        let cid = currentUser?.cid
        _ = try? await LivriaAPIClient.shared.removeShelfEntry(email: email, cid: cid, bookId: bookId)
        triggerHaptic()
        showToast("Livre retiré de vos étagères.")
    }

    public func fetchBookReaderContent(bookId: Int) async -> LivriaLibraryBookContentResponse? {
        let email = currentUser?.email ?? defaults.string(forKey: savedEmailKey)
        let uid = currentUser?.id ?? defaults.integer(forKey: savedUserIdKey)
        let cid = currentUser?.cid

        if let res = try? await LivriaAPIClient.shared.fetchLibraryBookContent(
            bookId: bookId,
            userId: uid > 0 ? uid : nil,
            email: email,
            cid: cid
        ) {
            return res
        }

        guard let entry = shelfEntry(for: bookId), (entry.ownsDigital || entry.ownsAudio) else {
            return LivriaLibraryBookContentResponse(
                ok: false,
                error: "Ce livre n'est pas détenu au format Numérique ou Audio dans votre bibliothèque.",
                ownsDigital: false,
                ownsAudio: false
            )
        }

        let catBook = books.first(where: { $0.id == bookId })
        let desc = catBook?.description ?? "Édition numérique et audio officielle de « \(entry.title) » par \(entry.author)."
        let fallbackChapters = [
            LivriaBookChapter(
                number: 1,
                title: "Chapitre I — Ouverture : \(entry.title)",
                durationSeconds: 210,
                content: "\(entry.title)\nPar \(entry.author)\n\n\(desc)\n\nDès les premières pages, l'ouvrage installe son atmosphère et pose les jalons essentiels du récit."
            ),
            LivriaBookChapter(
                number: 2,
                title: "Chapitre II — Le Cœur de l'Intrigue",
                durationSeconds: 245,
                content: "Au fil de ce deuxième chapitre de « \(entry.title) », les enjeux et la trajectoire des personnages se précisent sous la plume de \(entry.author)."
            ),
            LivriaBookChapter(
                number: 3,
                title: "Chapitre III — Dénouement & Perspectives",
                durationSeconds: 225,
                content: "Dans cette dernière partie de « \(entry.title) », les fils narratifs convergent vers leur point d'équilibre."
            )
        ]

        return LivriaLibraryBookContentResponse(
            ok: true,
            bookId: entry.bookId,
            title: entry.title,
            author: entry.author,
            genre: entry.genre,
            isbn: catBook?.isbn ?? "",
            coverUrl: entry.coverUrl,
            ownsDigital: entry.ownsDigital,
            ownsAudio: entry.ownsAudio,
            ownedFormats: entry.ownedFormats,
            progress: entry.progress,
            ambientSoundtrack: entry.ambientSoundtrack ?? "rain",
            aiSummary: catBook?.aiSummaryNoSpoil ?? desc,
            audioStreamUrl: entry.audioStreamUrl,
            epubStreamUrl: entry.epubStreamUrl,
            chapters: fallbackChapters
        )
    }
}
