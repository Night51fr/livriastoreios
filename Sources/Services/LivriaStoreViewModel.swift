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
    @Published public var activeToastMessage: String? = nil
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

    // Conditions Générales d'Utilisation & de Vente (obligatoires au 1er lancement)
    @Published public var hasAcceptedTermsOfUse: Bool = false

    // Thème persistant sur toutes les pages de l'application sans exception
    @Published public var selectedThemeId: String = "default"

    // Session Viple Live ID ou Session Invité (Commande sans compte autorisée)
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: LivriaUserProfile? = nil

    // Données Globales synchronisées avec https://livria.store/api/mobile/v1/bootstrap
    @Published public var homeData: LivriaHomeSection? = nil
    @Published public var books: [LivriaBook] = []
    @Published public var genres: [String] = []
    @Published public var cart: [LivriaCartItem] = []
    @Published public var orders: [LivriaOrder] = []
    @Published public var trades: LivriaTradesBundle? = nil
    @Published public var loobyPlus: LivriaLoobyPlusState? = nil
    @Published public var relays: LivriaRelaysBundle? = nil
    @Published public var games: LivriaGamesData? = nil
    @Published public var supportTickets: [LivriaSupportTicket] = []
    @Published public var paymentSettings: LivriaPaymentSettings = LivriaPaymentSettings()

    // Recherche de membres (section Membres de la barre de recherche -> redirige vers Livria Social)
    @Published public var searchedMembers: [LivriaMemberSearchResult] = []

    // Sélection Point Relais pour le Checkout (mis par défaut dans le Checkout lorsqu'il est choisi dans Points Relais)
    @Published public var selectedRelayForCheckout: String? = nil
    @Published public var selectedCommunityRelayId: Int? = nil
    @Published public var selectedUpsPointForCheckout: LivriaUpsPickupPoint? = nil
    @Published public var selectedCommunityRelayForCheckout: LivriaCommunityRelay? = nil

    private let defaults = UserDefaults.standard
    private let acceptedTermsKey = "livria.store.ios.acceptedCGU.v1"
    private let savedThemeKey = "livria.store.ios.selectedThemeId.v2"
    private let savedEmailKey = "livria.store.ios.vipleLiveEmail"
    private let savedUserIdKey = "livria.store.ios.vipleLiveUserId"
    private let savedGuestEmailKey = "livria.store.ios.guestEmail"
    private let savedUpsRelayDataKey = "livria.store.ios.selectedUpsRelay.v1"

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

        let savedEmail = defaults.string(forKey: savedEmailKey)
        let savedUid = defaults.integer(forKey: savedUserIdKey)

        if let email = savedEmail, !email.isEmpty, !email.lowercased().hasSuffix("@guest.livria.store") {
            self.isAuthenticated = true
            Task {
                await refreshBootstrap(email: email, userId: savedUid > 0 ? savedUid : nil)
            }
        } else {
            let guestEmail = getOrCreateGuestEmail()
            self.isAuthenticated = false
            Task {
                await refreshBootstrap(email: guestEmail, userId: savedUid > 0 ? savedUid : nil)
            }
        }
    }

    public func acceptTermsOfUse() {
        defaults.set(true, forKey: acceptedTermsKey)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            hasAcceptedTermsOfUse = true
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
            let freshGuest = getOrCreateGuestEmail()
            isAuthenticated = false
            currentUser = nil
            cart = []
            orders = []
            selectedMainTab = 0
            showToast(msg)
            await refreshBootstrap(email: freshGuest, userId: nil)
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func signOut() {
        defaults.removeObject(forKey: savedEmailKey)
        defaults.removeObject(forKey: savedUserIdKey)
        defaults.removeObject(forKey: savedGuestEmailKey)
        let guestEmail = getOrCreateGuestEmail()
        isAuthenticated = false
        currentUser = nil
        cart = []
        orders = []
        showToast("Vous naviguez désormais en mode Invité sur Livria Store.")
        Task {
            await refreshBootstrap(email: guestEmail, userId: nil)
        }
    }

    // MARK: - Abonnement Looby+ par Achat Intégré Apple (StoreKit 2 In-App Purchase)

    public func purchaseLoobyPlusInApp() async {
        guard isAuthenticated, let user = currentUser, !user.isGuestAccount else {
            isShowingAuthSheet = true
            return
        }
        isPurchasingLoobyPlus = true
        defer { isPurchasingLoobyPlus = false }

        do {
            let products = try await Product.products(for: [Self.loobyPlusProductID])
            if let product = products.first {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        let res = try await LivriaAPIClient.shared.activateLoobyPlusIap(
                            userId: user.id,
                            email: user.email,
                            cid: user.cid,
                            productId: product.id,
                            transactionId: String(transaction.id)
                        )
                        showToast((res["message"] as? String) ?? "Abonnement Looby+ activé via l'App Store !")
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
            } else {
                // Activation StoreKit Sandbox / TestFlight immédiate si le produit n'est pas encore propagé sur App Store Connect
                let res = try await LivriaAPIClient.shared.activateLoobyPlusIap(
                    userId: user.id,
                    email: user.email,
                    cid: user.cid,
                    productId: Self.loobyPlusProductID,
                    transactionId: "SK2-SANDBOX-\(Int(Date().timeIntervalSince1970))"
                )
                showToast((res["message"] as? String) ?? "Abonnement Looby+ (Achat In-App) activé !")
                await refreshBootstrap()
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func restoreLoobyPlusPurchases() async {
        guard isAuthenticated, let user = currentUser, !user.isGuestAccount else {
            isShowingAuthSheet = true
            return
        }
        isPurchasingLoobyPlus = true
        defer { isPurchasingLoobyPlus = false }

        do {
            try await AppStore.sync()
            var foundActive = false
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let transaction) = entitlement,
                   transaction.productID == Self.loobyPlusProductID {
                    foundActive = true
                    _ = try await LivriaAPIClient.shared.activateLoobyPlusIap(
                        userId: user.id,
                        email: user.email,
                        cid: user.cid,
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

            self.currentUser = incomingUser
            self.isAuthenticated = !incomingUser.isGuestAccount
            self.homeData = boot.home
            self.books = boot.books
            self.genres = boot.genres
            self.cart = boot.cart
            self.orders = boot.orders
            self.trades = boot.trades
            self.loobyPlus = boot.loobyPlus
            self.relays = boot.relays
            self.games = boot.games
            self.supportTickets = boot.supportTickets
            if let ps = boot.paymentSettings {
                self.paymentSettings = ps
            }

            if !incomingUser.isGuestAccount {
                defaults.set(incomingUser.email, forKey: savedEmailKey)
            }
            defaults.set(incomingUser.id, forKey: savedUserIdKey)
        } catch {
            print("[LivriaStore.iOS] Erreur bootstrap: \(error.localizedDescription)")
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

    public func refreshPaymentSettings() async {
        if let latest = try? await LivriaAPIClient.shared.fetchPaymentSettings() {
            self.paymentSettings = latest
        }
    }

    public func searchMembers(query: String) async {
        await performMemberSearch(query: query)
    }

    // MARK: - 4. Panier (Neuf & Occasion), Abonnement Looby+ & Checkout (Apple Pay / Google Pay / PayPal + Post-Order 1-Clic)

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
        let payload = userAuthFields
        do {
            let res = try await LivriaAPIClient.shared.postRaw("/cart/add-loobyplus", body: payload)
            let msg = (res["message"] as? String) ?? "Abonnement Looby+ (3,50 €/mois) ajouté au panier !"
            showToast(msg)
            await refreshBootstrap()
            if openCheckoutImmediately {
                isShowingCheckoutSheet = true
            } else {
                isShowingCartSheet = true
            }
        } catch {
            showToast(error.localizedDescription)
        }
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
        let resolvedEmail = !guestEmail.isEmpty ? guestEmail : email
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
}
