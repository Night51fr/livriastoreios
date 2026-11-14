import Foundation

// MARK: - Modèles Typés & Résilients du Référentiel En Ligne (https://academy.prod.cenelis.com/api/mobile/v1/bootstrap)

public struct AcademyBootstrapPayload: Codable, Sendable {
    public var ok: Bool
    public var contentVersion: String
    public var publicBaseUrl: String
    public var generatedAtUtc: String?
    public var courses: [AcademyCourse]
    public var deepDives: [AcademyDeepDive]
    public var bubbles: [String: AcademyBubble]
    public var resources: [AcademyResourceTab]
    public var learner: AcademyLearnerProfile?
    public var cgu: AcademyCGUDocument?
    public var cguAcceptance: AcademyCGUAcceptanceStatus?
    public var progress: AcademyUserProgress?

    enum CodingKeys: String, CodingKey {
        case ok, contentVersion, publicBaseUrl, generatedAtUtc, courses, deepDives, bubbles, resources, learner, cgu, cguAcceptance, progress
    }

    public init(
        ok: Bool = true,
        contentVersion: String = "local",
        publicBaseUrl: String = "https://academy.prod.cenelis.com",
        generatedAtUtc: String? = nil,
        courses: [AcademyCourse] = [],
        deepDives: [AcademyDeepDive] = [],
        bubbles: [String: AcademyBubble] = [:],
        resources: [AcademyResourceTab] = [],
        learner: AcademyLearnerProfile? = nil,
        cgu: AcademyCGUDocument? = nil,
        cguAcceptance: AcademyCGUAcceptanceStatus? = nil,
        progress: AcademyUserProgress? = nil
    ) {
        self.ok = ok
        self.contentVersion = contentVersion
        self.publicBaseUrl = publicBaseUrl
        self.generatedAtUtc = generatedAtUtc
        self.courses = courses
        self.deepDives = deepDives
        self.bubbles = bubbles
        self.resources = resources
        self.learner = learner
        self.cgu = cgu
        self.cguAcceptance = cguAcceptance
        self.progress = progress
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? true
        self.contentVersion = (try? c.decode(String.self, forKey: .contentVersion)) ?? "v1"
        self.publicBaseUrl = (try? c.decode(String.self, forKey: .publicBaseUrl)) ?? "https://academy.prod.cenelis.com"
        self.generatedAtUtc = try? c.decode(String.self, forKey: .generatedAtUtc)
        self.courses = (try? c.decode([AcademyCourse].self, forKey: .courses)) ?? []
        self.deepDives = (try? c.decode([AcademyDeepDive].self, forKey: .deepDives)) ?? []
        self.bubbles = (try? c.decode([String: AcademyBubble].self, forKey: .bubbles)) ?? [:]
        self.resources = (try? c.decode([AcademyResourceTab].self, forKey: .resources)) ?? []
        self.learner = try? c.decode(AcademyLearnerProfile.self, forKey: .learner)
        self.cgu = try? c.decode(AcademyCGUDocument.self, forKey: .cgu)
        self.cguAcceptance = try? c.decode(AcademyCGUAcceptanceStatus.self, forKey: .cguAcceptance)
        self.progress = try? c.decode(AcademyUserProgress.self, forKey: .progress)
    }
}

public struct AcademyLearnerProfile: Codable, Sendable, Equatable {
    public var authenticated: Bool
    public var email: String
    public var displayName: String
    public var avatarUrl: String?
    public var cid: String
    public var groups: [String]
    public var hasCenelisAccess: Bool
    public var permissionScope: String
    public var rbacStatus: String

    public init(
        authenticated: Bool = false,
        email: String = "",
        displayName: String = "",
        avatarUrl: String? = nil,
        cid: String = "",
        groups: [String] = [],
        hasCenelisAccess: Bool = false,
        permissionScope: String = "none",
        rbacStatus: String = "anonymous"
    ) {
        self.authenticated = authenticated
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.cid = cid
        self.groups = groups
        self.hasCenelisAccess = hasCenelisAccess
        self.permissionScope = permissionScope
        self.rbacStatus = rbacStatus
    }

    public var isInternalCenelis: Bool {
        hasCenelisAccess && permissionScope.lowercased() == "interne"
    }

    public var isExternalCenelis: Bool {
        hasCenelisAccess && permissionScope.lowercased() == "externe"
    }

    public var permissionBadgeTitle: String {
        if isInternalCenelis { return "Habilitation Interne Cenelis" }
        if isExternalCenelis { return "Habilitation Externe Cenelis" }
        return "Aucune habilitation Cenelis"
    }

    enum CodingKeys: String, CodingKey {
        case authenticated, email, displayName, avatarUrl, cid, groups, hasCenelisAccess, permissionScope, rbacStatus
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = (try? c.decode(Bool.self, forKey: .authenticated)) ?? false
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        self.cid = (try? c.decode(String.self, forKey: .cid)) ?? ""
        let decodedGroups = (try? c.decode([String].self, forKey: .groups)) ?? []
        self.groups = decodedGroups
        self.rbacStatus = (try? c.decode(String.self, forKey: .rbacStatus)) ?? "unregistered"
        if let explicitAccess = try? c.decode(Bool.self, forKey: .hasCenelisAccess) {
            self.hasCenelisAccess = explicitAccess
        } else {
            self.hasCenelisAccess = self.rbacStatus.lowercased() == "approved" && !decodedGroups.isEmpty
        }
        if let explicitScope = try? c.decode(String.self, forKey: .permissionScope), !explicitScope.isEmpty {
            self.permissionScope = explicitScope
        } else if self.hasCenelisAccess {
            let hasInternal = decodedGroups.contains { !$0.lowercased().hasPrefix("e.") }
            self.permissionScope = hasInternal ? "interne" : "externe"
        } else {
            self.permissionScope = "none"
        }
    }
}

// MARK: - Conditions Générales d'Utilisation (CGU) Versionnées & Hashées

public struct AcademyCGUSection: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var number: String
    public var title: String
    public var body: String

    public init(id: String, number: String, title: String, body: String) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
    }
}

public struct AcademyCGUDocument: Codable, Sendable, Equatable {
    public var version: String
    public var effectiveDate: String
    public var contentHash: String
    public var title: String
    public var subtitle: String
    public var sections: [AcademyCGUSection]

    public init(
        version: String,
        effectiveDate: String,
        contentHash: String,
        title: String,
        subtitle: String,
        sections: [AcademyCGUSection]
    ) {
        self.version = version
        self.effectiveDate = effectiveDate
        self.contentHash = contentHash
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
    }

    public static let embeddedFallback = AcademyCGUDocument(
        version: "2026.11.1",
        effectiveDate: "14 novembre 2026",
        contentHash: "25173495d38dfbf66c26eaae",
        title: "Conditions Générales d'Utilisation — Cenelis Academy",
        subtitle: "Plateforme institutionnelle de formation, de certification interne et de maîtrise opérationnelle du Groupe Cenelis (Cenelis SA · Viple · Livria).",
        sections: [
            AcademyCGUSection(
                id: "objet-acces",
                number: "Article 1",
                title: "Objet et Réserve d'Accès aux Personnes Habilitées",
                body: "L'application mobile Cenelis Academy est un environnement professionnel strictement réservé aux collaborateurs internes du Groupe Cenelis (Cenelis SA) ainsi qu'aux partenaires et gestionnaires externes titulaires d'une habilitation contractuelle active délivrée via Cenelis AdminGest (notamment mandats e.GL1, e.GL2, e.GVN_u ou délégations temporaires). Tout compte dépourvu d'habilitation interne ou externe active se voit refuser l'accès aux contenus pédagogiques et opérationnels."
            ),
            AcademyCGUSection(
                id: "authentification-pin",
                number: "Article 2",
                title: "Connexion Nominative & Code PIN Cenelis Connect à Chaque Ouverture",
                body: "L'accès à l'application requiert obligatoirement une authentification nominative Viple Live ID / Cenelis Connect suivie, à chaque lancement de l'application, de la validation personnelle du code PIN Cenelis Connect (4 ou 6 chiffres) via le portail sécurisé Cenelis Connect intégré. Les identifiants et le code PIN sont strictement personnels, confidentiels et incessibles. Toute divulgation ou prêt de session engage la responsabilité disciplinaire et contractuelle du titulaire."
            ),
            AcademyCGUSection(
                id: "confidentialite-secret",
                number: "Article 3",
                title: "Confidentialité Absolue & Protection du Secret des Affaires",
                body: "L'ensemble des parcours métiers, architectures techniques, procédures opérationnelles standardisées (SOP), captures de consoles d'administration (/admin), guides Viple SysGRC, protocoles cryptographiques 2D-DOC et scripts commerciaux accessibles dans Cenelis Academy constituent des informations confidentielles protégées au titre du secret des affaires du Groupe Cenelis. Il est formellement interdit de reproduire, capturer, transférer ou divulguer tout ou partie de ces contenus à des tiers non habilités."
            ),
            AcademyCGUSection(
                id: "rgpd-deontologie",
                number: "Article 4",
                title: "Conformité RGPD, Périmètre Externe & Déontologie Opérationnelle",
                body: "L'utilisateur s'engage à appliquer rigoureusement les règles de protection des données personnelles (RGPD) enseignées au sein des parcours, notamment le déclenchement systématique d'une vérification légale OTP client avant toute consultation ou action sensible sur un dossier Viple Live ID, ainsi que le strict respect des limites de son groupe d'habilitation (interne ou externe e.GL / e.GVN_u)."
            ),
            AcademyCGUSection(
                id: "propriete-evaluations",
                number: "Article 5",
                title: "Propriété Intellectuelle & Loyauté des Certifications",
                body: "Tous les textes, schémas interactifs, capsules vidéo explicatives, mini-jeux d'entraînement et référentiels demeurent la propriété exclusive de Cenelis SA. L'apprenant s'engage à réaliser personnellement et loyalement les évaluations certifiantes (seuil d'aptitude de 80 % et maîtrise consolidée à 100 %) conditionnant l'exercice de ses missions."
            ),
            AcademyCGUSection(
                id: "audit-modifications",
                number: "Article 6",
                title: "Journalisation de Sécurité, Révocation & Mise à Jour des CGU",
                body: "À des fins de sécurité, de conformité réglementaire et d'audit interne, les connexions, les validations du code PIN Cenelis Connect et l'acceptation horodatée des présentes CGU sont journalisées. La suspension ou la révocation d'une habilitation dans Cenelis AdminGest entraîne le blocage immédiat de l'accès mobile. En cas de modification ou de mise à jour des présentes CGU, une nouvelle acceptation expresse sera automatiquement requise dès l'ouverture suivante de l'application."
            )
        ]
    )
}

public struct AcademyCGUAcceptanceStatus: Codable, Sendable, Equatable {
    public var accepted: Bool
    public var requiresAcceptance: Bool
    public var acceptedVersion: String
    public var acceptedHash: String
    public var acceptedAtUtc: String

    public init(
        accepted: Bool = false,
        requiresAcceptance: Bool = true,
        acceptedVersion: String = "",
        acceptedHash: String = "",
        acceptedAtUtc: String = ""
    ) {
        self.accepted = accepted
        self.requiresAcceptance = requiresAcceptance
        self.acceptedVersion = acceptedVersion
        self.acceptedHash = acceptedHash
        self.acceptedAtUtc = acceptedAtUtc
    }

    enum CodingKeys: String, CodingKey {
        case accepted, requiresAcceptance, acceptedVersion, acceptedHash, acceptedAtUtc
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let acc = (try? c.decode(Bool.self, forKey: .accepted)) ?? false
        self.accepted = acc
        self.requiresAcceptance = (try? c.decode(Bool.self, forKey: .requiresAcceptance)) ?? !acc
        self.acceptedVersion = (try? c.decode(String.self, forKey: .acceptedVersion)) ?? ""
        self.acceptedHash = (try? c.decode(String.self, forKey: .acceptedHash)) ?? ""
        self.acceptedAtUtc = (try? c.decode(String.self, forKey: .acceptedAtUtc)) ?? ""
    }
}

// MARK: - Cours, Chapitres, Pages & Blocs Natifs

public struct AcademyCourse: Codable, Identifiable, Sendable {
    public var id: String
    public var number: String
    public var isFlagshipOnboarding: Bool
    public var hiddenFromHome: Bool
    public var isCustomerGuide: Bool
    public var passThresholdPct: Int
    public var badgeLabel: String
    public var icon: String
    public var duration: String
    public var recommendedFor: [String]
    public var audience: [String]
    public var title: String
    public var subtitle: String
    public var shortcutBannerTitle: String?
    public var shortcutBannerSubtitle: String?
    public var pairCourseId: String?
    public var deviceVariant: String?
    public var roleShortcuts: [AcademyRoleShortcut]
    public var chapters: [AcademyChapter]
    public var parts: [AcademyPart]
    public var quiz: [AcademyQuizQuestion]

    enum CodingKeys: String, CodingKey {
        case id, number, isFlagshipOnboarding, hiddenFromHome, isCustomerGuide, passThresholdPct
        case badgeLabel, icon, duration, recommendedFor, audience, title, subtitle
        case shortcutBannerTitle, shortcutBannerSubtitle, pairCourseId, deviceVariant
        case roleShortcuts, chapters, parts, quiz
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.number = (try? c.decode(String.self, forKey: .number)) ?? "Cours"
        self.isFlagshipOnboarding = (try? c.decode(Bool.self, forKey: .isFlagshipOnboarding)) ?? false
        self.hiddenFromHome = (try? c.decode(Bool.self, forKey: .hiddenFromHome)) ?? false
        self.isCustomerGuide = (try? c.decode(Bool.self, forKey: .isCustomerGuide)) ?? false
        self.passThresholdPct = (try? c.decode(Int.self, forKey: .passThresholdPct)) ?? 75
        self.badgeLabel = (try? c.decode(String.self, forKey: .badgeLabel)) ?? "Parcours Officiel"
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "graduationCap"
        self.duration = (try? c.decode(String.self, forKey: .duration)) ?? "30 min"
        self.recommendedFor = (try? c.decode([String].self, forKey: .recommendedFor)) ?? ["all"]
        self.audience = (try? c.decode([String].self, forKey: .audience)) ?? []
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.shortcutBannerTitle = try? c.decode(String.self, forKey: .shortcutBannerTitle)
        self.shortcutBannerSubtitle = try? c.decode(String.self, forKey: .shortcutBannerSubtitle)
        self.pairCourseId = try? c.decode(String.self, forKey: .pairCourseId)
        self.deviceVariant = try? c.decode(String.self, forKey: .deviceVariant)
        self.roleShortcuts = (try? c.decode([AcademyRoleShortcut].self, forKey: .roleShortcuts)) ?? []
        self.chapters = (try? c.decode([AcademyChapter].self, forKey: .chapters)) ?? []
        self.parts = (try? c.decode([AcademyPart].self, forKey: .parts)) ?? []
        self.quiz = (try? c.decode([AcademyQuizQuestion].self, forKey: .quiz)) ?? []
    }
}

public struct AcademyRoleShortcut: Codable, Identifiable, Sendable {
    public var id: String { "\(label)-\(startIndex)-\(endIndex)" }
    public var label: String
    public var range: [Int]
    public var icon: String

    public var startIndex: Int { range.first ?? 0 }
    public var endIndex: Int { range.count > 1 ? range[1] : startIndex }

    enum CodingKeys: String, CodingKey { case label, range, icon }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.range = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "briefcase"
    }
}

public struct AcademyVideoCue: Codable, Identifiable, Sendable, Equatable {
    public var id: String { "\(start)-\(end)" }
    public var start: Double
    public var end: Double
    public var text: String

    enum CodingKeys: String, CodingKey { case start, end, text }

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.start = (try? c.decode(Double.self, forKey: .start)) ?? 0
        self.end = (try? c.decode(Double.self, forKey: .end)) ?? 0
        self.text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}

public struct AcademyVideoCapsule: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var badge: String
    public var durationSeconds: Int
    public var durationLabel: String
    public var url: String
    public var posterUrl: String?
    public var captionsVttUrl: String?
    public var transcript: String
    public var keyTakeaways: [String]
    public var cues: [AcademyVideoCue]

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, badge, durationSeconds, durationLabel
        case url, posterUrl, captionsVttUrl, transcript, keyTakeaways, cues
    }

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        badge: String = "Capsule vidéo explicative",
        durationSeconds: Int = 45,
        durationLabel: String = "0:45",
        url: String,
        posterUrl: String? = nil,
        captionsVttUrl: String? = nil,
        transcript: String = "",
        keyTakeaways: [String] = [],
        cues: [AcademyVideoCue] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.durationSeconds = durationSeconds
        self.durationLabel = durationLabel
        self.url = url
        self.posterUrl = posterUrl
        self.captionsVttUrl = captionsVttUrl
        self.transcript = transcript
        self.keyTakeaways = keyTakeaways
        self.cues = cues
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.badge = (try? c.decode(String.self, forKey: .badge)) ?? "Capsule vidéo explicative"
        let secs = (try? c.decode(Int.self, forKey: .durationSeconds)) ?? 45
        self.durationSeconds = secs
        if let lbl = try? c.decode(String.self, forKey: .durationLabel), !lbl.isEmpty {
            self.durationLabel = lbl
        } else {
            self.durationLabel = String(format: "%d:%02d", secs / 60, secs % 60)
        }
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
        self.posterUrl = try? c.decode(String.self, forKey: .posterUrl)
        self.captionsVttUrl = try? c.decode(String.self, forKey: .captionsVttUrl)
        self.transcript = (try? c.decode(String.self, forKey: .transcript)) ?? ""
        self.keyTakeaways = (try? c.decode([String].self, forKey: .keyTakeaways)) ?? []
        self.cues = (try? c.decode([AcademyVideoCue].self, forKey: .cues)) ?? []
    }
}

public struct AcademyChapter: Codable, Identifiable, Sendable {
    public var id: Int
    public var title: String
    public var range: [Int]
    public var icon: String
    public var video: AcademyVideoCapsule?

    public var startIndex: Int { range.first ?? 0 }
    public var endIndex: Int { range.count > 1 ? range[1] : startIndex }

    enum CodingKeys: String, CodingKey { case id, title, range, icon, video }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.range = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "bookOpen"
        self.video = try? c.decode(AcademyVideoCapsule.self, forKey: .video)
    }
}

public struct AcademyPart: Codable, Identifiable, Sendable {
    public var id: String
    public var chapter: Int?
    public var title: String
    public var duration: String
    public var summary: String
    public var deepDiveId: String?
    public var blocks: [AcademyBlock]
    public var reexplain: AcademyReexplain?
    public var video: AcademyVideoCapsule?

    enum CodingKeys: String, CodingKey {
        case id, chapter, title, duration, summary, deepDiveId, blocks, reexplain, video
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.chapter = try? c.decode(Int.self, forKey: .chapter)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.duration = (try? c.decode(String.self, forKey: .duration)) ?? "3 min"
        self.summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        self.deepDiveId = try? c.decode(String.self, forKey: .deepDiveId)
        self.blocks = (try? c.decode([AcademyBlock].self, forKey: .blocks)) ?? []
        self.reexplain = try? c.decode(AcademyReexplain.self, forKey: .reexplain)
        self.video = try? c.decode(AcademyVideoCapsule.self, forKey: .video)
    }
}

public struct AcademyReexplain: Codable, Sendable {
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

// MARK: - Bloc Polymorphe (10 types natifs : prose, visual_scene, visual_flow, annotated_shot, screenshot, callout, terms, scenarios, table, ui_buttons)

public struct AcademyBlock: Codable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var type: String
    public var icon: String?
    public var heading: String?
    public var title: String?
    public var intro: String?
    public var text: String?
    public var variant: String?
    public var scene: String?
    public var paragraphs: [String]
    public var steps: [AcademyFlowStep]

    // Captures & Annotations
    public var src: String?
    public var mobileSrc: String?
    public var url: String?
    public var caption: String?
    public var crop: Bool
    public var noMobilePair: Bool
    public var device: String?
    public var pins: [AcademyShotPin]
    public var points: [AcademyShotPoint]

    // Collections spécialisées
    public var termItems: [AcademyTermItem]
    public var scenarioItems: [AcademyScenarioItem]
    public var uiButtonItems: [AcademyUIButtonItem]

    // Tableaux & Vidéo
    public var headers: [String]
    public var rows: [[String]]
    public var video: AcademyVideoCapsule?

    enum CodingKeys: String, CodingKey {
        case type, icon, heading, title, intro, text, variant, scene, paragraphs, steps
        case src, mobileSrc, url, caption, crop, noMobilePair, device, pins, points
        case items, headers, rows, video
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedType = (try? c.decode(String.self, forKey: .type)) ?? "prose"
        self.type = decodedType
        self.icon = try? c.decode(String.self, forKey: .icon)
        self.heading = try? c.decode(String.self, forKey: .heading)
        self.title = try? c.decode(String.self, forKey: .title)
        self.intro = try? c.decode(String.self, forKey: .intro)
        self.text = try? c.decode(String.self, forKey: .text)
        self.variant = try? c.decode(String.self, forKey: .variant)
        self.scene = try? c.decode(String.self, forKey: .scene)
        self.paragraphs = (try? c.decode([String].self, forKey: .paragraphs)) ?? []
        self.steps = (try? c.decode([AcademyFlowStep].self, forKey: .steps)) ?? []

        self.src = try? c.decode(String.self, forKey: .src)
        self.mobileSrc = try? c.decode(String.self, forKey: .mobileSrc)
        self.url = try? c.decode(String.self, forKey: .url)
        self.caption = try? c.decode(String.self, forKey: .caption)
        self.crop = (try? c.decode(Bool.self, forKey: .crop)) ?? false
        self.noMobilePair = (try? c.decode(Bool.self, forKey: .noMobilePair)) ?? false
        self.device = try? c.decode(String.self, forKey: .device)
        self.pins = (try? c.decode([AcademyShotPin].self, forKey: .pins)) ?? []
        self.points = (try? c.decode([AcademyShotPoint].self, forKey: .points)) ?? []

        self.headers = (try? c.decode([String].self, forKey: .headers)) ?? []
        self.rows = (try? c.decode([[String]].self, forKey: .rows)) ?? []
        self.video = try? c.decode(AcademyVideoCapsule.self, forKey: .video)

        switch decodedType {
        case "terms":
            self.termItems = (try? c.decode([AcademyTermItem].self, forKey: .items)) ?? []
            self.scenarioItems = []
            self.uiButtonItems = []
        case "scenarios":
            self.termItems = []
            self.scenarioItems = (try? c.decode([AcademyScenarioItem].self, forKey: .items)) ?? []
            self.uiButtonItems = []
        case "ui_buttons":
            self.termItems = []
            self.scenarioItems = []
            self.uiButtonItems = (try? c.decode([AcademyUIButtonItem].self, forKey: .items)) ?? []
        default:
            self.termItems = []
            self.scenarioItems = []
            self.uiButtonItems = []
        }

        let seed = "\(decodedType)|\(heading ?? "")|\(title ?? "")|\(scene ?? "")|\(src ?? "")|\(paragraphs.first ?? "")"
        self.id = seed + "|" + UUID().uuidString.prefix(8)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encodeIfPresent(heading, forKey: .heading)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(intro, forKey: .intro)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(variant, forKey: .variant)
        try c.encodeIfPresent(scene, forKey: .scene)
        if !paragraphs.isEmpty { try c.encode(paragraphs, forKey: .paragraphs) }
        if !steps.isEmpty { try c.encode(steps, forKey: .steps) }
        try c.encodeIfPresent(src, forKey: .src)
        try c.encodeIfPresent(mobileSrc, forKey: .mobileSrc)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(caption, forKey: .caption)
        if crop { try c.encode(crop, forKey: .crop) }
        if noMobilePair { try c.encode(noMobilePair, forKey: .noMobilePair) }
        try c.encodeIfPresent(device, forKey: .device)
        if !pins.isEmpty { try c.encode(pins, forKey: .pins) }
        if !points.isEmpty { try c.encode(points, forKey: .points) }
        if !headers.isEmpty { try c.encode(headers, forKey: .headers) }
        if !rows.isEmpty { try c.encode(rows, forKey: .rows) }
        try c.encodeIfPresent(video, forKey: .video)
        switch type {
        case "terms": try c.encode(termItems, forKey: .items)
        case "scenarios": try c.encode(scenarioItems, forKey: .items)
        case "ui_buttons": try c.encode(uiButtonItems, forKey: .items)
        default: break
        }
    }

    public var resolvedAutoMobileSrc: String? {
        if let mobileSrc, !mobileSrc.isEmpty { return mobileSrc }
        guard !noMobilePair, let raw = src, !raw.isEmpty else { return nil }
        if raw.hasPrefix("/captures/pc/") {
            return raw.replacingOccurrences(of: "/captures/pc/", with: "/captures/mobile/")
        }
        if raw.hasPrefix("/captures/crops-pc/") {
            return raw.replacingOccurrences(of: "/captures/crops-pc/", with: "/captures/crops-mobile/")
        }
        return nil
    }
}

public struct AcademyFlowStep: Codable, Identifiable, Sendable {
    public var id: String { "\(tag)-\(title)" }
    public var icon: String
    public var tag: String
    public var title: String
    public var text: String

    enum CodingKeys: String, CodingKey { case icon, tag, title, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "checkCircle"
        self.tag = (try? c.decode(String.self, forKey: .tag)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}

public struct AcademyShotPin: Codable, Identifiable, Sendable {
    public var id: String { "\(x)-\(y)-\(title)" }
    public var x: Double
    public var y: Double
    public var title: String
    public var text: String

    enum CodingKeys: String, CodingKey { case x, y, title, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.x = (try? c.decode(Double.self, forKey: .x)) ?? 50
        self.y = (try? c.decode(Double.self, forKey: .y)) ?? 50
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}

public struct AcademyShotPoint: Codable, Identifiable, Sendable {
    public var id: String { "\(title)-\(text.prefix(24))" }
    public var title: String
    public var text: String

    enum CodingKeys: String, CodingKey { case title, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}

public struct AcademyTermItem: Codable, Identifiable, Sendable {
    public var id: String { "\(code)-\(title)" }
    public var code: String
    public var title: String
    public var def: String

    enum CodingKeys: String, CodingKey { case code, title, def }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = (try? c.decode(String.self, forKey: .code)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.def = (try? c.decode(String.self, forKey: .def)) ?? ""
    }
}

public struct AcademyScenarioItem: Codable, Identifiable, Sendable {
    public var id: String { "\(tag)-\(title)" }
    public var tag: String
    public var title: String
    public var steps: [String]

    enum CodingKeys: String, CodingKey { case tag, title, steps }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = (try? c.decode(String.self, forKey: .tag)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.steps = (try? c.decode([String].self, forKey: .steps)) ?? []
    }
}

public struct AcademyUIButtonItem: Codable, Identifiable, Sendable {
    public var id: String { "\(label)-\(whereLabel ?? "")" }
    public var icon: String?
    public var label: String
    public var whereLabel: String?
    public var desc: String?
    public var plainDesc: String?
    public var src: String?

    enum CodingKeys: String, CodingKey {
        case icon, label, desc, plainDesc, src
        case whereLabel = "where"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.icon = try? c.decode(String.self, forKey: .icon)
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.whereLabel = try? c.decode(String.self, forKey: .whereLabel)
        self.desc = try? c.decode(String.self, forKey: .desc)
        self.plainDesc = try? c.decode(String.self, forKey: .plainDesc)
        self.src = try? c.decode(String.self, forKey: .src)
    }
}

// MARK: - Quiz, Lacunes & Rattrapage jusqu'à 100 %

public struct AcademyQuizQuestion: Codable, Identifiable, Sendable {
    public var id: String { "\(partIdx ?? -1)-\(q.prefix(40))" }
    public var topic: String?
    public var partIdx: Int?
    public var q: String
    public var options: [String]
    public var correct: Int
    public var whyWrong: String?
    public var explain: String
    public var remediation: AcademyRemediation?

    enum CodingKeys: String, CodingKey {
        case topic, partIdx, q, options, correct, whyWrong, explain, remediation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.topic = try? c.decode(String.self, forKey: .topic)
        self.partIdx = try? c.decode(Int.self, forKey: .partIdx)
        self.q = (try? c.decode(String.self, forKey: .q)) ?? ""
        self.options = (try? c.decode([String].self, forKey: .options)) ?? []
        self.correct = (try? c.decode(Int.self, forKey: .correct)) ?? 0
        self.whyWrong = try? c.decode(String.self, forKey: .whyWrong)
        self.explain = (try? c.decode(String.self, forKey: .explain)) ?? ""
        self.remediation = try? c.decode(AcademyRemediation.self, forKey: .remediation)
    }
}

public struct AcademyRemediation: Codable, Sendable {
    public var q: String
    public var options: [String]
    public var correct: Int
    public var successNote: String?

    enum CodingKeys: String, CodingKey { case q, options, correct, successNote }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.q = (try? c.decode(String.self, forKey: .q)) ?? ""
        self.options = (try? c.decode([String].self, forKey: .options)) ?? []
        self.correct = (try? c.decode(Int.self, forKey: .correct)) ?? 0
        self.successNote = try? c.decode(String.self, forKey: .successNote)
    }
}

// MARK: - Dossiers d'Approfondissement Progressifs (5 Paliers) & Bulles « C'est quoi … ? »

public struct AcademyDeepDive: Codable, Identifiable, Sendable {
    public var id: String
    public var icon: String
    public var badge: String
    public var title: String
    public var subtitle: String
    public var relatedChapters: [Int]
    public var levels: [AcademyDeepDiveLevel]

    enum CodingKeys: String, CodingKey {
        case id, icon, badge, title, subtitle, relatedChapters, levels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "layersPlus"
        self.badge = (try? c.decode(String.self, forKey: .badge)) ?? "5 paliers progressifs"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.relatedChapters = (try? c.decode([Int].self, forKey: .relatedChapters)) ?? []
        self.levels = (try? c.decode([AcademyDeepDiveLevel].self, forKey: .levels)) ?? []
    }
}

public struct AcademyDeepDiveLevel: Codable, Identifiable, Sendable {
    public var id: Int { level }
    public var level: Int
    public var title: String
    public var summary: String
    public var analogy: String
    public var paragraphs: [String]
    public var unlockedWords: [AcademyUnlockedWord]

    enum CodingKeys: String, CodingKey {
        case level, title, summary, analogy, paragraphs, unlockedWords
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.level = (try? c.decode(Int.self, forKey: .level)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        self.analogy = (try? c.decode(String.self, forKey: .analogy)) ?? ""
        self.paragraphs = (try? c.decode([String].self, forKey: .paragraphs)) ?? []
        self.unlockedWords = (try? c.decode([AcademyUnlockedWord].self, forKey: .unlockedWords)) ?? []
    }
}

public struct AcademyUnlockedWord: Codable, Identifiable, Sendable {
    public var id: String { word }
    public var word: String
    public var def: String

    enum CodingKeys: String, CodingKey { case word, def }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.word = (try? c.decode(String.self, forKey: .word)) ?? ""
        self.def = (try? c.decode(String.self, forKey: .def)) ?? ""
    }
}

public struct AcademyBubble: Codable, Identifiable, Sendable, Equatable {
    public var key: String = ""
    public var id: String { key.isEmpty ? q : key }
    public var q: String
    public var title: String
    public var analogy: String
    public var def: String
    public var why: String

    enum CodingKeys: String, CodingKey { case q, title, analogy, def, why }

    public init(key: String = "", q: String, title: String, analogy: String, def: String, why: String) {
        self.key = key
        self.q = q
        self.title = title
        self.analogy = analogy
        self.def = def
        self.why = why
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.q = (try? c.decode(String.self, forKey: .q)) ?? "C'est quoi ?"
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.analogy = (try? c.decode(String.self, forKey: .analogy)) ?? ""
        self.def = (try? c.decode(String.self, forKey: .def)) ?? ""
        self.why = (try? c.decode(String.self, forKey: .why)) ?? ""
    }
}

// MARK: - Mode Ressources (Encyclopédie 7 Onglets, Couches, Cartes /admin, SOPs & Glossaire A–Z)

public struct AcademyResourceTab: Codable, Identifiable, Sendable {
    public var id: String
    public var icon: String
    public var label: String
    public var badge: String
    public var title: String
    public var subtitle: String
    public var archLayers: [AcademyArchLayer]
    public var cards: [AcademyResourceCard]
    public var sections: [AcademyBlock]
    public var glossary: [AcademyGlossaryEntry]

    enum CodingKeys: String, CodingKey {
        case id, icon, label, badge, title, subtitle, archLayers, cards, sections, glossary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "layers"
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.badge = (try? c.decode(String.self, forKey: .badge)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.archLayers = (try? c.decode([AcademyArchLayer].self, forKey: .archLayers)) ?? []
        self.cards = (try? c.decode([AcademyResourceCard].self, forKey: .cards)) ?? []
        self.sections = (try? c.decode([AcademyBlock].self, forKey: .sections)) ?? []
        self.glossary = (try? c.decode([AcademyGlossaryEntry].self, forKey: .glossary)) ?? []
    }
}

public struct AcademyArchLayer: Codable, Identifiable, Sendable {
    public var id: String { label }
    public var icon: String
    public var label: String
    public var nodes: [AcademyArchNode]

    enum CodingKeys: String, CodingKey { case icon, label, nodes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "layers"
        self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
        self.nodes = (try? c.decode([AcademyArchNode].self, forKey: .nodes)) ?? []
    }
}

public struct AcademyArchNode: Codable, Identifiable, Sendable {
    public var id: String { title }
    public var title: String
    public var sub: String

    enum CodingKeys: String, CodingKey { case title, sub }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.sub = (try? c.decode(String.self, forKey: .sub)) ?? ""
    }
}

public struct AcademyResourceCard: Codable, Identifiable, Sendable {
    public var id: String { "\(tag)-\(title)" }
    public var tag: String
    public var title: String
    public var url: String
    public var rbac: String
    public var shot: String?
    public var mobileShot: String?
    public var points: [String]

    enum CodingKeys: String, CodingKey {
        case tag, title, url, rbac, shot, mobileShot, points
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = (try? c.decode(String.self, forKey: .tag)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
        self.rbac = (try? c.decode(String.self, forKey: .rbac)) ?? ""
        self.shot = try? c.decode(String.self, forKey: .shot)
        self.mobileShot = try? c.decode(String.self, forKey: .mobileShot)
        self.points = (try? c.decode([String].self, forKey: .points)) ?? []
    }
}

public struct AcademyGlossaryEntry: Codable, Identifiable, Sendable {
    public var id: String { term }
    public var term: String
    public var cat: String
    public var def: String

    public var initialLetter: String {
        let folded = term.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr"))
        guard let first = folded.first else { return "#" }
        let upper = String(first).uppercased()
        return upper.rangeOfCharacter(from: .letters) != nil ? upper : "#"
    }

    enum CodingKeys: String, CodingKey { case term, cat, def }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.term = (try? c.decode(String.self, forKey: .term)) ?? ""
        self.cat = (try? c.decode(String.self, forKey: .cat)) ?? ""
        self.def = (try? c.decode(String.self, forKey: .def)) ?? ""
    }
}

// MARK: - Parseur de Texte Enrichi & Bulles Interactives {{cle|libelle}} + Markdown + Balises HTML Inline

public enum AcademyInlineToken: Identifiable, Sendable {
    case text(id: Int, content: String, isBold: Bool, isCode: Bool, isItalic: Bool = false)
    case bubble(id: Int, key: String, label: String)

    public var id: Int {
        switch self {
        case .text(let id, _, _, _, _): return id
        case .bubble(let id, _, _): return id
        }
    }
}

public enum AcademyRichTextParser {
    private static let htmlBreakRegex = try? NSRegularExpression(pattern: #"<br\s*/?>"#, options: [.caseInsensitive])
    private static let htmlLiOpenRegex = try? NSRegularExpression(pattern: #"<li(?:\s+[^>]*)?>"#, options: [.caseInsensitive])
    private static let htmlLiCloseRegex = try? NSRegularExpression(pattern: #"</li>"#, options: [.caseInsensitive])
    private static let htmlRealTagRegex = try? NSRegularExpression(pattern: #"</?[a-zA-Z][a-zA-Z0-9-]*(?:\s+[^<>]*)?>"#, options: [])
    private static let bubbleRegex = try? NSRegularExpression(pattern: #"\{\{([^|}]+)\|([^}]+)\}\}"#, options: [])
    private static let codeTickRegex = try? NSRegularExpression(pattern: #"`([^`]+)`"#, options: [])
    private static let boldMdRegex = try? NSRegularExpression(pattern: #"\*\*([\s\S]+?)\*\*"#, options: [])
    private static let italicMdRegex = try? NSRegularExpression(pattern: #"(?<![\p{L}\p{N}*])\*(?![\s.*])([^*\n]+?)(?<![\s*])\*(?![\p{L}\p{N}.*])"#, options: [])
    private static let decEntityRegex = try? NSRegularExpression(pattern: #"&#(\d{1,7});"#, options: [])
    private static let hexEntityRegex = try? NSRegularExpression(pattern: #"&#[xX]([0-9a-fA-F]{1,6});"#, options: [])

    private static let inlineTokenRegex = try? NSRegularExpression(
        pattern: #"\{\{([^|}]+)\|([^}]+)\}\}|`([^`]+)`|<code(?:\s+[^>]*)?>([\s\S]*?)</code>|<span\s+class=['"]ca-mono['"][^>]*>([\s\S]*?)</span>|\*\*([\s\S]+?)\*\*|<(?:strong|b)(?:\s+[^>]*)?>([\s\S]*?)</(?:strong|b)>|<(?:em|i)(?:\s+[^>]*)?>([\s\S]*?)</(?:em|i)>|(?<![\p{L}\p{N}*])\*(?![\s.*])([^*\n]+?)(?<![\s*])\*(?![\p{L}\p{N}.*])"#,
        options: [.caseInsensitive]
    )

    /// Nettoie intégralement le Markdown, les bulles `{{key|label}}`, les vraies balises HTML et les entités pour un affichage brut propre (titres, cartes, sommaires, quiz, recherche).
    public static func plainText(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        var s = normalizeHtmlBreaks(raw)

        // 1. Supprimer les vraies balises HTML AVANT de décoder &lt; / &gt; (préserve les chevrons techniques légitimes)
        s = stripRealHtmlTags(s)

        // 2. Convertir {{key|label}} -> label
        if let regex = bubbleRegex {
            for _ in 0..<3 {
                let ns = s as NSString
                let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed()
                if matches.isEmpty { break }
                for m in matches where m.numberOfRanges >= 3 {
                    let label = ns.substring(with: m.range(at: 2))
                    s = (s as NSString).replacingCharacters(in: m.range, with: label)
                }
            }
        }

        // 3. Supprimer les backticks `code` -> code
        if let regex = codeTickRegex {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "$1")
        }

        // 4. Supprimer le gras **texte** -> texte (y compris imbriqué)
        if let regex = boldMdRegex {
            for _ in 0..<2 {
                let len = (s as NSString).length
                let next = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: len), withTemplate: "$1")
                if next == s { break }
                s = next
            }
        }

        // 5. Supprimer l'italique *texte* sans jamais altérer *.prod.cenelis.com
        if let regex = italicMdRegex {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "$1")
        }

        return decodeEntities(s)
    }

    /// Découpe récursivement un texte en segments texte / gras / italique / code / bulles interactives `{{key|label}}` (gère les imbrications `**... {{key|label}} ...**` et `**... \`code\` ...**`).
    public static func tokenize(_ raw: String) -> [AcademyInlineToken] {
        if raw.isEmpty { return [] }
        let prepared = normalizeHtmlBreaks(raw)
        var tokens: [AcademyInlineToken] = []
        var nextId = 0
        parseSegment(prepared, bold: false, italic: false, depth: 0, nextId: &nextId, into: &tokens)
        return tokens
    }

    private static func parseSegment(
        _ segment: String,
        bold: Bool,
        italic: Bool,
        depth: Int,
        nextId: inout Int,
        into tokens: inout [AcademyInlineToken]
    ) {
        if segment.isEmpty { return }
        guard depth < 6, let regex = inlineTokenRegex else {
            let cleaned = decodeEntities(stripRealHtmlTags(segment))
            if !cleaned.isEmpty {
                tokens.append(.text(id: nextId, content: cleaned, isBold: bold, isCode: false, isItalic: italic))
                nextId += 1
            }
            return
        }

        let ns = segment as NSString
        let matches = regex.matches(in: segment, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            let cleaned = decodeEntities(stripRealHtmlTags(segment))
            if !cleaned.isEmpty {
                tokens.append(.text(id: nextId, content: cleaned, isBold: bold, isCode: false, isItalic: italic))
                nextId += 1
            }
            return
        }

        var cursor = 0
        for m in matches {
            if m.range.location > cursor {
                let beforeRaw = ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                let beforeClean = decodeEntities(stripRealHtmlTags(beforeRaw))
                if !beforeClean.isEmpty {
                    tokens.append(.text(id: nextId, content: beforeClean, isBold: bold, isCode: false, isItalic: italic))
                    nextId += 1
                }
            }

            if m.range(at: 1).location != NSNotFound && m.range(at: 2).location != NSNotFound {
                let key = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let label = plainText(ns.substring(with: m.range(at: 2)))
                tokens.append(.bubble(id: nextId, key: key, label: label))
                nextId += 1
            } else if m.range(at: 3).location != NSNotFound {
                let codeText = decodeEntities(ns.substring(with: m.range(at: 3)))
                if !codeText.isEmpty {
                    tokens.append(.text(id: nextId, content: codeText, isBold: bold, isCode: true, isItalic: italic))
                    nextId += 1
                }
            } else if m.range(at: 4).location != NSNotFound {
                let codeText = decodeEntities(stripRealHtmlTags(ns.substring(with: m.range(at: 4))))
                if !codeText.isEmpty {
                    tokens.append(.text(id: nextId, content: codeText, isBold: bold, isCode: true, isItalic: italic))
                    nextId += 1
                }
            } else if m.range(at: 5).location != NSNotFound {
                let monoText = decodeEntities(stripRealHtmlTags(ns.substring(with: m.range(at: 5))))
                if !monoText.isEmpty {
                    tokens.append(.text(id: nextId, content: monoText, isBold: bold, isCode: true, isItalic: italic))
                    nextId += 1
                }
            } else if m.range(at: 6).location != NSNotFound {
                let inner = ns.substring(with: m.range(at: 6))
                parseSegment(inner, bold: true, italic: italic, depth: depth + 1, nextId: &nextId, into: &tokens)
            } else if m.range(at: 7).location != NSNotFound {
                let inner = ns.substring(with: m.range(at: 7))
                parseSegment(inner, bold: true, italic: italic, depth: depth + 1, nextId: &nextId, into: &tokens)
            } else if m.range(at: 8).location != NSNotFound {
                let inner = ns.substring(with: m.range(at: 8))
                parseSegment(inner, bold: bold, italic: true, depth: depth + 1, nextId: &nextId, into: &tokens)
            } else if m.range(at: 9).location != NSNotFound {
                let inner = ns.substring(with: m.range(at: 9))
                parseSegment(inner, bold: bold, italic: true, depth: depth + 1, nextId: &nextId, into: &tokens)
            }

            cursor = m.range.location + m.range.length
        }

        if cursor < ns.length {
            let tailRaw = ns.substring(from: cursor)
            let tailClean = decodeEntities(stripRealHtmlTags(tailRaw))
            if !tailClean.isEmpty {
                tokens.append(.text(id: nextId, content: tailClean, isBold: bold, isCode: false, isItalic: italic))
                nextId += 1
            }
        }
    }

    private static func normalizeHtmlBreaks(_ s: String) -> String {
        var out = s
        if let br = htmlBreakRegex {
            out = br.stringByReplacingMatches(in: out, range: NSRange(location: 0, length: (out as NSString).length), withTemplate: "\n")
        }
        if let liOpen = htmlLiOpenRegex {
            out = liOpen.stringByReplacingMatches(in: out, range: NSRange(location: 0, length: (out as NSString).length), withTemplate: "\n• ")
        }
        if let liClose = htmlLiCloseRegex {
            out = liClose.stringByReplacingMatches(in: out, range: NSRange(location: 0, length: (out as NSString).length), withTemplate: "")
        }
        return out
    }

    private static func stripRealHtmlTags(_ s: String) -> String {
        guard let regex = htmlRealTagRegex else { return s }
        return regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
    }

    private static func decodeEntities(_ s: String) -> String {
        if !s.contains("&") { return s }
        var out = s
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&rdquo;", with: "”")
            .replacingOccurrences(of: "&laquo;", with: "«")
            .replacingOccurrences(of: "&raquo;", with: "»")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&rarr;", with: "→")
            .replacingOccurrences(of: "&larr;", with: "←")
            .replacingOccurrences(of: "&harr;", with: "↔")
            .replacingOccurrences(of: "&bull;", with: "•")
            .replacingOccurrences(of: "&middot;", with: "·")
            .replacingOccurrences(of: "&hellip;", with: "…")
            .replacingOccurrences(of: "&times;", with: "×")
            .replacingOccurrences(of: "&euro;", with: "€")
            .replacingOccurrences(of: "&copy;", with: "©")
            .replacingOccurrences(of: "&reg;", with: "®")
            .replacingOccurrences(of: "&ge;", with: "≥")
            .replacingOccurrences(of: "&le;", with: "≤")
            .replacingOccurrences(of: "&ne;", with: "≠")
            .replacingOccurrences(of: "&plusmn;", with: "±")
            .replacingOccurrences(of: "&deg;", with: "°")
            .replacingOccurrences(of: "&thinsp;", with: " ")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        if out.contains("&#"), let decRegex = decEntityRegex {
            let ns = out as NSString
            let matches = decRegex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches where m.numberOfRanges >= 2 {
                if let code = UInt32(ns.substring(with: m.range(at: 1))),
                   let scalar = UnicodeScalar(code) {
                    out = (out as NSString).replacingCharacters(in: m.range, with: String(scalar))
                }
            }
        }
        if out.contains("&#"), let hexRegex = hexEntityRegex {
            let ns = out as NSString
            let matches = hexRegex.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches where m.numberOfRanges >= 2 {
                if let code = UInt32(ns.substring(with: m.range(at: 1)), radix: 16),
                   let scalar = UnicodeScalar(code) {
                    out = (out as NSString).replacingCharacters(in: m.range, with: String(scalar))
                }
            }
        }

        return out.replacingOccurrences(of: "&amp;", with: "&")
    }
}
