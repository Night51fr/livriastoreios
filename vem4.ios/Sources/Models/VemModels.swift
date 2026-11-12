import Foundation

// MARK: - Complete Typed Models for Viple & Moi (Espace Client v4 + Livria Delivery + 2D-DOC + Academy Guide)

public struct VemBootstrapResponse: Codable, Sendable {
    public var workspace: VemWorkspace
    public var account: VemAccountProfile?
}

public struct VemMobileLoginResponse: Codable, Sendable {
    public var ok: Bool
    public var error: String?
    public var token: String?
    public var viewer: VemAuthViewer?
    public var workspace: VemWorkspace?
    public var account: VemAccountProfile?
}

public struct VemGenericActionResponse: Codable, Sendable {
    public var ok: Bool?
    public var message: String?
    public var error: String?
    public var lockedByFamilyOwner: Bool?
    public var userTileUrl: String?
    public var orderId: String?
    public var approveUrl: String?
    public var amountEur: Double?
    public var vipleMail: VemMailStatus?
}

public struct VemAuthViewer: Codable, Sendable, Equatable {
    public var authenticated: Bool
    public var email: String
    public var displayName: String
    public var cid: String
    public var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case authenticated, email, displayName, cid, avatarUrl
    }

    public init(authenticated: Bool = true, email: String, displayName: String, cid: String = "", avatarUrl: String? = nil) {
        self.authenticated = authenticated
        self.email = email
        self.displayName = displayName
        self.cid = cid
        self.avatarUrl = avatarUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = (try? c.decode(Bool.self, forKey: .authenticated)) ?? true
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.cid = (try? c.decode(String.self, forKey: .cid)) ?? ""
        self.avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
    }
}

// MARK: - Workspace Root

public struct VemWorkspace: Codable, Sendable {
    public var ok: Bool
    public var viewer: VemWorkspaceViewer
    public var rights: VemAccountRights
    public var vipleMail: VemMailStatus
    public var summary: VemWorkspaceSummary
    public var familyMembers: [VemFamilyMember]
    public var subscriptions: [VemSubscription]
    public var optionRequests: [VemOptionRequest]
    public var boutique: VemBoutiqueCatalog
    public var billing: VemBillingBundle

    enum CodingKeys: String, CodingKey {
        case ok, viewer, rights, vipleMail, summary, familyMembers, subscriptions, optionRequests, boutique, billing
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? true
        self.viewer = (try? c.decode(VemWorkspaceViewer.self, forKey: .viewer)) ?? VemWorkspaceViewer()
        self.rights = (try? c.decode(VemAccountRights.self, forKey: .rights)) ?? VemAccountRights()
        self.vipleMail = (try? c.decode(VemMailStatus.self, forKey: .vipleMail)) ?? VemMailStatus()
        self.summary = (try? c.decode(VemWorkspaceSummary.self, forKey: .summary)) ?? VemWorkspaceSummary()
        self.familyMembers = (try? c.decode([VemFamilyMember].self, forKey: .familyMembers)) ?? []
        self.subscriptions = (try? c.decode([VemSubscription].self, forKey: .subscriptions)) ?? []
        self.optionRequests = (try? c.decode([VemOptionRequest].self, forKey: .optionRequests)) ?? []
        self.boutique = (try? c.decode(VemBoutiqueCatalog.self, forKey: .boutique)) ?? VemBoutiqueCatalog()
        self.billing = (try? c.decode(VemBillingBundle.self, forKey: .billing)) ?? VemBillingBundle()
    }
}

public struct VemWorkspaceViewer: Codable, Sendable {
    public var email: String = ""
    public var displayName: String = ""
    public var cid: String = ""
    public var vipleMail: String = ""

    public var firstName: String {
        let parts = displayName.split(separator: " ")
        if let first = parts.first, !first.isEmpty {
            return String(first)
        }
        return email.split(separator: "@").first.map(String.init) ?? "Client"
    }

    public init(email: String = "", displayName: String = "", cid: String = "", vipleMail: String = "") {
        self.email = email
        self.displayName = displayName
        self.cid = cid
        self.vipleMail = vipleMail
    }

    enum CodingKeys: String, CodingKey { case email, displayName, cid, vipleMail }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.cid = (try? c.decode(String.self, forKey: .cid)) ?? ""
        self.vipleMail = (try? c.decode(String.self, forKey: .vipleMail)) ?? ""
    }
}

public struct VemAccountRights: Codable, Sendable {
    public var canOrderNewServices: Bool = true
    public var canOrderOptions: Bool = true
    public var canManageFamily: Bool = true
    public var canEditBilling: Bool = true
    public var canChangeMailAlias: Bool = true
    public var vipPriority: Bool = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case canOrderNewServices, canOrderOptions, canManageFamily, canEditBilling, canChangeMailAlias, vipPriority
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.canOrderNewServices = (try? c.decode(Bool.self, forKey: .canOrderNewServices)) ?? true
        self.canOrderOptions = (try? c.decode(Bool.self, forKey: .canOrderOptions)) ?? true
        self.canManageFamily = (try? c.decode(Bool.self, forKey: .canManageFamily)) ?? true
        self.canEditBilling = (try? c.decode(Bool.self, forKey: .canEditBilling)) ?? true
        self.canChangeMailAlias = (try? c.decode(Bool.self, forKey: .canChangeMailAlias)) ?? true
        self.vipPriority = (try? c.decode(Bool.self, forKey: .vipPriority)) ?? false
    }
}

public struct VemMailStatus: Codable, Sendable {
    public var primaryAddress: String = ""
    public var aliases: [String] = []
    public var usedBytes: Int64 = 0
    public var quotaBytes: Int64 = 5_368_709_120
    public var usedGb: Double = 0
    public var quotaGb: Double = 5.0
    public var percentUsed: Int = 1
    public var imapServer: String = "imap.viplemail.fr:993 (SSL/TLS)"
    public var smtpServer: String = "smtp.viplemail.fr:587 (STARTTLS)"
    public var webmailUrl: String = "https://mail.viplemail.fr/sso-login"

    public init() {}

    enum CodingKeys: String, CodingKey {
        case primaryAddress, aliases, usedBytes, quotaBytes, usedGb, quotaGb, percentUsed, imapServer, smtpServer, webmailUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryAddress = (try? c.decode(String.self, forKey: .primaryAddress)) ?? ""
        self.aliases = (try? c.decode([String].self, forKey: .aliases)) ?? []
        self.usedBytes = (try? c.decode(Int64.self, forKey: .usedBytes)) ?? 0
        self.quotaBytes = (try? c.decode(Int64.self, forKey: .quotaBytes)) ?? 5_368_709_120
        self.usedGb = (try? c.decode(Double.self, forKey: .usedGb)) ?? 0
        self.quotaGb = (try? c.decode(Double.self, forKey: .quotaGb)) ?? 5.0
        self.percentUsed = (try? c.decode(Int.self, forKey: .percentUsed)) ?? 1
        self.imapServer = (try? c.decode(String.self, forKey: .imapServer)) ?? "imap.viplemail.fr:993 (SSL/TLS)"
        self.smtpServer = (try? c.decode(String.self, forKey: .smtpServer)) ?? "smtp.viplemail.fr:587 (STARTTLS)"
        self.webmailUrl = (try? c.decode(String.self, forKey: .webmailUrl)) ?? "https://mail.viplemail.fr/sso-login"
    }
}

public struct VemWorkspaceSummary: Codable, Sendable {
    public var monthlyTotalTtc: Double = 0
    public var activeServicesCount: Int = 0
    public var familyMembersCount: Int = 1
    public var pendingOptionRequestsCount: Int = 0

    public init() {}

    enum CodingKeys: String, CodingKey {
        case monthlyTotalTtc, activeServicesCount, familyMembersCount, pendingOptionRequestsCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.monthlyTotalTtc = (try? c.decode(Double.self, forKey: .monthlyTotalTtc)) ?? 0
        self.activeServicesCount = (try? c.decode(Int.self, forKey: .activeServicesCount)) ?? 0
        self.familyMembersCount = (try? c.decode(Int.self, forKey: .familyMembersCount)) ?? 1
        self.pendingOptionRequestsCount = (try? c.decode(Int.self, forKey: .pendingOptionRequestsCount)) ?? 0
    }
}

// MARK: - Family Members & Household Delegation

public struct VemFamilyMember: Codable, Identifiable, Sendable, Equatable {
    public var id: Int
    public var firstName: String
    public var relationship: String
    public var linkedVipleEmail: String?
    public var avatarColor: String
    public var canAccessServices: Bool
    public var canPurchaseOptions: Bool
    public var canCancelServices: Bool
    public var isPrimaryOwner: Bool

    enum CodingKeys: String, CodingKey {
        case id, firstName, relationship, linkedVipleEmail, avatarColor
        case canAccessServices, canPurchaseOptions, canCancelServices, isPrimaryOwner
    }

    public init(
        id: Int = 0,
        firstName: String = "",
        relationship: String = "Fils",
        linkedVipleEmail: String? = nil,
        avatarColor: String = "#4F46E5",
        canAccessServices: Bool = true,
        canPurchaseOptions: Bool = false,
        canCancelServices: Bool = false,
        isPrimaryOwner: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.relationship = relationship
        self.linkedVipleEmail = linkedVipleEmail
        self.avatarColor = avatarColor
        self.canAccessServices = canAccessServices
        self.canPurchaseOptions = canPurchaseOptions
        self.canCancelServices = canCancelServices
        self.isPrimaryOwner = isPrimaryOwner
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.firstName = (try? c.decode(String.self, forKey: .firstName)) ?? "Membre"
        self.relationship = (try? c.decode(String.self, forKey: .relationship)) ?? "Famille"
        self.linkedVipleEmail = try? c.decode(String.self, forKey: .linkedVipleEmail)
        self.avatarColor = (try? c.decode(String.self, forKey: .avatarColor)) ?? "#4F46E5"
        self.canAccessServices = (try? c.decode(Bool.self, forKey: .canAccessServices)) ?? true
        self.canPurchaseOptions = (try? c.decode(Bool.self, forKey: .canPurchaseOptions)) ?? false
        self.canCancelServices = (try? c.decode(Bool.self, forKey: .canCancelServices)) ?? false
        self.isPrimaryOwner = (try? c.decode(Bool.self, forKey: .isPrimaryOwner)) ?? false
    }
}

// MARK: - Subscriptions (Strict Server vs Non-Server Classification)

public struct VemSubscription: Codable, Identifiable, Sendable {
    public var id: Int
    public var serviceRef: String
    public var ownerEmail: String
    public var isOwner: Bool
    public var isDelegatedToMe: Bool
    public var assignedMemberId: Int?
    public var assignedMemberName: String
    public var delegatedVipleEmail: String?
    public var productCode: String
    public var category: String
    public var serviceKind: String
    public var isServerService: Bool
    public var canStartStop: Bool
    public var canReboot: Bool
    public var runtimeStatusLabel: String
    public var runtimeStatusDetail: String
    public var runtimeStatusTone: String
    public var title: String
    public var subtitle: String
    public var customNickname: String?
    public var technicalIdentifier: String
    public var basePriceMonthlyTtc: Double
    public var totalMonthlyTtc: Double
    public var commitmentLabel: String
    public var status: String
    public var isLockedMandatory: Bool
    public var powerState: String
    public var metric1Label: String
    public var metric1Used: Double
    public var metric1Max: Double
    public var metric1Unit: String
    public var metric2Label: String
    public var metric2Value: String
    public var createdAt: String?
    public var nextBillingAt: String?
    public var isCommercialized: Bool
    public var retiredReason: String?
    public var replacementProductCode: String?
    public var accentTheme: String
    public var iconName: String
    public var permissions: VemServicePermissions
    public var options: [VemActiveOption]

    public var displayTitle: String {
        if let nick = customNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return nick
        }
        return title
    }

    public var displaySubtitle: String {
        if let nick = customNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return title
        }
        return subtitle
    }

    public var isMandatoryMail: Bool {
        isLockedMandatory || productCode.lowercased() == "viple-mail-inclus" || serviceKind == "mail"
    }

    public var isServerStopped: Bool {
        isServerService && powerState.lowercased() == "stopped"
    }

    enum CodingKeys: String, CodingKey {
        case id, serviceRef, ownerEmail, isOwner, isDelegatedToMe, assignedMemberId, assignedMemberName, delegatedVipleEmail
        case productCode, category, serviceKind, isServerService, canStartStop, canReboot
        case runtimeStatusLabel, runtimeStatusDetail, runtimeStatusTone
        case title, subtitle, customNickname, technicalIdentifier
        case basePriceMonthlyTtc, totalMonthlyTtc, commitmentLabel, status, isLockedMandatory, powerState
        case metric1Label, metric1Used, metric1Max, metric1Unit, metric2Label, metric2Value
        case createdAt, nextBillingAt, isCommercialized, retiredReason, replacementProductCode
        case accentTheme, iconName, permissions, options
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.serviceRef = (try? c.decode(String.self, forKey: .serviceRef)) ?? ""
        self.ownerEmail = (try? c.decode(String.self, forKey: .ownerEmail)) ?? ""
        self.isOwner = (try? c.decode(Bool.self, forKey: .isOwner)) ?? true
        self.isDelegatedToMe = (try? c.decode(Bool.self, forKey: .isDelegatedToMe)) ?? false
        self.assignedMemberId = try? c.decode(Int.self, forKey: .assignedMemberId)
        self.assignedMemberName = (try? c.decode(String.self, forKey: .assignedMemberName)) ?? "Titulaire"
        self.delegatedVipleEmail = try? c.decode(String.self, forKey: .delegatedVipleEmail)
        let pCode = (try? c.decode(String.self, forKey: .productCode)) ?? ""
        let cat = (try? c.decode(String.self, forKey: .category)) ?? ""
        let locked = (try? c.decode(Bool.self, forKey: .isLockedMandatory)) ?? false
        let rawPower = (try? c.decode(String.self, forKey: .powerState)) ?? "active"

        self.productCode = pCode
        self.category = cat
        self.isLockedMandatory = locked

        // Fallback local classification guaranteeing non-servers NEVER display server labels even from cached payloads
        let catLower = cat.lowercased()
        let codeLower = pCode.lowercased()
        let fallbackServer = ["cloud-vps", "vps", "serveur-dedie", "dedie", "cloud-server", "gaming-server"].contains(catLower)
            || codeLower.hasPrefix("vps-")
            || codeLower.hasPrefix("it-serveur-")

        let resolvedIsServer = (try? c.decode(Bool.self, forKey: .isServerService)) ?? fallbackServer
        self.isServerService = resolvedIsServer
        self.powerState = resolvedIsServer ? rawPower : "active"

        let fallbackKind: String = {
            if resolvedIsServer { return "server" }
            if locked || catLower == "messagerie-incluse" || codeLower == "viple-mail-inclus" { return "mail" }
            if catLower == "box-5g" || catLower == "decodeur-tv" { return "equipment" }
            if catLower == "forfait-mobile" || catLower == "telephonie-sip" { return "telecom" }
            if catLower == "hebergement-web" || catLower == "domaine" { return "web" }
            if catLower == "ecosysteme-looby" || codeLower.contains("looby") { return "pass" }
            return "subscription"
        }()

        let kind = (try? c.decode(String.self, forKey: .serviceKind)) ?? fallbackKind
        self.serviceKind = kind
        self.canStartStop = (try? c.decode(Bool.self, forKey: .canStartStop)) ?? resolvedIsServer
        self.canReboot = (try? c.decode(Bool.self, forKey: .canReboot)) ?? (kind == "server" || kind == "equipment")

        let fallbackLabel: String = {
            if resolvedIsServer {
                return rawPower.lowercased() == "stopped" ? "Serveur arrêté" : "Serveur démarré"
            }
            switch kind {
            case "mail": return "Inclus · Gratuit"
            case "equipment": return catLower == "decodeur-tv" ? "Décodeur actif" : "Connexion active"
            case "telecom": return catLower == "forfait-mobile" ? "Ligne 5G active" : "Ligne fixe active"
            case "web": return "Hébergement actif"
            case "pass": return "Avantages actifs"
            default: return "Service actif"
            }
        }()

        self.runtimeStatusLabel = (try? c.decode(String.self, forKey: .runtimeStatusLabel)) ?? fallbackLabel
        self.runtimeStatusDetail = (try? c.decode(String.self, forKey: .runtimeStatusDetail)) ?? "Abonnement actif sans interruption."
        self.runtimeStatusTone = (try? c.decode(String.self, forKey: .runtimeStatusTone))
            ?? ((resolvedIsServer && rawPower.lowercased() == "stopped") ? "amber" : "emerald")

        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.customNickname = try? c.decode(String.self, forKey: .customNickname)
        self.technicalIdentifier = (try? c.decode(String.self, forKey: .technicalIdentifier)) ?? ""
        self.basePriceMonthlyTtc = (try? c.decode(Double.self, forKey: .basePriceMonthlyTtc)) ?? 0
        self.totalMonthlyTtc = (try? c.decode(Double.self, forKey: .totalMonthlyTtc)) ?? 0
        self.commitmentLabel = (try? c.decode(String.self, forKey: .commitmentLabel)) ?? "Sans engagement"
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "Actif"
        self.metric1Label = (try? c.decode(String.self, forKey: .metric1Label)) ?? "Usage"
        self.metric1Used = (try? c.decode(Double.self, forKey: .metric1Used)) ?? 0
        self.metric1Max = (try? c.decode(Double.self, forKey: .metric1Max)) ?? 100
        self.metric1Unit = (try? c.decode(String.self, forKey: .metric1Unit)) ?? "Go"
        self.metric2Label = (try? c.decode(String.self, forKey: .metric2Label)) ?? ""
        self.metric2Value = (try? c.decode(String.self, forKey: .metric2Value)) ?? ""
        self.createdAt = try? c.decode(String.self, forKey: .createdAt)
        self.nextBillingAt = try? c.decode(String.self, forKey: .nextBillingAt)
        self.isCommercialized = (try? c.decode(Bool.self, forKey: .isCommercialized)) ?? true
        self.retiredReason = try? c.decode(String.self, forKey: .retiredReason)
        self.replacementProductCode = try? c.decode(String.self, forKey: .replacementProductCode)
        self.accentTheme = (try? c.decode(String.self, forKey: .accentTheme)) ?? "indigo"
        self.iconName = (try? c.decode(String.self, forKey: .iconName)) ?? "server"
        self.permissions = (try? c.decode(VemServicePermissions.self, forKey: .permissions)) ?? VemServicePermissions()
        self.options = (try? c.decode([VemActiveOption].self, forKey: .options)) ?? []
    }
}

public struct VemServicePermissions: Codable, Sendable {
    public var canPilotTechnical: Bool = false
    public var canPurchaseOptions: Bool = true
    public var canCancelService: Bool = true

    public init() {}

    enum CodingKeys: String, CodingKey { case canPilotTechnical, canPurchaseOptions, canCancelService }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.canPilotTechnical = (try? c.decode(Bool.self, forKey: .canPilotTechnical)) ?? false
        self.canPurchaseOptions = (try? c.decode(Bool.self, forKey: .canPurchaseOptions)) ?? true
        self.canCancelService = (try? c.decode(Bool.self, forKey: .canCancelService)) ?? true
    }
}

public struct VemActiveOption: Codable, Identifiable, Sendable {
    public var id: Int
    public var optionCode: String
    public var title: String
    public var priceMonthlyTtc: Double
    public var addedByEmail: String
    public var createdAt: String?
    public var isCommercialized: Bool
    public var retiredReason: String?

    enum CodingKeys: String, CodingKey {
        case id, optionCode, title, priceMonthlyTtc, addedByEmail, createdAt, isCommercialized, retiredReason
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.optionCode = (try? c.decode(String.self, forKey: .optionCode)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.priceMonthlyTtc = (try? c.decode(Double.self, forKey: .priceMonthlyTtc)) ?? 0
        self.addedByEmail = (try? c.decode(String.self, forKey: .addedByEmail)) ?? ""
        self.createdAt = try? c.decode(String.self, forKey: .createdAt)
        self.isCommercialized = (try? c.decode(Bool.self, forKey: .isCommercialized)) ?? true
        self.retiredReason = try? c.decode(String.self, forKey: .retiredReason)
    }
}

public struct VemOptionRequest: Codable, Identifiable, Sendable {
    public var id: Int
    public var subscriptionId: Int
    public var serviceTitle: String
    public var serviceNickname: String
    public var ownerEmail: String
    public var requesterEmail: String
    public var requesterName: String
    public var optionCode: String
    public var optionTitle: String
    public var priceMonthlyTtc: Double
    public var message: String
    public var status: String
    public var createdAt: String?
    public var canResolve: Bool

    enum CodingKeys: String, CodingKey {
        case id, subscriptionId, serviceTitle, serviceNickname, ownerEmail, requesterEmail, requesterName
        case optionCode, optionTitle, priceMonthlyTtc, message, status, createdAt, canResolve
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.subscriptionId = (try? c.decode(Int.self, forKey: .subscriptionId)) ?? 0
        self.serviceTitle = (try? c.decode(String.self, forKey: .serviceTitle)) ?? ""
        self.serviceNickname = (try? c.decode(String.self, forKey: .serviceNickname)) ?? ""
        self.ownerEmail = (try? c.decode(String.self, forKey: .ownerEmail)) ?? ""
        self.requesterEmail = (try? c.decode(String.self, forKey: .requesterEmail)) ?? ""
        self.requesterName = (try? c.decode(String.self, forKey: .requesterName)) ?? ""
        self.optionCode = (try? c.decode(String.self, forKey: .optionCode)) ?? ""
        self.optionTitle = (try? c.decode(String.self, forKey: .optionTitle)) ?? ""
        self.priceMonthlyTtc = (try? c.decode(Double.self, forKey: .priceMonthlyTtc)) ?? 0
        self.message = (try? c.decode(String.self, forKey: .message)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "pending"
        self.createdAt = try? c.decode(String.self, forKey: .createdAt)
        self.canResolve = (try? c.decode(Bool.self, forKey: .canResolve)) ?? false
    }
}

// MARK: - Boutique Official Catalog

public struct VemBoutiqueCatalog: Codable, Sendable {
    public var products: [VemBoutiqueProduct] = []
    public var options: [VemBoutiqueOption] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case products, options }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.products = (try? c.decode([VemBoutiqueProduct].self, forKey: .products)) ?? []
        self.options = (try? c.decode([VemBoutiqueOption].self, forKey: .options)) ?? []
    }
}

public struct VemBoutiqueProduct: Codable, Identifiable, Sendable {
    public var id: String { productCode }
    public var productCode: String
    public var category: String
    public var title: String
    public var subtitle: String
    public var description: String
    public var badgeText: String
    public var accentTheme: String
    public var iconName: String
    public var priceMonthlyTtc: Double
    public var setupFeeTtc: Double
    public var commitmentLabel: String
    public var specPrimaryLabel: String
    public var specPrimaryMax: Double
    public var specPrimaryUnit: String
    public var specSecondaryLabel: String
    public var specSecondaryDefault: String

    enum CodingKeys: String, CodingKey {
        case productCode, category, title, subtitle, description, badgeText, accentTheme, iconName
        case priceMonthlyTtc, setupFeeTtc, commitmentLabel, specPrimaryLabel, specPrimaryMax, specPrimaryUnit
        case specSecondaryLabel, specSecondaryDefault
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.productCode = (try? c.decode(String.self, forKey: .productCode)) ?? UUID().uuidString
        self.category = (try? c.decode(String.self, forKey: .category)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.badgeText = (try? c.decode(String.self, forKey: .badgeText)) ?? ""
        self.accentTheme = (try? c.decode(String.self, forKey: .accentTheme)) ?? "indigo"
        self.iconName = (try? c.decode(String.self, forKey: .iconName)) ?? "server"
        self.priceMonthlyTtc = (try? c.decode(Double.self, forKey: .priceMonthlyTtc)) ?? 0
        self.setupFeeTtc = (try? c.decode(Double.self, forKey: .setupFeeTtc)) ?? 0
        self.commitmentLabel = (try? c.decode(String.self, forKey: .commitmentLabel)) ?? "Sans engagement"
        self.specPrimaryLabel = (try? c.decode(String.self, forKey: .specPrimaryLabel)) ?? ""
        self.specPrimaryMax = (try? c.decode(Double.self, forKey: .specPrimaryMax)) ?? 0
        self.specPrimaryUnit = (try? c.decode(String.self, forKey: .specPrimaryUnit)) ?? ""
        self.specSecondaryLabel = (try? c.decode(String.self, forKey: .specSecondaryLabel)) ?? ""
        self.specSecondaryDefault = (try? c.decode(String.self, forKey: .specSecondaryDefault)) ?? ""
    }
}

public struct VemBoutiqueOption: Codable, Identifiable, Sendable {
    public var id: String { optionCode }
    public var optionCode: String
    public var compatibleCategories: String
    public var title: String
    public var description: String
    public var priceMonthlyTtc: Double
    public var iconName: String

    public func isCompatible(with category: String) -> Bool {
        if compatibleCategories == "*" { return true }
        let cats = compatibleCategories
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return cats.contains(category.lowercased())
    }

    enum CodingKeys: String, CodingKey {
        case optionCode, compatibleCategories, title, description, priceMonthlyTtc, iconName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.optionCode = (try? c.decode(String.self, forKey: .optionCode)) ?? UUID().uuidString
        self.compatibleCategories = (try? c.decode(String.self, forKey: .compatibleCategories)) ?? "*"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.priceMonthlyTtc = (try? c.decode(Double.self, forKey: .priceMonthlyTtc)) ?? 0
        self.iconName = (try? c.decode(String.self, forKey: .iconName)) ?? "sparkles"
    }
}

// MARK: - Billing, SEPA (5/10/15), PayPal & Certified 2D-DOC Invoices

public struct VemBillingBundle: Codable, Sendable {
    public var profile: VemBillingProfile?
    public var invoices: [VemInvoice] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case profile, invoices }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try? c.decode(VemBillingProfile.self, forKey: .profile)
        self.invoices = (try? c.decode([VemInvoice].self, forKey: .invoices)) ?? []
    }
}

public struct VemBillingProfile: Codable, Sendable {
    public var preferredMethod: String = "SEPA"
    public var sepaAccountHolder: String = ""
    public var sepaIbanMasked: String = ""
    public var sepaBic: String = ""
    public var sepaDebitDay: Int = 10
    public var sepaMandateRum: String = ""
    public var sepaSignedAt: String?
    public var sepaActive: Bool = false
    public var payPalEmail: String?
    public var payPalPayerId: String?
    public var payPalLinkedAt: String?
    public var payPalActive: Bool = false
    public var billingAddress: String = ""
    public var billingPostalCode: String = ""
    public var billingCity: String = ""

    enum CodingKeys: String, CodingKey {
        case preferredMethod, sepaAccountHolder, sepaIbanMasked, sepaBic, sepaDebitDay
        case sepaMandateRum, sepaSignedAt, sepaActive, payPalEmail, payPalPayerId, payPalLinkedAt, payPalActive
        case billingAddress, billingPostalCode, billingCity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.preferredMethod = (try? c.decode(String.self, forKey: .preferredMethod)) ?? "SEPA"
        self.sepaAccountHolder = (try? c.decode(String.self, forKey: .sepaAccountHolder)) ?? ""
        self.sepaIbanMasked = (try? c.decode(String.self, forKey: .sepaIbanMasked)) ?? ""
        self.sepaBic = (try? c.decode(String.self, forKey: .sepaBic)) ?? ""
        let day = (try? c.decode(Int.self, forKey: .sepaDebitDay)) ?? 10
        self.sepaDebitDay = [5, 10, 15].contains(day) ? day : 10
        self.sepaMandateRum = (try? c.decode(String.self, forKey: .sepaMandateRum)) ?? ""
        self.sepaSignedAt = try? c.decode(String.self, forKey: .sepaSignedAt)
        self.sepaActive = (try? c.decode(Bool.self, forKey: .sepaActive)) ?? false
        self.payPalEmail = try? c.decode(String.self, forKey: .payPalEmail)
        self.payPalPayerId = try? c.decode(String.self, forKey: .payPalPayerId)
        self.payPalLinkedAt = try? c.decode(String.self, forKey: .payPalLinkedAt)
        self.payPalActive = (try? c.decode(Bool.self, forKey: .payPalActive)) ?? false
        self.billingAddress = (try? c.decode(String.self, forKey: .billingAddress)) ?? ""
        self.billingPostalCode = (try? c.decode(String.self, forKey: .billingPostalCode)) ?? ""
        self.billingCity = (try? c.decode(String.self, forKey: .billingCity)) ?? ""
    }
}

public struct VemInvoice: Codable, Identifiable, Sendable {
    public var id: Int
    public var invoiceNumber: String
    public var label: String
    public var periodLabel: String
    public var amountTtc: Double
    public var paymentMethod: String
    public var externalRef: String
    public var status: String
    public var issuedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, invoiceNumber, label, periodLabel, amountTtc, paymentMethod, externalRef, status, issuedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        self.invoiceNumber = (try? c.decode(String.self, forKey: .invoiceNumber)) ?? ""
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.periodLabel = (try? c.decode(String.self, forKey: .periodLabel)) ?? ""
        self.amountTtc = (try? c.decode(Double.self, forKey: .amountTtc)) ?? 0
        self.paymentMethod = (try? c.decode(String.self, forKey: .paymentMethod)) ?? ""
        self.externalRef = (try? c.decode(String.self, forKey: .externalRef)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "Payée"
        self.issuedAt = try? c.decode(String.self, forKey: .issuedAt)
    }
}

public struct VemInvoiceDetailResponse: Codable, Sendable {
    public var ok: Bool
    public var invoice: VemPrintableInvoiceDetail
    public var printableUrl: String
    public var seal: Vem2DDocSeal
}

public struct VemPrintableInvoiceDetail: Codable, Sendable {
    public var invoiceNumber: String
    public var label: String
    public var periodLabel: String
    public var amountTtc: Double
    public var amountHt: Double
    public var tva: Double
    public var paymentMethod: String
    public var externalRef: String
    public var status: String
    public var issuedAt: String?
    public var holder: String
    public var address: String
    public var postalCode: String
    public var city: String

    enum CodingKeys: String, CodingKey {
        case invoiceNumber, label, periodLabel, amountTtc, amountHt, tva
        case paymentMethod, externalRef, status, issuedAt, holder, address, postalCode, city
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.invoiceNumber = (try? c.decode(String.self, forKey: .invoiceNumber)) ?? ""
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.periodLabel = (try? c.decode(String.self, forKey: .periodLabel)) ?? ""
        let ttc = (try? c.decode(Double.self, forKey: .amountTtc)) ?? 0
        self.amountTtc = ttc
        self.amountHt = (try? c.decode(Double.self, forKey: .amountHt)) ?? (ttc / 1.20)
        self.tva = (try? c.decode(Double.self, forKey: .tva)) ?? (ttc - ttc / 1.20)
        self.paymentMethod = (try? c.decode(String.self, forKey: .paymentMethod)) ?? ""
        self.externalRef = (try? c.decode(String.self, forKey: .externalRef)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "Payée"
        self.issuedAt = try? c.decode(String.self, forKey: .issuedAt)
        self.holder = (try? c.decode(String.self, forKey: .holder)) ?? ""
        self.address = (try? c.decode(String.self, forKey: .address)) ?? ""
        self.postalCode = (try? c.decode(String.self, forKey: .postalCode)) ?? ""
        self.city = (try? c.decode(String.self, forKey: .city)) ?? ""
    }
}

public struct Vem2DDocSeal: Codable, Sendable {
    public var hasSeal: Bool
    public var authority: String
    public var algorithm: String
    public var docReference: String
    public var payloadRaw: String
    public var svg: String
    public var verifyUrl: String

    enum CodingKeys: String, CodingKey {
        case hasSeal, authority, algorithm, docReference, payloadRaw, svg, verifyUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hasSeal = (try? c.decode(Bool.self, forKey: .hasSeal)) ?? false
        self.authority = (try? c.decode(String.self, forKey: .authority)) ?? "ANTS DC04 · VP01 / V26A (Cenelis SA)"
        self.algorithm = (try? c.decode(String.self, forKey: .algorithm)) ?? "ECDSA NIST P-256"
        self.docReference = (try? c.decode(String.self, forKey: .docReference)) ?? ""
        self.payloadRaw = (try? c.decode(String.self, forKey: .payloadRaw)) ?? ""
        self.svg = (try? c.decode(String.self, forKey: .svg)) ?? ""
        self.verifyUrl = (try? c.decode(String.self, forKey: .verifyUrl)) ?? "https://2d-doc.prod.cenelis.com"
    }
}

// MARK: - Livria Store Orders & Viple Delivery Shipments

public struct VemOrdersDeliveryPayload: Codable, Sendable {
    public var ok: Bool = true
    public var livriaStoreUrl: String = "https://livria.store"
    public var vipleDeliveryUrl: String = "https://delivery.viplenetwork.com"
    public var orders: [VemOrderShipment] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case ok, livriaStoreUrl, vipleDeliveryUrl, orders }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? true
        self.livriaStoreUrl = (try? c.decode(String.self, forKey: .livriaStoreUrl)) ?? "https://livria.store"
        self.vipleDeliveryUrl = (try? c.decode(String.self, forKey: .vipleDeliveryUrl)) ?? "https://delivery.viplenetwork.com"
        self.orders = (try? c.decode([VemOrderShipment].self, forKey: .orders)) ?? []
    }
}

public struct VemOrderShipment: Codable, Identifiable, Sendable {
    public var id: String { "\(orderRef)-\(trackingNumber)" }
    public var source: String
    public var orderRef: String
    public var createdAtDisplay: String
    public var totalTtc: Double
    public var status: String
    public var statusCode: String
    public var stepIndex: Int
    public var carrier: String
    public var trackingNumber: String
    public var vipleDeliveryBarcode: String
    public var trackingUrl: String
    public var labelUrl: String
    public var destination: String
    public var isRelay: Bool
    public var items: [VemOrderBookItem]
    public var events: [VemDeliveryEvent]

    enum CodingKeys: String, CodingKey {
        case source, orderRef, createdAtDisplay, totalTtc, status, statusCode, stepIndex, carrier
        case trackingNumber, vipleDeliveryBarcode, trackingUrl, labelUrl, destination, isRelay, items, events
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.source = (try? c.decode(String.self, forKey: .source)) ?? "Livria Store"
        self.orderRef = (try? c.decode(String.self, forKey: .orderRef)) ?? "LIV"
        self.createdAtDisplay = (try? c.decode(String.self, forKey: .createdAtDisplay)) ?? ""
        self.totalTtc = (try? c.decode(Double.self, forKey: .totalTtc)) ?? 0
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "Confirmée"
        self.statusCode = (try? c.decode(String.self, forKey: .statusCode)) ?? ""
        self.stepIndex = min(4, max(1, (try? c.decode(Int.self, forKey: .stepIndex)) ?? 1))
        self.carrier = (try? c.decode(String.self, forKey: .carrier)) ?? "Viple Delivery"
        self.trackingNumber = (try? c.decode(String.self, forKey: .trackingNumber)) ?? ""
        self.vipleDeliveryBarcode = (try? c.decode(String.self, forKey: .vipleDeliveryBarcode)) ?? ""
        self.trackingUrl = (try? c.decode(String.self, forKey: .trackingUrl)) ?? "https://delivery.viplenetwork.com/tools/suivi"
        self.labelUrl = (try? c.decode(String.self, forKey: .labelUrl)) ?? ""
        self.destination = (try? c.decode(String.self, forKey: .destination)) ?? "France"
        self.isRelay = (try? c.decode(Bool.self, forKey: .isRelay)) ?? false
        self.items = (try? c.decode([VemOrderBookItem].self, forKey: .items)) ?? []
        self.events = (try? c.decode([VemDeliveryEvent].self, forKey: .events)) ?? []
    }
}

public struct VemOrderBookItem: Codable, Identifiable, Sendable {
    public var id: String { "\(title)-\(format)-\(quantity)" }
    public var quantity: Int
    public var unitPrice: Double
    public var format: String
    public var title: String
    public var author: String
    public var coverUrl: String

    enum CodingKeys: String, CodingKey { case quantity, unitPrice, format, title, author, coverUrl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.quantity = (try? c.decode(Int.self, forKey: .quantity)) ?? 1
        self.unitPrice = (try? c.decode(Double.self, forKey: .unitPrice)) ?? 0
        self.format = (try? c.decode(String.self, forKey: .format)) ?? "Broché"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Ouvrage"
        self.author = (try? c.decode(String.self, forKey: .author)) ?? ""
        self.coverUrl = (try? c.decode(String.self, forKey: .coverUrl)) ?? ""
    }
}

public struct VemDeliveryEvent: Codable, Identifiable, Sendable {
    public var id: String { "\(when)-\(description)" }
    public var description: String
    public var when: String
    public var location: String

    enum CodingKeys: String, CodingKey { case description, when, location }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.when = (try? c.decode(String.self, forKey: .when)) ?? ""
        self.location = (try? c.decode(String.self, forKey: .location)) ?? ""
    }
}

// MARK: - Unified Viple Live Account Profile & Presets

public struct VemAccountProfile: Codable, Sendable {
    public var email: String = ""
    public var vipleMailAddress: String = ""
    public var displayName: String = ""
    public var firstName: String = ""
    public var lastName: String = ""
    public var personalMessage: String = ""
    public var phoneNumber: String = ""
    public var city: String = ""
    public var bio: String = ""
    public var colorScheme: String = "#145346"
    public var securityAlerts: Bool = true
    public var newsletter: Bool = false
    public var userTileUrl: String = ""
    public var presetAvatars: [VemPresetAvatar] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case email, vipleMailAddress, displayName, firstName, lastName, personalMessage
        case phoneNumber, city, bio, colorScheme, securityAlerts, newsletter, userTileUrl, presetAvatars
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.vipleMailAddress = (try? c.decode(String.self, forKey: .vipleMailAddress)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.firstName = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        self.lastName = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        self.personalMessage = (try? c.decode(String.self, forKey: .personalMessage)) ?? ""
        self.phoneNumber = (try? c.decode(String.self, forKey: .phoneNumber)) ?? ""
        self.city = (try? c.decode(String.self, forKey: .city)) ?? ""
        self.bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        self.colorScheme = (try? c.decode(String.self, forKey: .colorScheme)) ?? "#145346"
        self.securityAlerts = (try? c.decode(Bool.self, forKey: .securityAlerts)) ?? true
        self.newsletter = (try? c.decode(Bool.self, forKey: .newsletter)) ?? false
        self.userTileUrl = (try? c.decode(String.self, forKey: .userTileUrl)) ?? ""
        self.presetAvatars = (try? c.decode([VemPresetAvatar].self, forKey: .presetAvatars)) ?? []
    }
}

public struct VemPresetAvatar: Codable, Identifiable, Sendable {
    public var id: String { file }
    public var file: String
    public var url: String

    enum CodingKeys: String, CodingKey { case file, url }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.file = (try? c.decode(String.self, forKey: .file)) ?? UUID().uuidString
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }
}

// MARK: - Embedded Cenelis Academy Guide Models (guide-espace-client-v4)

public struct VemAcademyBootstrap: Codable, Sendable {
    public var courses: [VemGuideCourse]
    public var bubbles: [String: VemGuideBubble]

    enum CodingKeys: String, CodingKey { case courses, bubbles }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.courses = (try? c.decode([VemGuideCourse].self, forKey: .courses)) ?? []
        self.bubbles = (try? c.decode([String: VemGuideBubble].self, forKey: .bubbles)) ?? [:]
    }
}

public struct VemGuideBubble: Codable, Sendable {
    public var term: String
    public var plain: String
    public var example: String?

    enum CodingKeys: String, CodingKey { case term, plain, example }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.term = (try? c.decode(String.self, forKey: .term)) ?? ""
        self.plain = (try? c.decode(String.self, forKey: .plain)) ?? ""
        self.example = try? c.decode(String.self, forKey: .example)
    }
}

public struct VemGuideCourse: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var duration: String
    public var passThresholdPct: Int
    public var isCustomerGuide: Bool
    public var chapters: [VemGuideChapter]
    public var parts: [VemGuidePart]
    public var quiz: [VemGuideQuizItem]

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, duration, passThresholdPct, isCustomerGuide, chapters, parts, quiz
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? "guide-espace-client-v4"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Maîtriser votre Espace Client Viple de A à Z"
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.duration = (try? c.decode(String.self, forKey: .duration)) ?? "20 min"
        self.passThresholdPct = (try? c.decode(Int.self, forKey: .passThresholdPct)) ?? 75
        self.isCustomerGuide = (try? c.decode(Bool.self, forKey: .isCustomerGuide)) ?? false
        self.chapters = (try? c.decode([VemGuideChapter].self, forKey: .chapters)) ?? []
        self.parts = (try? c.decode([VemGuidePart].self, forKey: .parts)) ?? []
        self.quiz = (try? c.decode([VemGuideQuizItem].self, forKey: .quiz)) ?? []
    }
}

public struct VemGuideChapter: Codable, Identifiable, Sendable {
    public var id: Int
    public var title: String
    public var range: [Int]

    enum CodingKeys: String, CodingKey { case id, title, range }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.range = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
    }
}

public struct VemGuidePart: Codable, Identifiable, Sendable {
    public var id: String
    public var chapter: Int?
    public var title: String
    public var duration: String
    public var summary: String
    public var blocks: [VemGuideBlock]
    public var reexplain: VemGuideReexplain?

    enum CodingKeys: String, CodingKey { case id, chapter, title, duration, summary, blocks, reexplain }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.chapter = try? c.decode(Int.self, forKey: .chapter)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.duration = (try? c.decode(String.self, forKey: .duration)) ?? "2 min"
        self.summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        self.blocks = (try? c.decode([VemGuideBlock].self, forKey: .blocks)) ?? []
        self.reexplain = try? c.decode(VemGuideReexplain.self, forKey: .reexplain)
    }
}

public struct VemGuideReexplain: Codable, Sendable {
    public var analogy: String
    public var simple: String
    public var example: String?
    public var essential: String?

    enum CodingKeys: String, CodingKey { case analogy, simple, example, essential }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.analogy = (try? c.decode(String.self, forKey: .analogy)) ?? ""
        self.simple = (try? c.decode(String.self, forKey: .simple)) ?? ""
        self.example = try? c.decode(String.self, forKey: .example)
        self.essential = try? c.decode(String.self, forKey: .essential)
    }
}

public struct VemGuideBlock: Codable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var type: String
    public var heading: String?
    public var title: String?
    public var intro: String?
    public var text: String?
    public var variant: String?
    public var caption: String?
    public var src: String?
    public var paragraphs: [String]
    public var items: [VemGuideTermItem]
    public var buttons: [VemGuideButtonItem]
    public var cases: [VemGuideScenarioCase]
    public var steps: [VemGuideFlowStep]

    enum CodingKeys: String, CodingKey {
        case type, heading, title, intro, text, variant, caption, src, paragraphs, items, buttons, cases, steps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? c.decode(String.self, forKey: .type)) ?? "prose"
        self.heading = try? c.decode(String.self, forKey: .heading)
        self.title = try? c.decode(String.self, forKey: .title)
        self.intro = try? c.decode(String.self, forKey: .intro)
        self.text = try? c.decode(String.self, forKey: .text)
        self.variant = try? c.decode(String.self, forKey: .variant)
        self.caption = try? c.decode(String.self, forKey: .caption)
        self.src = try? c.decode(String.self, forKey: .src)
        self.paragraphs = (try? c.decode([String].self, forKey: .paragraphs)) ?? []
        self.items = (try? c.decode([VemGuideTermItem].self, forKey: .items)) ?? []
        self.buttons = (try? c.decode([VemGuideButtonItem].self, forKey: .buttons)) ?? []
        self.cases = (try? c.decode([VemGuideScenarioCase].self, forKey: .cases)) ?? []
        self.steps = (try? c.decode([VemGuideFlowStep].self, forKey: .steps)) ?? []
    }
}

public struct VemGuideTermItem: Codable, Identifiable, Sendable {
    public var id: String { "\(term)-\(plain.prefix(18))" }
    public var term: String
    public var plain: String
    public var why: String?

    enum CodingKeys: String, CodingKey { case term, plain, why }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.term = (try? c.decode(String.self, forKey: .term)) ?? ""
        self.plain = (try? c.decode(String.self, forKey: .plain)) ?? ""
        self.why = try? c.decode(String.self, forKey: .why)
    }
}

public struct VemGuideButtonItem: Codable, Identifiable, Sendable {
    public var id: String { "\(label)-\(location)" }
    public var label: String
    public var location: String
    public var plainDesc: String

    enum CodingKeys: String, CodingKey { case label, whereLoc = "where", plainDesc }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.location = (try? c.decode(String.self, forKey: .whereLoc)) ?? ""
        self.plainDesc = (try? c.decode(String.self, forKey: .plainDesc)) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(location, forKey: .whereLoc)
        try c.encode(plainDesc, forKey: .plainDesc)
    }
}

public struct VemGuideScenarioCase: Codable, Identifiable, Sendable {
    public var id: String { "\(who)-\(situation.prefix(20))" }
    public var who: String
    public var situation: String
    public var solution: String

    enum CodingKeys: String, CodingKey { case who, situation, solution }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.who = (try? c.decode(String.self, forKey: .who)) ?? ""
        self.situation = (try? c.decode(String.self, forKey: .situation)) ?? ""
        self.solution = (try? c.decode(String.self, forKey: .solution)) ?? ""
    }
}

public struct VemGuideFlowStep: Codable, Identifiable, Sendable {
    public var id: String { "\(label)-\(sub.prefix(16))" }
    public var label: String
    public var sub: String

    enum CodingKeys: String, CodingKey { case label, sub }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.sub = (try? c.decode(String.self, forKey: .sub)) ?? ""
    }
}

public struct VemGuideQuizItem: Codable, Identifiable, Sendable {
    public var id: String { q }
    public var q: String
    public var options: [String]
    public var answer: Int
    public var explain: String

    enum CodingKeys: String, CodingKey { case q, options, answer, explain }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.q = (try? c.decode(String.self, forKey: .q)) ?? ""
        self.options = (try? c.decode([String].self, forKey: .options)) ?? []
        self.answer = (try? c.decode(Int.self, forKey: .answer)) ?? 0
        self.explain = (try? c.decode(String.self, forKey: .explain)) ?? ""
    }
}
