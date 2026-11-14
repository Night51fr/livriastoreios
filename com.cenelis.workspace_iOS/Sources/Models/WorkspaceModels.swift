import Foundation

// MARK: - Onglets de Recherche Multi-Scopes du Hub

public enum WorkspaceSearchScope: String, CaseIterable, Identifiable, Sendable {
    case panels = "Panels"
    case functions = "Fonctions"
    case academyHelp = "Aide"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .panels: return "Panels"
        case .functions: return "Fonctions"
        case .academyHelp: return "Aide · Academy"
        }
    }

    public var placeholder: String {
        switch self {
        case .panels:
            return "Filtrer un panel /admin (AdminGest, SysGRC, Livria…)"
        case .functions:
            return "Rechercher une fonction (Habiliter, Matrice RBAC, Registre…)"
        case .academyHelp:
            return "Chercher un cours, chapitre ou guide Cenelis Academy…"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .panels: return "square.grid.2x2.fill"
        case .functions: return "command.square.fill"
        case .academyHelp: return "graduationcap.fill"
        }
    }
}

// MARK: - État de Sécurité Application & Opérateur Connecté

public enum WorkspaceSecurityState: Equatable, Sendable {
    case booting
    case loginRequired
    case accessDenied
    case pinLocked
    case unlocked
}

public struct WorkspaceOperatorProfile: Codable, Equatable, Sendable {
    public var authenticated: Bool
    public var email: String
    public var displayName: String
    public var cid: String
    public var isAdmin: Bool
    public var status: String
    public var isSuperAdmin: Bool
    public var groups: [String]
    public var hasPinConfigured: Bool
    public var pinLength: Int

    public init(
        authenticated: Bool = false,
        email: String = "",
        displayName: String = "",
        cid: String = "",
        isAdmin: Bool = false,
        status: String = "unregistered",
        isSuperAdmin: Bool = false,
        groups: [String] = [],
        hasPinConfigured: Bool = true,
        pinLength: Int = 6
    ) {
        self.authenticated = authenticated
        self.email = email
        self.displayName = displayName
        self.cid = cid
        self.isAdmin = isAdmin
        self.status = status
        self.isSuperAdmin = isSuperAdmin
        self.groups = groups
        self.hasPinConfigured = hasPinConfigured
        self.pinLength = (pinLength == 4) ? 4 : 6
    }

    public var initials: String {
        let parts = displayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "-" })
            .prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        if !letters.isEmpty { return letters }
        return String(email.prefix(2)).uppercased()
    }
}

// MARK: - Droits RBAC Effectifs VipleAPI (/api/public/rbac/effective)

public struct WorkspaceRbacSnapshot: Codable, Equatable, Sendable {
    public var registered: Bool
    public var status: String
    public var isSuperAdmin: Bool
    public var groups: [String]
    public var permissions: Set<String>
    public var deniedPermissions: Set<String>

    public init(
        registered: Bool = false,
        status: String = "unregistered",
        isSuperAdmin: Bool = false,
        groups: [String] = [],
        permissions: Set<String> = [],
        deniedPermissions: Set<String> = []
    ) {
        self.registered = registered
        self.status = status
        self.isSuperAdmin = isSuperAdmin
        self.groups = groups
        self.permissions = permissions
        self.deniedPermissions = deniedPermissions
    }

    public var isApprovedOperator: Bool {
        status.lowercased() == "approved" && (isSuperAdmin || !permissions.isEmpty || !groups.isEmpty)
    }

    public func hasPermission(_ perm: String) -> Bool {
        guard status.lowercased() == "approved" else { return false }
        if deniedPermissions.contains("*") || deniedPermissions.contains(perm) {
            return false
        }
        if isSuperAdmin || permissions.contains("*") || permissions.contains(perm) {
            return true
        }
        return false
    }

    /// Réplique à l'identique la logique officielle de `viple-admin.js` et `EcosystemGovernance.cs`
    public func isPanelAuthorized(_ panelId: String) -> Bool {
        guard status.lowercased() == "approved" else { return false }
        if deniedPermissions.contains("*") || deniedPermissions.contains("panel:\(panelId)") {
            return false
        }
        if isSuperAdmin || permissions.contains("*") {
            return true
        }

        switch panelId {
        case "cenelis-connect":
            return hasPermission("panel:cenelis-connect")
                || permissions.contains(where: { $0.hasPrefix("panel:") })
        case "cenelis-academy":
            return hasPermission("panel:cenelis-academy")
                || !groups.isEmpty
                || !permissions.isEmpty
        case "livria":
            return hasPermission("panel:livria")
                || permissions.contains(where: { $0.hasPrefix("livria:") })
        case "viple-contracts":
            return hasPermission("panel:viple-contracts")
                || hasPermission("contracts:panel")
                || hasPermission("data:contracts.registry")
        case "viple-status":
            return hasPermission("panel:viple-status")
                || hasPermission("livria:status")
        default:
            return hasPermission("panel:\(panelId)")
        }
    }

    public func isFunctionAuthorized(_ fn: PanelFunctionItem) -> Bool {
        guard isPanelAuthorized(fn.panelId) else { return false }
        guard let specificPerm = fn.requiredPermission, !specificPerm.isEmpty else {
            return true
        }
        if specificPerm.hasPrefix("panel:") {
            return isPanelAuthorized(fn.panelId)
        }
        return hasPermission(specificPerm)
    }
}

// MARK: - Statut de Santé Temps Réel des Panels

public enum AdminPanelHealthStatus: Equatable, Sendable {
    case unknown
    case checking
    case operational(latencyMs: Int)
    case degraded(code: Int)
    case unreachable

    public var isHealthy: Bool {
        if case .operational = self { return true }
        return false
    }

    public var shortLabel: String {
        switch self {
        case .unknown: return "Prêt"
        case .checking: return "Vérif…"
        case .operational(let ms): return "\(ms) ms"
        case .degraded(let code): return "HTTP \(code)"
        case .unreachable: return "Hors-ligne"
        }
    }
}

// MARK: - Modèle Panel /admin Officiel

public struct AdminPanelItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let fullTitle: String
    public let domainLabel: String
    public let adminURLString: String
    public let category: String
    public let description: String
    public let accentHex: String
    public let iconKey: String
    public let healthProbeURLString: String

    public var isCenelisAcademyNativeApp: Bool {
        id == "cenelis-academy"
    }

    public var normalizedAdminURL: URL? {
        let normalized = Self.normalizeEcosystemURL(adminURLString)
        return URL(string: normalized)
    }

    public var healthProbeURL: URL? {
        URL(string: Self.normalizeEcosystemURL(healthProbeURLString))
    }

    public static func normalizeEcosystemURL(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: "https://master-sysgrc.console.prod.cenelis.com",
            with: "https://control.ext-sysprod.cenelis.com"
        )
    }
}

// MARK: - Modèle Fonction / Sous-Module d'Administration (Recherche « Fonctions »)

public struct PanelFunctionItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let panelId: String
    public let panelName: String
    public let title: String
    public let subtitle: String
    public let keywords: [String]
    public let targetURLString: String
    public let postLoadJavaScript: String?
    public let sfSymbol: String
    public let requiredPermission: String?

    public var targetURL: URL? {
        URL(string: AdminPanelItem.normalizeEcosystemURL(targetURLString))
    }
}

// MARK: - Modèle Résultat de Recherche « Aide (Cenelis Academy) »

public struct AcademyHelpSearchResult: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let badge: String
    public let icon: String
    public let title: String
    public let snippet: String
    public let courseId: String?
    public let courseTitle: String?
    public let chapterTitle: String?
    public let sectionId: String?
    public let stepIndex: Int?
    public let bubbleKey: String?
    public let deepDiveId: String?
    public let resourceTabId: String?
}

public struct AcademyHelpSearchEnvelope: Codable, Sendable {
    public let ok: Bool
    public let contentVersion: String?
    public let query: String?
    public let total: Int?
    public let results: [AcademyHelpSearchResult]
}

// MARK: - Référentiel Exhaustif des 24 Panels & des Fonctions Métiers Cenelis

public enum EcosystemCatalogRegistry {
    public static let allCategoriesOrdered: [String] = [
        "Tous",
        "Gouvernance, RH & Juridique",
        "Commerce, Édition & Culture",
        "Réseau, Cloud & Logistique"
    ]

    /// Référentiel complet embarqué (synchronisé dynamiquement au démarrage avec `GET /api/public/admin-directory`)
    public static let fallbackPanels: [AdminPanelItem] = [
        AdminPanelItem(
            id: "cenelis-admingest",
            name: "AdminGest RBAC",
            fullTitle: "Cenelis AdminGest — Gouvernance RBAC Centrale",
            domainLabel: "admingest.prod.cenelis.com",
            adminURLString: "https://admingest.prod.cenelis.com/",
            category: "Gouvernance, RH & Juridique",
            description: "Gouvernance centrale des accès /admin, matrice des 15 groupes métiers, délégations temporaires et audit.",
            accentHex: "#1E3A8A",
            iconKey: "key",
            healthProbeURLString: "https://admingest.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-sysgrc",
            name: "Viple SysGRC",
            fullTitle: "Viple SysGRC — Suite CRM, CPQ, SLA & Écosystème Cenelis",
            domainLabel: "grc.ext-sysprod.cenelis.com",
            adminURLString: "https://grc.ext-sysprod.cenelis.com/",
            category: "Commerce, Édition & Culture",
            description: "Suite CRM & ERP d'entreprise : Utilisateurs Viple Live ID & Fiches 365, RDV, pipeline Kanban, devis CPQ, factures et tickets SLA.",
            accentHex: "#0F548C",
            iconKey: "briefcase",
            healthProbeURLString: "https://grc.ext-sysprod.cenelis.com/healthz"
        ),
        AdminPanelItem(
            id: "viple-sysgrc-master",
            name: "SysGRC Master",
            fullTitle: "SysGRC Control-Plane — Licences & Provisionnement Multi-Tenant",
            domainLabel: "control.ext-sysprod.cenelis.com",
            adminURLString: "https://control.ext-sysprod.cenelis.com/",
            category: "Gouvernance, RH & Juridique",
            description: "Console centrale de provisionnement des licences clientes SysGRC ({slug}.ext-sysprod.cenelis.com) et bases isolées.",
            accentHex: "#1E3A8A",
            iconKey: "sliders",
            healthProbeURLString: "https://control.ext-sysprod.cenelis.com/healthz"
        ),
        AdminPanelItem(
            id: "cenelis-academy",
            name: "Cenelis Academy",
            fullTitle: "Cenelis Academy — Formation & Référentiel par Poste (App Native)",
            domainLabel: "academy.prod.cenelis.com",
            adminURLString: "https://academy.prod.cenelis.com/",
            category: "Gouvernance, RH & Juridique",
            description: "Ouverture directe dans l'application iOS native Cenelis Academy avec transfert SSO et bypass automatique du code PIN.",
            accentHex: "#0F766E",
            iconKey: "book",
            healthProbeURLString: "https://academy.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-user-console",
            name: "CRM Viple ID",
            fullTitle: "Console Utilisateurs Viple Live ID & Modération Sociale",
            domainLabel: "u.console.prod.viple.digital",
            adminURLString: "https://u.console.prod.viple.digital/",
            category: "Gouvernance, RH & Juridique",
            description: "Fiches clients 360°/365, vérification légale OTP, modération LivriaSocial et diagnostics écosystème.",
            accentHex: "#0F766E",
            iconKey: "users",
            healthProbeURLString: "https://u.console.prod.viple.digital/health"
        ),
        AdminPanelItem(
            id: "livria",
            name: "Livria Admin",
            fullTitle: "Livria Store — Administration Librairie, Marketplace & Troc",
            domainLabel: "livria.store",
            adminURLString: "https://livria.store/admin",
            category: "Commerce, Édition & Culture",
            description: "Catalogue ISBN, commandes & étiquettes UPS, marketplace vendeurs, reprises Argus, troc et manuscrits auteurs.",
            accentHex: "#6D28D9",
            iconKey: "book",
            healthProbeURLString: "https://livria.store/"
        ),
        AdminPanelItem(
            id: "cenelis-groupe",
            name: "Groupe Cenelis & Looby",
            fullTitle: "Portail Institutionnel Groupe Cenelis, Assemblée Commune & Looby",
            domainLabel: "cenelis.com",
            adminURLString: "https://cenelis.com/admin",
            category: "Gouvernance, RH & Juridique",
            description: "Gouvernance de l'Assemblée Commune, candidatures partenaires fondateurs Looby et relations institutionnelles.",
            accentHex: "#1F3A2E",
            iconKey: "landmark",
            healthProbeURLString: "https://cenelis.com/"
        ),
        AdminPanelItem(
            id: "viple-delivery",
            name: "Viple Delivery",
            fullTitle: "Viple Delivery — Réseau Points Relais Viple Taker & Logistique",
            domainLabel: "delivery.viplenetwork.com",
            adminURLString: "https://delivery.viplenetwork.com/admin",
            category: "Réseau, Cloud & Logistique",
            description: "Gestion des points relais commerçants et particuliers Viple Taker, suivi colis et acheminements.",
            accentHex: "#D97706",
            iconKey: "truck",
            healthProbeURLString: "https://delivery.viplenetwork.com/"
        ),
        AdminPanelItem(
            id: "cenelis-2ddoc",
            name: "Autorité 2D-DOC",
            fullTitle: "Autorité Cryptographique 2D-DOC, Fiches Bristol & Coffre CNI",
            domainLabel: "2d-doc.console.prod.cenelis.com",
            adminURLString: "https://2d-doc.console.prod.cenelis.com/",
            category: "Gouvernance, RH & Juridique",
            description: "Autorités X.509 ECDSA, bons de commande Bristol 30j net, coffre pièces d'identité et registre CRL.",
            accentHex: "#145346",
            iconKey: "shield",
            healthProbeURLString: "https://2d-doc.console.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-contracts",
            name: "Viple Contractuel",
            fullTitle: "Viple Contractuel — Émission & Registre des Mandats e.GL / GVN_u",
            domainLabel: "contractuel.viplenetwork.com",
            adminURLString: "https://contractuel.viplenetwork.com/admin",
            category: "Gouvernance, RH & Juridique",
            description: "Émission de contrats officiels, signature électronique horodatée et registre légal des conventions.",
            accentHex: "#0284C7",
            iconKey: "file-signature",
            healthProbeURLString: "https://contractuel.viplenetwork.com/"
        ),
        AdminPanelItem(
            id: "cenelis-recrute",
            name: "Cenelis Recrute",
            fullTitle: "Cenelis Recrute — Carrières, Offres & Candidatures Groupe",
            domainLabel: "recrute.cenelis.fr",
            adminURLString: "https://recrute.cenelis.fr/admin",
            category: "Gouvernance, RH & Juridique",
            description: "Pilotage des offres CDI/alternance, candidatures internes, gestionnaires externes e.GL et candidatures spontanées.",
            accentHex: "#A43820",
            iconKey: "briefcase",
            healthProbeURLString: "https://recrute.cenelis.fr/"
        ),
        AdminPanelItem(
            id: "cenelis-marketing",
            name: "Marketing Studio",
            fullTitle: "Cenelis Marketing Studio — Campagnes HTML, Segments RGPD & UTM",
            domainLabel: "marketing.console.prod.cenelis.com",
            adminURLString: "https://marketing.console.prod.cenelis.com/",
            category: "Commerce, Édition & Culture",
            description: "Studio visuel d'e-mails multi-marques, audiences opt-in RGPD, générateur UTM/QR et playbooks Cenelis.",
            accentHex: "#B85D19",
            iconKey: "megaphone",
            healthProbeURLString: "https://marketing.console.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "cenelis-prospect",
            name: "Prospection & RDV",
            fullTitle: "Cenelis Prospection — Pipeline Commercial, Cockpit d'Appel & RDV",
            domainLabel: "prospect.console.prod.cenelis.com",
            adminURLString: "https://prospect.console.prod.cenelis.com/",
            category: "Commerce, Édition & Culture",
            description: "Ma journée prospection, pipeline Kanban 6 étapes, cockpit d'appel avec scripts métiers et agenda RDV.",
            accentHex: "#145346",
            iconKey: "phone",
            healthProbeURLString: "https://prospect.console.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-support",
            name: "Assistance Viple",
            fullTitle: "Assistance Viple — Tickets Clients, Rappels & Médiation",
            domainLabel: "assistance.viplenetwork.com",
            adminURLString: "https://assistance.viplenetwork.com/admin",
            category: "Réseau, Cloud & Logistique",
            description: "File des tickets d'assistance, création manuelle, rappels téléphoniques, médiation et bibliothèque de réponses.",
            accentHex: "#0D9488",
            iconKey: "life-buoy",
            healthProbeURLString: "https://assistance.viplenetwork.com/"
        ),
        AdminPanelItem(
            id: "cenelis-newswire",
            name: "Cenelis Newswire",
            fullTitle: "Cenelis Newswire — Agence de Presse & Communiqués Officiels",
            domainLabel: "newswire.cenelis.com",
            adminURLString: "https://newswire.cenelis.com/admin",
            category: "Commerce, Édition & Culture",
            description: "Studio éditorial de communiqués de presse officiels, gestion des dépêches et import structuré.",
            accentHex: "#B45309",
            iconKey: "newspaper",
            healthProbeURLString: "https://newswire.cenelis.com/"
        ),
        AdminPanelItem(
            id: "cenelis-planner",
            name: "Cenelis Planner",
            fullTitle: "Cenelis Planner — Calendriers Partagés & Rituels d'Équipe",
            domainLabel: "planner.prod.cenelis.com",
            adminURLString: "https://planner.prod.cenelis.com/admin",
            category: "Gouvernance, RH & Juridique",
            description: "Organisation des réunions d'équipe, rituels récurrents et synchronisation Visio.",
            accentHex: "#1B362D",
            iconKey: "calendar",
            healthProbeURLString: "https://planner.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-gest-proct",
            name: "Viple Gest-Proct",
            fullTitle: "Viple Gest-Proct — Catalogue Commercial & Cycle de Vie Offres",
            domainLabel: "viple-gest-proct.console.prod.cenelis.com",
            adminURLString: "https://viple-gest-proct.console.prod.cenelis.com/",
            category: "Réseau, Cloud & Logistique",
            description: "Pilotage de la commercialisation des services et options Viple sur l'Espace Client v4 et les Fiches 365.",
            accentHex: "#0F766E",
            iconKey: "sliders",
            healthProbeURLString: "https://viple-gest-proct.console.prod.cenelis.com/health"
        ),
        AdminPanelItem(
            id: "viple-wingman",
            name: "Viple Wingman",
            fullTitle: "Viple Wingman — 12 Assistants Opérateurs Terrain",
            domainLabel: "viple-wingman.com",
            adminURLString: "https://viple-wingman.com/",
            category: "Commerce, Édition & Culture",
            description: "Assistants terrain : scan ISBN, réception cartons, picking commandes, validation troc, SAV et vérification KYC.",
            accentHex: "#4F46E5",
            iconKey: "box",
            healthProbeURLString: "https://viple-wingman.com/"
        ),
        AdminPanelItem(
            id: "viple-visio",
            name: "Viple Visio",
            fullTitle: "Viple Visio — Salons WebRTC HD & Relais TURN",
            domainLabel: "visio.prod.viple.digital",
            adminURLString: "https://visio.prod.viple.digital/admin",
            category: "Réseau, Cloud & Logistique",
            description: "Administration des salons de visioconférence permanents, journaux de sessions et infrastructure TURN.",
            accentHex: "#0369A1",
            iconKey: "video",
            healthProbeURLString: "https://visio.prod.viple.digital/health"
        ),
        AdminPanelItem(
            id: "viple-mail",
            name: "Viple Mail",
            fullTitle: "Viple Mail — Administration Messagerie @viplemail.fr & Stalwart",
            domainLabel: "mail.viplemail.fr",
            adminURLString: "https://mail.viplemail.fr/admin",
            category: "Réseau, Cloud & Logistique",
            description: "Provisionnement des boîtes professionnelles @viplemail.fr, quotas, alias et diagnostics IMAP/SMTP/DKIM.",
            accentHex: "#1D4ED8",
            iconKey: "mail",
            healthProbeURLString: "https://mail.viplemail.fr/"
        ),
        AdminPanelItem(
            id: "viple-shortener",
            name: "Viple Shortener",
            fullTitle: "Viple Shortener — Liens Courts Officiels g.viple.digital",
            domainLabel: "g.viple.digital",
            adminURLString: "https://g.viple.digital/admin",
            category: "Réseau, Cloud & Logistique",
            description: "Création et suivi des liens courts institutionnels et des liens contractuels sécurisés.",
            accentHex: "#0EA5E9",
            iconKey: "link",
            healthProbeURLString: "https://g.viple.digital/"
        ),
        AdminPanelItem(
            id: "viple-live",
            name: "Viple Live SSO",
            fullTitle: "Viple Live ID — Fédération OAuth 2.0 / OIDC & Annuaire",
            domainLabel: "live.viplenetwork.com",
            adminURLString: "https://live.viplenetwork.com/admin",
            category: "Réseau, Cloud & Logistique",
            description: "Clients OAuth 2.0 / OpenID Connect, liste blanche de domaines autorisés et annuaire central Viple Live.",
            accentHex: "#2563EB",
            iconKey: "shield",
            healthProbeURLString: "https://identity-v2.viple.digital/api/health"
        ),
        AdminPanelItem(
            id: "viple-status",
            name: "État Services",
            fullTitle: "Supervision & État Temps Réel des Services Cenelis / Viple",
            domainLabel: "livria.store/admin/etat-services",
            adminURLString: "https://livria.store/admin/etat-services",
            category: "Réseau, Cloud & Logistique",
            description: "Tableau de disponibilité globale des APIs, bases SQL Server et portails web de l'écosystème.",
            accentHex: "#16A34A",
            iconKey: "activity",
            healthProbeURLString: "https://api.viple.digital/"
        ),
        AdminPanelItem(
            id: "cenelis-connect",
            name: "Cenelis Connect",
            fullTitle: "Cenelis Connect — Portail Agent & Paramètres Sécurité PIN",
            domainLabel: "sso.prod.cenelis.com",
            adminURLString: "https://sso.prod.cenelis.com/portail",
            category: "Gouvernance, RH & Juridique",
            description: "Profil opérateur Cenelis Connect, groupes d'appartenance et modification du code PIN personnel.",
            accentHex: "#145346",
            iconKey: "shield",
            healthProbeURLString: "https://sso.prod.cenelis.com/health"
        )
    ]

    /// Index exhaustif des fonctions et sous-modules réels pour l'onglet « Fonctions »
    public static let allFunctions: [PanelFunctionItem] = [
        // --- ADMINGEST RBAC ---
        PanelFunctionItem(
            id: "fn-ag-matrix",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Matrice RBAC (15 Groupes & 55 Permissions)",
            subtitle: "Consulter la cartographie complète des rôles internes et externes e.GL / e.GVN_u",
            keywords: ["matrice", "rbac", "groupes", "permissions", "roles", "droits"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"overview\"]')?.click();",
            sfSymbol: "tablecells.badge.ellipsis",
            requiredPermission: "panel:cenelis-admingest"
        ),
        PanelFunctionItem(
            id: "fn-ag-users",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Registre des Opérateurs & Habilitations",
            subtitle: "Gérer les comptes habilités, groupes assignés, approbations et suspensions",
            keywords: ["registre", "operateurs", "utilisateurs", "comptes", "habilitations", "approuver"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"users\"]')?.click();",
            sfSymbol: "person.badge.key.fill",
            requiredPermission: "panel:cenelis-admingest"
        ),
        PanelFunctionItem(
            id: "fn-ag-habiliter",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Habiliter un nouvel opérateur",
            subtitle: "Ouvrir directement l'assistant de création / habilitation d'un collaborateur ou partenaire",
            keywords: ["habiliter", "nouvel operateur", "ajouter admin", "creer acces", "autoriser"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"users\"]')?.click(); setTimeout(function(){ document.getElementById('btn-top-new-user')?.click(); }, 250);",
            sfSymbol: "person.crop.circle.badge.plus",
            requiredPermission: "admingest:manage"
        ),
        PanelFunctionItem(
            id: "fn-ag-temp",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Accès Temporaires & Délégations Horodatées",
            subtitle: "Accorder ou révoquer une permission temporaire auto-expirante avec motif d'audit",
            keywords: ["temporaire", "delegation", "elevation", "urgence", "temp grant"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"temp-grants\"]')?.click();",
            sfSymbol: "clock.badge.checkmark.fill",
            requiredPermission: "admingest:temp_grant"
        ),
        PanelFunctionItem(
            id: "fn-ag-sim",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Simulateur RBAC & Diagnostic 403",
            subtitle: "Tester en direct les droits effectifs d'un e-mail sur n'importe quelle console /admin",
            keywords: ["simulateur", "tester", "403", "diagnostic", "verifier acces"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"simulator\"]')?.click();",
            sfSymbol: "stethoscope",
            requiredPermission: "panel:cenelis-admingest"
        ),
        PanelFunctionItem(
            id: "fn-ag-audit",
            panelId: "cenelis-admingest",
            panelName: "AdminGest RBAC",
            title: "Journal d'Audit Central AdminGest",
            subtitle: "Historique immuable des habilitations, connexions PIN et actions sensibles",
            keywords: ["audit", "journal", "logs", "historique", "securite"],
            targetURLString: "https://admingest.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"audit-logs\"]')?.click();",
            sfSymbol: "list.bullet.clipboard.fill",
            requiredPermission: "admingest:audit"
        ),

        // --- VIPLE SYSGRC (CRM / ERP ENTREPRISE) ---
        PanelFunctionItem(
            id: "fn-sg-dashboard",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Tableaux de bord Exécutifs CRM & SLA",
            subtitle: "Vue synthétique du chiffre d'affaires, pipeline pondéré, tickets SLA et activités",
            keywords: ["tableau de bord", "dashboard", "kpi", "sysgrc", "chiffre affaires"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/dashboard",
            postLoadJavaScript: nil,
            sfSymbol: "chart.pie.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-vipleusers",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Utilisateurs Viple Live ID (Fiches 365)",
            subtitle: "Annuaire synchronisé des clients Cenelis/Viple pour associer RDV, devis et ventes",
            keywords: ["utilisateurs", "viple live id", "fiche 365", "clients cenelis", "rdv"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/viple_users",
            postLoadJavaScript: nil,
            sfSymbol: "person.text.rectangle.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-leads",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Prospects (Leads) & Qualification BPF",
            subtitle: "Grille des prospects entrants, scoring et conversion en opportunité commerciale",
            keywords: ["prospects", "leads", "qualifier", "bpf", "acquisition"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/leads",
            postLoadJavaScript: nil,
            sfSymbol: "target",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-accounts",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Comptes Entreprises & Contacts Décideurs",
            subtitle: "Référentiel des entreprises clientes, filiales, organigrammes et encours",
            keywords: ["comptes", "entreprises", "societes", "grands comptes", "b2b"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/accounts",
            postLoadJavaScript: nil,
            sfSymbol: "building.2.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-kanban",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Pipeline Commercial Pondéré (Vue Kanban)",
            subtitle: "Pilotage visuel des opportunités par jalon de vente et probabilité de signature",
            keywords: ["kanban", "pipeline", "opportunites", "ventes", "entonnoir"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/kanban/opportunities",
            postLoadJavaScript: nil,
            sfSymbol: "rectangle.split.3x1.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-quotes",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Devis CPQ, Catalogue Produits & Tarifs",
            subtitle: "Éditer un devis multi-lignes, appliquer une grille tarifaire et convertir en commande",
            keywords: ["devis", "cpq", "proposition", "tarifs", "catalogue produits"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/quotes",
            postLoadJavaScript: nil,
            sfSymbol: "doc.text.magnifyingglass",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-invoices",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Factures, Commandes & Recouvrement",
            subtitle: "Suivi de la facturation, génération PDF, règlements et échéances",
            keywords: ["factures", "commandes", "paiements", "recouvrement", "pdf"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/invoices",
            postLoadJavaScript: nil,
            sfSymbol: "eurosign.circle.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-tickets",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Incidents / Tickets Support & SLA P1–P4",
            subtitle: "Tickets synchronisés Assistance Viple, chronomètres SLA et escalades",
            keywords: ["tickets", "incidents", "sla", "support", "escalade"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/entity/tickets",
            postLoadJavaScript: nil,
            sfSymbol: "bolt.Heart.fill".lowercased() == "bolt.heart.fill" ? "exclamationmark.bubble.fill" : "exclamationmark.bubble.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-calendar",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Calendrier Commercial & RDV Unifiés",
            subtitle: "Planifier des appels, rendez-vous téléphoniques et sessions Viple Visio",
            keywords: ["calendrier", "rdv", "rendez-vous", "activites", "agenda"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/#/calendar",
            postLoadJavaScript: nil,
            sfSymbol: "calendar.badge.plus",
            requiredPermission: "panel:viple-sysgrc"
        ),
        PanelFunctionItem(
            id: "fn-sg-admin",
            panelId: "viple-sysgrc",
            panelName: "Viple SysGRC",
            title: "Administration d'Instance SysGRC (RBAC, SSO & BYODB)",
            subtitle: "Sièges salariés, unités d'affaires, SSO OIDC/SAML, base dédiée et champs personnalisés",
            keywords: ["administration instance", "byodb", "sso", "sieges", "champs personnalises"],
            targetURLString: "https://grc.ext-sysprod.cenelis.com/admin",
            postLoadJavaScript: nil,
            sfSymbol: "gearshape.2.fill",
            requiredPermission: "panel:viple-sysgrc"
        ),

        // --- SYSGRC MASTER CONTROL-PLANE ---
        PanelFunctionItem(
            id: "fn-sgm-provision",
            panelId: "viple-sysgrc-master",
            panelName: "SysGRC Master",
            title: "Provisionner une Nouvelle Licence Entreprise SysGRC",
            subtitle: "Créer à la volée un sous-domaine client {slug}.ext-sysprod.cenelis.com et sa base isolée",
            keywords: ["provisionner", "licence", "tenant", "nouvelle entreprise", "base dediee"],
            targetURLString: "https://control.ext-sysprod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-master-tab=\"provision\"]')?.click();",
            sfSymbol: "externaldrive.fill.badge.plus",
            requiredPermission: "panel:viple-sysgrc-master"
        ),

        // --- AUTORITÉ 2D-DOC ---
        PanelFunctionItem(
            id: "fn-2ddoc-ca",
            panelId: "cenelis-2ddoc",
            panelName: "Autorité 2D-DOC",
            title: "Autorités de Certification (AC) & Certificats ECDSA",
            subtitle: "Gérer la chaîne de confiance X.509 P-256 et les clés de signature ANTS/Cenelis",
            keywords: ["autorite", "certificat", "ecdsa", "pki", "ac", "2d-doc"],
            targetURLString: "https://2d-doc.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-section=\"authorities\"]')?.click();",
            sfSymbol: "checkmark.seal.fill",
            requiredPermission: "pki2ddoc:ca"
        ),
        PanelFunctionItem(
            id: "fn-2ddoc-bristol",
            panelId: "cenelis-2ddoc",
            panelName: "Autorité 2D-DOC",
            title: "Émettre une Fiche Bristol (Bon de Commande 30j net)",
            subtitle: "Génération et scellement cryptographique 2D-DOC des bons d'achat Carrefour / fournisseurs",
            keywords: ["bristol", "bon de commande", "carrefour", "30j", "emettre"],
            targetURLString: "https://2d-doc.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-section=\"bristol\"]')?.click();",
            sfSymbol: "qrcode",
            requiredPermission: "pki2ddoc:issue"
        ),
        PanelFunctionItem(
            id: "fn-2ddoc-registry",
            panelId: "cenelis-2ddoc",
            panelName: "Autorité 2D-DOC",
            title: "Registre des Sceaux 2D-DOC & Révocation CRL",
            subtitle: "Rechercher un document scellé et révoquer en 1 clic un certificat ou acte",
            keywords: ["registre", "crl", "revoquer", "revocation", "sceau", "2d-doc"],
            targetURLString: "https://2d-doc.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-section=\"registry\"]')?.click();",
            sfSymbol: "archivebox.fill",
            requiredPermission: "panel:cenelis-2ddoc"
        ),

        // --- VIPLE CONTRACTUEL ---
        PanelFunctionItem(
            id: "fn-ct-create",
            panelId: "viple-contracts",
            panelName: "Viple Contractuel",
            title: "Émettre un Contrat (e.GL1, e.GL2, e.GVN_u, CGU)",
            subtitle: "Préparer et envoyer pour signature électronique un mandat ou contrat officiel",
            keywords: ["emettre contrat", "egl", "egvn", "mandat", "signature electronique"],
            targetURLString: "https://contractuel.viplenetwork.com/admin",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"create\"]')?.click();",
            sfSymbol: "signature",
            requiredPermission: "contracts:create"
        ),
        PanelFunctionItem(
            id: "fn-ct-registry",
            panelId: "viple-contracts",
            panelName: "Viple Contractuel",
            title: "Registre des Contrats & Signatures Électroniques",
            subtitle: "Consulter les conventions signées, preuves d'horodatage et PDF scellés",
            keywords: ["registre contrats", "signatures", "conventions", "preuves", "juridique"],
            targetURLString: "https://contractuel.viplenetwork.com/admin",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"registry\"]')?.click();",
            sfSymbol: "doc.badge.gearshape.fill",
            requiredPermission: "data:contracts.registry"
        ),

        // --- CRM VIPLE ID (u.console) ---
        PanelFunctionItem(
            id: "fn-uc-clients",
            panelId: "viple-user-console",
            panelName: "CRM Viple ID",
            title: "Fiches Clients 360° / 365 & Vérification OTP Légale",
            subtitle: "Rechercher un titulaire Viple Live ID, déclencher un OTP légal et gérer ses services",
            keywords: ["fiche 360", "fiche 365", "otp", "verification legale", "client viple"],
            targetURLString: "https://u.console.prod.viple.digital/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"clients\"]')?.click();",
            sfSymbol: "person.crop.rectangle.stack.fill",
            requiredPermission: "panel:viple-user-console"
        ),
        PanelFunctionItem(
            id: "fn-uc-social",
            panelId: "viple-user-console",
            panelName: "CRM Viple ID",
            title: "Modération LivriaSocial & Signalements",
            subtitle: "Traiter les contenus signalés, avertissements et sanctions communautaires",
            keywords: ["moderation", "livriasocial", "signalements", "sanctions", "abus"],
            targetURLString: "https://u.console.prod.viple.digital/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"social-mod\"]')?.click();",
            sfSymbol: "hand.raised.shield.fill",
            requiredPermission: "social:moderate"
        ),

        // --- LIVRIA ADMIN ---
        PanelFunctionItem(
            id: "fn-liv-books",
            panelId: "livria",
            panelName: "Livria Admin",
            title: "Catalogue Livres & Fiches ISBN",
            subtitle: "Ajouter, éditer et gérer les stocks du catalogue Livria Store",
            keywords: ["livres", "isbn", "catalogue", "stock", "edition"],
            targetURLString: "https://livria.store/admin/livres",
            postLoadJavaScript: nil,
            sfSymbol: "book.fill",
            requiredPermission: "livria:catalog"
        ),
        PanelFunctionItem(
            id: "fn-liv-orders",
            panelId: "livria",
            panelName: "Livria Admin",
            title: "Commandes Livria & Bordereaux d'Expédition UPS",
            subtitle: "Préparation des commandes, étiquettes thermiques et suivi de livraison",
            keywords: ["commandes livria", "expeditions", "ups", "colis", "bordereaux"],
            targetURLString: "https://livria.store/admin/commandes",
            postLoadJavaScript: nil,
            sfSymbol: "shippingbox.fill",
            requiredPermission: "livria:orders"
        ),
        PanelFunctionItem(
            id: "fn-liv-marketplace",
            panelId: "livria",
            panelName: "Livria Admin",
            title: "Marketplace Vendeurs & Libraires Partenaires",
            subtitle: "Validation KYC vendeurs, offres marketplace et commissions",
            keywords: ["marketplace", "vendeurs", "libraires", "partenaires"],
            targetURLString: "https://livria.store/admin/marketplace",
            postLoadJavaScript: nil,
            sfSymbol: "storefront.fill",
            requiredPermission: "livria:marketplace"
        ),
        PanelFunctionItem(
            id: "fn-liv-troc",
            panelId: "livria",
            panelName: "Livria Admin",
            title: "Troc de Livres & Reprises Argus Occasion",
            subtitle: "Superviser les échanges entre lecteurs et les rachats Argus",
            keywords: ["troc", "argus", "occasion", "reprise", "echange"],
            targetURLString: "https://livria.store/admin/troc",
            postLoadJavaScript: nil,
            sfSymbol: "arrow.triangle.2.circlepath.circle.fill",
            requiredPermission: "livria:ideas"
        ),

        // --- GROUPE CENELIS & LOOBY ---
        PanelFunctionItem(
            id: "fn-cn-looby",
            panelId: "cenelis-groupe",
            panelName: "Groupe Cenelis & Looby",
            title: "Candidatures Commerçants & Partenaires Fondateurs Looby",
            subtitle: "Dossiers d'adhésion des commerces locaux du Grand Est au réseau Looby",
            keywords: ["looby", "commercants", "partenaires fondateurs", "grand est"],
            targetURLString: "https://cenelis.com/admin",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"looby\"]')?.click();",
            sfSymbol: "bag.badge.plus",
            requiredPermission: "cenelis:governance"
        ),
        PanelFunctionItem(
            id: "fn-cn-assemblee",
            panelId: "cenelis-groupe",
            panelName: "Groupe Cenelis & Looby",
            title: "Assemblée Commune — Collège Usagers & Propositions",
            subtitle: "Gérer les candidatures au collège utilisateurs et les propositions citoyennes",
            keywords: ["assemblee commune", "propositions", "gouvernance", "college"],
            targetURLString: "https://cenelis.com/admin",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"assemblee-cand\"]')?.click();",
            sfSymbol: "person.3.sequence.fill",
            requiredPermission: "cenelis:governance"
        ),

        // --- VIPLE DELIVERY ---
        PanelFunctionItem(
            id: "fn-del-pros",
            panelId: "viple-delivery",
            panelName: "Viple Delivery",
            title: "Points Relais Commerçants & Particuliers Viple Taker",
            subtitle: "Instruction et agrément des nouveaux points relais du réseau logistique",
            keywords: ["points relais", "viple taker", "delivery", "logistique", "agrement"],
            targetURLString: "https://delivery.viplenetwork.com/admin",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"pros\"]')?.click();",
            sfSymbol: "mappin.and.ellipse",
            requiredPermission: "panel:viple-delivery"
        ),

        // --- MARKETING, PROSPECTION, RECRUTE, SUPPORT, NEWSWIRE, MAIL ---
        PanelFunctionItem(
            id: "fn-mkt-studio",
            panelId: "cenelis-marketing",
            panelName: "Marketing Studio",
            title: "Studio E-Mail Visuel Multi-Marques & Segments RGPD",
            subtitle: "Composer une campagne officielle Cenelis / Viple / Livria avec tracking UTM",
            keywords: ["studio email", "campagne", "newsletter", "rgpd", "utm", "marketing"],
            targetURLString: "https://marketing.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"studio\"]')?.click();",
            sfSymbol: "paintbrush.pointed.fill",
            requiredPermission: "marketing:studio"
        ),
        PanelFunctionItem(
            id: "fn-pro-cockpit",
            panelId: "cenelis-prospect",
            panelName: "Prospection & RDV",
            title: "Cockpit d'Appel Téléphonique & Scripts Commerciaux",
            subtitle: "Lancer une session d'appels qualifiés avec argumentaires et prise de RDV directe",
            keywords: ["cockpit", "appel", "script", "telephone", "prospection"],
            targetURLString: "https://prospect.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-vua-section-target=\"cockpit\"]')?.click();",
            sfSymbol: "headphones",
            requiredPermission: "prospect:calls"
        ),
        PanelFunctionItem(
            id: "fn-rec-jobs",
            panelId: "cenelis-recrute",
            panelName: "Cenelis Recrute",
            title: "Publier une Offre d'Emploi & Trier les Candidatures",
            subtitle: "Gérer les postes ouverts sur recrute.cenelis.fr et le vivier de candidats",
            keywords: ["recrutement", "offres emploi", "candidatures", "rh", "cv"],
            targetURLString: "https://recrute.cenelis.fr/admin",
            postLoadJavaScript: "document.querySelector('[data-adm-tab=\"jobs\"]')?.click();",
            sfSymbol: "person.badge.plus",
            requiredPermission: "panel:cenelis-recrute"
        ),
        PanelFunctionItem(
            id: "fn-sup-tickets",
            panelId: "viple-support",
            panelName: "Assistance Viple",
            title: "File des Tickets Support & Création Manuelle",
            subtitle: "Répondre aux demandes clients Viple, planifier un rappel ou ouvrir un dossier",
            keywords: ["tickets support", "assistance", "sav", "rappel", "litige"],
            targetURLString: "https://assistance.viplenetwork.com/admin/tickets",
            postLoadJavaScript: nil,
            sfSymbol: "bubble.left.and.exclamationmark.bubble.right.fill",
            requiredPermission: "panel:viple-support"
        ),
        PanelFunctionItem(
            id: "fn-nw-studio",
            panelId: "cenelis-newswire",
            panelName: "Cenelis Newswire",
            title: "Rédiger un Communiqué de Presse Officiel",
            subtitle: "Ouvrir le studio éditorial Newswire pour publier une dépêche Groupe Cenelis",
            keywords: ["communique", "presse", "depeche", "newswire", "rediger"],
            targetURLString: "https://newswire.cenelis.com/admin",
            postLoadJavaScript: "document.querySelector('[data-nw-view=\"studio\"]')?.click();",
            sfSymbol: "square.and.pencil",
            requiredPermission: "newswire:studio"
        ),
        PanelFunctionItem(
            id: "fn-gp-catalog",
            panelId: "viple-gest-proct",
            panelName: "Viple Gest-Proct",
            title: "Activer / Retirer la Commercialisation d'un Service Viple",
            subtitle: "Gérer la disponibilité des offres et options sur l'Espace Client v4",
            keywords: ["gest-proct", "commercialisation", "catalogue viple", "fin de vente", "options"],
            targetURLString: "https://viple-gest-proct.console.prod.cenelis.com/",
            postLoadJavaScript: "document.querySelector('[data-tab=\"products\"]')?.click();",
            sfSymbol: "switch.2",
            requiredPermission: "panel:viple-gest-proct"
        ),
        PanelFunctionItem(
            id: "fn-mail-box",
            panelId: "viple-mail",
            panelName: "Viple Mail",
            title: "Provisionner une Boîte Professionnelle @viplemail.fr",
            subtitle: "Créer un compte mail collaborateur, définir son quota et ses alias Stalwart",
            keywords: ["boite mail", "viplemail", "provisionner", "alias", "imap", "smtp"],
            targetURLString: "https://mail.viplemail.fr/admin",
            postLoadJavaScript: nil,
            sfSymbol: "envelope.badge.person.crop",
            requiredPermission: "panel:viple-mail"
        )
    ]
}
