import Foundation

// MARK: - Configuration Officielle de l'Application « Livria Store » (App Store ID : 6825159743)

public enum LivriaAppConfig: Sendable {
    public static let appName = "Livria Store"
    public static let appleAppId = "6825159743"
    public static let bundleIdentifier = "com.viplenetwork.livria"
    public static let signingOrganization = "Viple"
    public static let appStoreURL = "https://apps.apple.com/fr/app/livria-store/id6825159743"
    public static let minimumIOSVersion = "18.0"
    public static let enhancedIOSVersion = "26.0"

    // Écosystème séparé selon la nouvelle architecture mobile Viple :
    // 1. Livria Store (id 6825159743) -> Boutique (Neuf & Occasion), Checkout, Looby+ & Troc
    // 2. Livria Social -> Réseau social littéraire, fil d'actualité, listes & messagerie
    // 3. Viple & Moi -> Espaces clients Viple dont Ma Bibliothèque Livria
    public static let livriaSocialWebURL = "https://livriasocial.viplenetwork.com"
    public static let vipleEtMoiWebURL = "https://my.livria.store"
}

// MARK: - Modèles de Données Codable & Sendable Livria Store (Alignés à 100% sur /api/mobile/v1)

public struct LivriaAuthResponse: Codable, Sendable {
    public var ok: Bool
    public var error: String?
    public var token: String?
    public var accountType: String?
    public var hasVipleMailBox: Bool?
    public var requiresApplePasswordSetup: Bool?
    public var icloudEmail: String?
    public var vipleMailAddress: String?
    public var needsOnboarding: Bool?
    public var appleUserId: String?
    public var appleEmail: String?
    public var suggestedFirstName: String?
    public var suggestedLastName: String?
    public var user: LivriaUserProfile?
}

public struct LivriaCrossAppAccount: Codable, Equatable, Sendable, Identifiable {
    public var userId: Int
    public var email: String
    public var displayName: String
    public var firstName: String
    public var lastName: String
    public var cid: String
    public var avatarUrl: String
    public var bio: String
    public var isLivriaPlus: Bool
    public var level: Int
    public var xp: Int
    public var sourceApp: String
    public var targetApp: String

    public var id: Int { userId }

    public init(
        sourceApp: String = "Livria Social",
        targetApp: String = "Livria Store",
        userId: Int,
        email: String,
        displayName: String,
        firstName: String = "",
        lastName: String = "",
        cid: String = "",
        avatarUrl: String = "",
        bio: String = "",
        level: Int = 1,
        xp: Int = 0,
        isLivriaPlus: Bool = false
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.cid = cid
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.isLivriaPlus = isLivriaPlus
        self.level = level
        self.xp = xp
        self.sourceApp = sourceApp
        self.targetApp = targetApp
    }

    enum CodingKeys: String, CodingKey {
        case userId, email, displayName, firstName, lastName, cid, avatarUrl, bio, isLivriaPlus, level, xp, sourceApp, targetApp
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? c.decode(Int.self, forKey: .userId)) ?? 0
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        firstName = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        lastName = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        cid = (try? c.decode(String.self, forKey: .cid)) ?? ""
        avatarUrl = (try? c.decode(String.self, forKey: .avatarUrl)) ?? ""
        bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        isLivriaPlus = (try? c.decode(Bool.self, forKey: .isLivriaPlus)) ?? false
        level = (try? c.decode(Int.self, forKey: .level)) ?? 1
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        sourceApp = (try? c.decode(String.self, forKey: .sourceApp)) ?? "Livria Social"
        targetApp = (try? c.decode(String.self, forKey: .targetApp)) ?? "Livria Store"
    }

    public var fullNameOrDisplay: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? displayName : full
    }

    public var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let str = parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
        return str.isEmpty ? "V" : str
    }
}

public struct LivriaCrossAppDiscoverResponse: Codable, Sendable {
    public var ok: Bool
    public var hasDetectedAccount: Bool
    public var account: LivriaCrossAppAccount?

    public var hasAccount: Bool { hasDetectedAccount }

    enum CodingKeys: String, CodingKey {
        case ok, hasDetectedAccount, hasAccount, account
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        hasDetectedAccount = (try? c.decode(Bool.self, forKey: .hasDetectedAccount))
            ?? (try? c.decode(Bool.self, forKey: .hasAccount))
            ?? false
        account = try? c.decodeIfPresent(LivriaCrossAppAccount.self, forKey: .account)
    }
}

public struct LivriaPaymentSettings: Codable, Equatable, Sendable {
    public var paypalEnabled: Bool
    public var applePayEnabled: Bool
    public var googlePayEnabled: Bool
    public var loobySocialAppStoreRedirectEnabled: Bool
    public var loobySocialAppStoreUrl: String
    public var mobileAppMaintenanceEnabled: Bool

    public init(
        paypalEnabled: Bool = true,
        applePayEnabled: Bool = true,
        googlePayEnabled: Bool = true,
        loobySocialAppStoreRedirectEnabled: Bool = true,
        loobySocialAppStoreUrl: String = "https://apps.apple.com/fr/search?term=LoobySocial",
        mobileAppMaintenanceEnabled: Bool = false
    ) {
        self.paypalEnabled = paypalEnabled
        self.applePayEnabled = applePayEnabled
        self.googlePayEnabled = googlePayEnabled
        self.loobySocialAppStoreRedirectEnabled = loobySocialAppStoreRedirectEnabled
        self.loobySocialAppStoreUrl = loobySocialAppStoreUrl
        self.mobileAppMaintenanceEnabled = mobileAppMaintenanceEnabled
    }

    enum CodingKeys: String, CodingKey {
        case paypalEnabled, applePayEnabled, googlePayEnabled
        case loobySocialAppStoreRedirectEnabled, loobySocialAppStoreUrl
        case mobileAppMaintenanceEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paypalEnabled = (try? c.decode(Bool.self, forKey: .paypalEnabled)) ?? true
        applePayEnabled = (try? c.decode(Bool.self, forKey: .applePayEnabled)) ?? true
        googlePayEnabled = (try? c.decode(Bool.self, forKey: .googlePayEnabled)) ?? true
        loobySocialAppStoreRedirectEnabled = (try? c.decode(Bool.self, forKey: .loobySocialAppStoreRedirectEnabled)) ?? true
        loobySocialAppStoreUrl = (try? c.decode(String.self, forKey: .loobySocialAppStoreUrl)) ?? "https://apps.apple.com/fr/search?term=LoobySocial"
        mobileAppMaintenanceEnabled = (try? c.decode(Bool.self, forKey: .mobileAppMaintenanceEnabled)) ?? false
    }
}

public struct LivriaBootstrapResponse: Codable, Sendable {
    public var ok: Bool
    public var user: LivriaUserProfile
    public var home: LivriaHomeSection
    public var books: [LivriaBook]
    public var genres: [String]
    public var cart: [LivriaCartItem]
    public var orders: [LivriaOrder]
    public var trades: LivriaTradesBundle
    public var loobyPlus: LivriaLoobyPlusState
    public var relays: LivriaRelaysBundle
    public var games: LivriaGamesData
    public var supportTickets: [LivriaSupportTicket]
    public var paymentSettings: LivriaPaymentSettings?
}

public struct LivriaUserProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var email: String
    public var displayName: String
    public var role: String?
    public var isAdmin: Bool
    public var isGuest: Bool?
    public var livriaAccountId: String
    public var accountProvider: String
    public var isLivriaPlus: Bool
    public var isBuyGod: Bool?
    public var loyaltyPoints: Int
    public var cashbackBalance: Double
    public var audioCredits: Int
    public var xp: Int
    public var level: Int
    public var streak: Int
    public var yearlyGoal: Int
    public var bio: String
    public var motto: String
    public var favoriteGenres: String
    public var accentColor: String
    public var themeId: String
    public var themeOpacity: Int
    public var firstName: String
    public var lastName: String
    public var phone: String
    public var address: String
    public var postalCode: String
    public var city: String
    public var cid: String
    public var puid: String?
    public var avatarUrl: String

    public var isGuestAccount: Bool {
        isGuest == true || role == "Guest" || email.lowercased().hasSuffix("@guest.livria.store")
    }

    public var resolvedAvatarURL: URL? {
        LivriaURLResolver.resolve(avatarUrl)
    }

    public var authBadgeLabel: String {
        if isGuestAccount {
            return "Session Invité • Sans compte requis"
        }
        return "Membre Viple Live ID (\(email))"
    }
}

public struct LivriaHomeStats: Codable, Equatable, Sendable {
    public var read: Int
    public var reading: Int
    public var wantToRead: Int
    public var readThisYear: Int
    public var trades: Int
    public var orders: Int
    public var yearlyGoal: Int
    public var streak: Int
}

public struct LivriaHomeSection: Codable, Equatable, Sendable {
    public var stats: LivriaHomeStats
    public var recommended: [LivriaBook]
    public var newest: [LivriaBook]
    public var deals: [LivriaBook]
}

// MARK: - Livre Boutique (Neuf & Occasion + Métadonnées Enrichies)

public struct LivriaBook: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: Int
    public var title: String
    public var author: String
    public var isbn: String
    public var genre: String
    public var description: String
    public var coverUrl: String
    public var price: Double
    public var originalPrice: Double?
    public var stock: Int
    public var isActive: Bool
    public var hasPaperback: Bool?
    public var hasEpub: Bool
    public var hasAudio: Bool

    public var isPaperbackAvailable: Bool {
        if let hp = hasPaperback { return hp }
        return stock > 0 || (usedStock ?? 0) > 0 || (!hasEpub && !hasAudio)
    }

    public var availableFormats: [String] {
        var list: [String] = []
        if isPaperbackAvailable {
            list.append("Broché")
        }
        if hasEpub {
            list.append("Numérique")
        }
        if hasAudio {
            list.append("Audio")
        }
        if list.isEmpty {
            list.append("Broché")
        }
        return list
    }

    // État Neuf / Occasion (synchronisé avec Wingman & Livria)
    public var condition: String?
    public var usedStock: Int?
    public var usedPrice: Double?
    public var usedCondition: String?
    public var hasNewInStock: Bool?
    public var hasUsedInStock: Bool?

    // Métadonnées enrichies Boutique
    public var countryOfOrigin: String?
    public var moodTags: String?
    public var triggerWarnings: String?
    public var aiSummaryNoSpoil: String?
    public var ambientSoundtrack: String?
    public var warehouseLocation: String?

    public var resolvedCoverURL: URL? {
        LivriaURLResolver.resolve(coverUrl)
    }

    public var displayGenre: String {
        let trimmed = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 11 {
            return "Inconnu"
        }
        return trimmed
    }

    public var effectiveNewStock: Int {
        max(0, stock)
    }

    public var effectiveUsedStock: Int {
        max(0, usedStock ?? 0)
    }

    public var hasNewStock: Bool {
        if let h = hasNewInStock { return h }
        return effectiveNewStock > 0 || !isUsedOnly
    }

    public var hasUsedStock: Bool {
        if let h = hasUsedInStock { return h }
        return effectiveUsedStock > 0 || (condition?.lowercased().contains("occasion") == true)
    }

    public var effectiveUsedConditionLabel: String {
        if let uc = usedCondition, !uc.isEmpty {
            return uc.lowercased().hasPrefix("occasion") ? uc : "Occasion - \(uc)"
        }
        if let c = condition, c.lowercased().contains("occasion") {
            return c
        }
        return "Occasion - Très bon état"
    }

    public var usedConditionLabel: String {
        effectiveUsedConditionLabel
    }

    public var effectiveUsedPriceValue: Double {
        usedPrice ?? max(1.0, (price * 0.65 * 100).rounded() / 100)
    }

    public var effectiveUsedPrice: Double {
        effectiveUsedPriceValue
    }

    public var cartFormatForUsed: String {
        effectiveUsedConditionLabel
    }

    public var hasBothNewAndUsed: Bool {
        hasNewStock && hasUsedStock
    }

    public var isUsedOnly: Bool {
        effectiveNewStock <= 0 && (effectiveUsedStock > 0 || (condition?.lowercased().contains("occasion") == true))
    }

    public var primaryDisplayPrice: Double {
        isUsedOnly ? effectiveUsedPriceValue : price
    }

    public var primaryBadgeText: String {
        if hasBothNewAndUsed {
            return "Neuf & \(effectiveUsedConditionLabel)"
        }
        if isUsedOnly {
            return effectiveUsedConditionLabel
        }
        return "Neuf"
    }
}

public struct LivriaBookDetailResponse: Codable, Sendable {
    public var ok: Bool
    public var book: LivriaBook
    public var averageRating: Double?
    public var reviewsCount: Int?
    public var reviews: [LivriaBookReview]
    public var similar: [LivriaBook]
}

public struct LivriaBookReview: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var rating: Int
    public var comment: String
    public var userName: String
    public var userAvatar: String?
    public var createdAt: String
}

// MARK: - Recherche ISBN (Google Books Priorité 1 + OpenLibrary Fallback) & Recherche Membres

public struct LivriaIsbnMetadata: Codable, Equatable, Sendable {
    public var source: String
    public var title: String
    public var author: String
    public var coverUrl: String
    public var description: String
    public var genre: String
}

public struct LivriaIsbnLookupResponse: Codable, Sendable {
    public var ok: Bool
    public var error: String?
    public var isbn: String?
    public var inCatalog: Bool
    public var catalogBook: LivriaBook?
    public var metadata: LivriaIsbnMetadata?

    public var title: String? {
        metadata?.title ?? catalogBook?.title
    }

    public var author: String? {
        metadata?.author ?? catalogBook?.author
    }

    public var coverUrl: String? {
        metadata?.coverUrl ?? catalogBook?.coverUrl
    }

    enum CodingKeys: String, CodingKey {
        case ok, error, isbn, inCatalog, catalogBook, metadata
    }

    public init(
        ok: Bool = true,
        error: String? = nil,
        inCatalog: Bool = false,
        isbn: String? = nil,
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        coverUrl: String? = nil,
        catalogBook: LivriaBook? = nil,
        metadata: LivriaIsbnMetadata? = nil
    ) {
        self.ok = ok
        self.error = error
        self.isbn = isbn
        self.inCatalog = inCatalog
        self.catalogBook = catalogBook
        if let metadata {
            self.metadata = metadata
        } else if title != nil || author != nil || description != nil || coverUrl != nil {
            self.metadata = LivriaIsbnMetadata(
                source: "LivriaCatalog",
                title: title ?? catalogBook?.title ?? "",
                author: author ?? catalogBook?.author ?? "",
                coverUrl: coverUrl ?? catalogBook?.coverUrl ?? "",
                description: description ?? catalogBook?.description ?? "",
                genre: catalogBook?.genre ?? "Roman"
            )
        } else {
            self.metadata = nil
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        self.error = try? c.decode(String.self, forKey: .error)
        self.isbn = try? c.decode(String.self, forKey: .isbn)
        self.inCatalog = (try? c.decode(Bool.self, forKey: .inCatalog)) ?? false
        self.catalogBook = try? c.decode(LivriaBook.self, forKey: .catalogBook)
        self.metadata = try? c.decode(LivriaIsbnMetadata.self, forKey: .metadata)
    }
}

public typealias LivriaISBNLookupResponse = LivriaIsbnLookupResponse
public typealias LivriaMemberSummary = LivriaMemberSearchResult

public struct LivriaMemberSearchResult: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var displayName: String
    public var avatarUrl: String
    public var motto: String
    public var bioString: String?
    public var favoriteGenresString: String?
    public var level: Int
    public var xp: Int
    public var isLivriaPlus: Bool
    public var socialProfileUrl: String

    public var bio: String {
        bioString ?? motto
    }

    public var favoriteGenres: String {
        favoriteGenresString ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, avatarUrl, motto
        case bioString = "bio"
        case favoriteGenresString = "favoriteGenres"
        case level, xp, isLivriaPlus, socialProfileUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? "Lecteur"
        self.avatarUrl = (try? c.decode(String.self, forKey: .avatarUrl)) ?? ""
        self.motto = (try? c.decode(String.self, forKey: .motto)) ?? ""
        self.bioString = try? c.decode(String.self, forKey: .bioString)
        self.favoriteGenresString = try? c.decode(String.self, forKey: .favoriteGenresString)
        self.level = (try? c.decode(Int.self, forKey: .level)) ?? 1
        self.xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        self.isLivriaPlus = (try? c.decode(Bool.self, forKey: .isLivriaPlus)) ?? false
        self.socialProfileUrl = (try? c.decode(String.self, forKey: .socialProfileUrl)) ?? "https://livriasocial.viplenetwork.com"
    }
}

public struct LivriaMemberSearchResponse: Codable, Sendable {
    public var ok: Bool
    public var loobySocialAppStoreRedirectEnabled: Bool?
    public var loobySocialAppStoreUrl: String?
    public var members: [LivriaMemberSearchResult]
}

// MARK: - Panier, Commandes & Checkout (Apple Pay / Google Pay / PayPal + Post-Order 1-Click Account)

public struct LivriaCartItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var bookId: Int
    public var title: String
    public var author: String
    public var coverUrl: String
    public var format: String
    public var quantity: Int
    public var unitPrice: Double
    public var isUsedFormat: Bool?

    public var lineTotal: Double {
        unitPrice * Double(quantity)
    }

    public var isUsedBookItem: Bool {
        isUsedFormat == true || format.lowercased().hasPrefix("occasion")
    }

    public var isLoobyPlusSubscription: Bool {
        format == "Abonnement" || title.lowercased().contains("looby+")
    }

    public var resolvedCoverURL: URL? {
        LivriaURLResolver.resolve(coverUrl)
    }
}

public struct LivriaOrder: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var reference: String
    public var createdAt: String
    public var total: Double
    public var status: String
    public var carrier: String
    public var trackingNumber: String?
    public var accessCode: String?
    public var hasShipping: Bool
    public var hasLabel: Bool
    public var deliveryUrl: String
    public var labelUrl: String?
    public var shippingAddress: String
    public var isGiftWrapped: Bool
    public var isZeroWastePackaging: Bool
    public var isClickAndCollect: Bool
    public var items: [LivriaOrderItem]

    public var effectiveLabelUrl: String {
        if let labelUrl = labelUrl, !labelUrl.isEmpty {
            return labelUrl
        }
        return "https://livria.store/api/mobile/v1/orders/\(id)/label?auth=\(accessCode ?? "")"
    }
}

public struct LivriaOrderItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var bookId: Int
    public var title: String
    public var author: String
    public var coverUrl: String
    public var quantity: Int
    public var unitPrice: Double
    public var format: String

    public var resolvedCoverURL: URL? {
        LivriaURLResolver.resolve(coverUrl)
    }
}

public struct LivriaCheckoutResponse: Codable, Sendable {
    public var ok: Bool
    public var error: String?
    public var orderId: Int?
    public var reference: String?
    public var trackingNumber: String?
    public var deliveryUrl: String?
    public var labelUrl: String?
    public var activatedLoobyPlus: Bool?
    public var isGuestOrder: Bool?
    public var canCreateAccount: Bool?
    public var guestUserId: Int?
    public var checkoutEmail: String?
    public var checkoutFirstName: String?
    public var checkoutLastName: String?
    public var prefilledEmail: String?
    public var prefilledName: String?
    public var order: LivriaOrder?
    public var user: LivriaUserProfile?
    public var message: String?
}

public struct LivriaPayPalCreateResponse: Codable, Sendable {
    public var ok: Bool
    public var orderId: String?
    public var approveUrl: String?
    public var walletSource: String?
    public var error: String?

    public var payPalOrderId: String? {
        orderId
    }
}

public struct LivriaFinalizeAccountResponse: Codable, Sendable {
    public var ok: Bool
    public var mode: String?
    public var message: String?
    public var error: String?
    public var token: String?
    public var user: LivriaUserProfile?

    public init(
        ok: Bool,
        mode: String? = nil,
        message: String? = nil,
        error: String? = nil,
        token: String? = nil,
        user: LivriaUserProfile? = nil
    ) {
        self.ok = ok
        self.mode = mode
        self.message = message
        self.error = error
        self.token = token
        self.user = user
    }
}

// MARK: - Troc de Livres

public struct LivriaTradesBundle: Codable, Equatable, Sendable {
    public var openOffers: [LivriaTradeOffer]
    public var myOffers: [LivriaMyTradeOffer]
    public var myRequests: [LivriaTradeRequestItem]
}

public struct LivriaTradeOffer: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var ownerId: Int
    public var ownerName: String
    public var ownerAvatar: String
    public var title: String
    public var author: String
    public var condition: String
    public var wants: String
    public var description: String
    public var coverUrl: String
    public var status: String
    public var createdAt: String
}

public struct LivriaMyTradeOffer: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var title: String
    public var author: String
    public var condition: String
    public var wants: String
    public var description: String
    public var coverUrl: String
    public var status: String
    public var createdAt: String
    public var requests: [LivriaIncomingTradeRequest]
}

public struct LivriaIncomingTradeRequest: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var requesterId: Int
    public var requesterName: String
    public var proposedBook: String
    public var message: String
    public var status: String
    public var createdAt: String
}

public struct LivriaTradeRequestItem: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var offerId: Int
    public var offerTitle: String
    public var offerAuthor: String
    public var ownerName: String
    public var proposedBook: String
    public var message: String
    public var status: String
    public var createdAt: String
}

// MARK: - Looby+ (Dashboard & Souscription 3,50 €/mois)

public struct LivriaLoobyPlusState: Codable, Equatable, Sendable {
    public var isSubscribed: Bool
    public var monthlyPrice: Double
    public var cashbackBalance: Double
    public var audioCredits: Int
    public var boxPreferences: LivriaBoxPreferences
    public var familyMembers: [LivriaFamilyMember]
}

public struct LivriaBoxPreferences: Codable, Equatable, Sendable {
    public var preferredGenres: String
    public var dislikedTropes: String
    public var specialNotes: String
    public var shippingAddress: String
}

public struct LivriaFamilyMember: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var avatar: String
    public var isKidsMode: Bool
    public var birthYear: Int?
}

// MARK: - Points Relais Communautaires & UPS Access Point™

public struct LivriaRelaysBundle: Codable, Equatable, Sendable {
    public var externalPickupUrl: String
    public var communityPoints: [LivriaCommunityRelay]
    public var upsPoints: [LivriaUpsPickupPoint]
}

public struct LivriaCommunityRelay: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var type: String
    public var address: String
    public var city: String
    public var postalCode: String
    public var latitude: Double
    public var longitude: Double
    public var description: String
    public var openingHours: String
}

public struct LivriaUpsPickupPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var postalCode: String
    public var city: String
    public var hours: String
    public var distance: String
    public var carrier: String
    public var latitude: Double
    public var longitude: Double
}

public struct LivriaUpsSearchResponse: Codable, Sendable {
    public var ok: Bool
    public var externalPickupUrl: String
    public var resolvedPostalCode: String?
    public var resolvedCity: String?
    public var centerLatitude: Double?
    public var centerLongitude: Double?
    public var searchCenterLat: Double?
    public var searchCenterLon: Double?
    public var points: [LivriaUpsPickupPoint]

    public var effectiveCenterLat: Double? {
        searchCenterLat ?? centerLatitude
    }

    public var effectiveCenterLon: Double? {
        searchCenterLon ?? centerLongitude
    }
}

// MARK: - Jeux Littéraires XP (Conformes Sendable pour Swift 6 Strict Concurrency)

public struct LivriaGamesData: Codable, Equatable, Sendable {
    public var canSpinWheel: Bool
    public var canClaimDaily: Bool
    public var streak: Int
    public var xp: Int
    public var loyaltyPoints: Int
}

public struct LivriaQuizQuestionItem: Identifiable, Sendable {
    public let id: UUID
    public let question: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public let xpReward: Int

    public init(id: UUID = UUID(), question: String, options: [String], correctIndex: Int, explanation: String, xpReward: Int) {
        self.id = id
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.xpReward = xpReward
    }

    public static let sampleQuestions: [LivriaQuizQuestionItem] = [
        .init(question: "Qui a écrit « Les Misérables » et « Notre-Dame de Paris » ?", options: ["Émile Zola", "Victor Hugo", "Honoré de Balzac", "Gustave Flaubert"], correctIndex: 1, explanation: "Victor Hugo a publié Notre-Dame de Paris en 1831 et Les Misérables en 1862.", xpReward: 25),
        .init(question: "Dans « Le Petit Prince » d'Antoine de Saint-Exupéry, quelle fleur le Petit Prince protège-t-il sur l'astéroïde B 612 ?", options: ["Une tulipe", "Une rose", "Une orchidée", "Un lys"], correctIndex: 1, explanation: "Sa rose unique au monde symbolise l'amour et la responsabilité (« Tu deviens toujours responsable de ce que tu as apprivoisé »).", xpReward: 25),
        .init(question: "Quel auteur français a imaginé le cycle des « Rougon-Macquart » dont fait partie Germinal ?", options: ["Guy de Maupassant", "Stendhal", "Émile Zola", "Jules Verne"], correctIndex: 2, explanation: "Émile Zola a consacré vingt romans à l'histoire naturelle et sociale d'une famille sous le Second Empire.", xpReward: 30),
        .init(question: "Quel détective gentleman cambrioleur a été créé par Maurice Leblanc ?", options: ["Hercule Poirot", "Arsène Lupin", "Jules Maigret", "Rouletabille"], correctIndex: 1, explanation: "Arsène Lupin apparaît pour la première fois en 1905 sous la plume de Maurice Leblanc.", xpReward: 25),
        .init(question: "Quel roman de Frank Herbert se déroule sur la planète désertique Arrakis ?", options: ["Fondation", "Hypérion", "Dune", "Neuromancien"], correctIndex: 2, explanation: "Dune (1965) raconte la lutte pour le contrôle d'Arrakis et de l'Épice de longue vie.", xpReward: 30)
    ]
}

public struct LivriaWordScrambleItem: Identifiable, Sendable {
    public let id: UUID
    public let scrambled: String
    public let answer: String
    public let hint: String
    public let xpReward: Int

    public init(id: UUID = UUID(), scrambled: String, answer: String, hint: String, xpReward: Int) {
        self.id = id
        self.scrambled = scrambled
        self.answer = answer
        self.hint = hint
        self.xpReward = xpReward
    }

    public static let all: [LivriaWordScrambleItem] = [
        .init(scrambled: "M A N O R", answer: "ROMAN", hint: "Genre littéraire narratif majeur en prose", xpReward: 20),
        .init(scrambled: "E P O I S E", answer: "POESIE", hint: "Art du langage rythmé et des vers", xpReward: 20),
        .init(scrambled: "A H P C I R T E", answer: "CHAPITRE", hint: "Division principale d'un livre", xpReward: 25),
        .init(scrambled: "L I B L I O P H I E L", answer: "BIBLIOPHILE", hint: "Amoureux passionné des beaux livres", xpReward: 35)
    ]
}

// MARK: - Assistance Synchronisée avec VipleAPI (assistance.viplenetwork.com)

public struct LivriaSupportTicket: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var reference: String
    public var service: String
    public var category: String
    public var priority: String
    public var status: String
    public var title: String
    public var requesterName: String
    public var requesterEmail: String
    public var createdAt: String
    public var updatedAt: String
    public var messageCount: Int
    public var lastMessage: String?
    public var messages: [LivriaSupportMessage]?
}

public struct LivriaSupportMessage: Codable, Identifiable, Equatable, Sendable {
    public var id: Int
    public var isStaff: Bool
    public var authorName: String
    public var body: String
    public var sentAt: String
}

public struct LivriaSupportTicketDetailResponse: Codable, Sendable {
    public var ok: Bool
    public var ticket: LivriaSupportTicket
}
