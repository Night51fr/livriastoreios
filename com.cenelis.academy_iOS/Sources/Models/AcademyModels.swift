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
    public var progress: AcademyUserProgress?

    enum CodingKeys: String, CodingKey {
        case ok, contentVersion, publicBaseUrl, generatedAtUtc, courses, deepDives, bubbles, resources, learner, progress
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

    public init(
        authenticated: Bool = false,
        email: String = "",
        displayName: String = "",
        avatarUrl: String? = nil,
        cid: String = "",
        groups: [String] = []
    ) {
        self.authenticated = authenticated
        self.email = email
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.cid = cid
        self.groups = groups
    }

    enum CodingKeys: String, CodingKey {
        case authenticated, email, displayName, avatarUrl, cid, groups
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticated = (try? c.decode(Bool.self, forKey: .authenticated)) ?? false
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        self.cid = (try? c.decode(String.self, forKey: .cid)) ?? ""
        self.groups = (try? c.decode([String].self, forKey: .groups)) ?? []
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

public struct AcademyChapter: Codable, Identifiable, Sendable {
    public var id: Int
    public var title: String
    public var range: [Int]
    public var icon: String

    public var startIndex: Int { range.first ?? 0 }
    public var endIndex: Int { range.count > 1 ? range[1] : startIndex }

    enum CodingKeys: String, CodingKey { case id, title, range, icon }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(Int.self, forKey: .id)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.range = (try? c.decode([Int].self, forKey: .range)) ?? [0, 0]
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? "bookOpen"
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

    enum CodingKeys: String, CodingKey {
        case id, chapter, title, duration, summary, deepDiveId, blocks, reexplain
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

    // Tableaux
    public var headers: [String]
    public var rows: [[String]]

    enum CodingKeys: String, CodingKey {
        case type, icon, heading, title, intro, text, variant, scene, paragraphs, steps
        case src, mobileSrc, url, caption, crop, noMobilePair, device, pins, points
        case items, headers, rows
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

// MARK: - Parseur de Texte Enrichi & Bulles Interactives {{cle|libelle}} + Balises HTML Inline

public enum AcademyInlineToken: Identifiable, Sendable {
    case text(id: Int, content: String, isBold: Bool, isCode: Bool)
    case bubble(id: Int, key: String, label: String)

    public var id: Int {
        switch self {
        case .text(let id, _, _, _): return id
        case .bubble(let id, _, _): return id
        }
    }
}

public enum AcademyRichTextParser {
    /// Nettoie les entités HTML et balises pour un affichage brut propre (cartes, tableaux, recherche).
    public static func plainText(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        var s = raw
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)

        // Convertir {{key|label}} -> label
        let bubblePattern = #"\{\{([^|}]+)\|([^}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: bubblePattern) {
            let ns = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches where m.numberOfRanges >= 3 {
                let label = ns.substring(with: m.range(at: 2))
                s = (s as NSString).replacingCharacters(in: m.range, with: label)
            }
        }

        // Supprimer les balises HTML restantes
        if let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
            s = tagRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
        }

        return decodeEntities(s)
    }

    /// Découpe un paragraphe en segments texte / gras / code / bulles interactives `{{key|label}}`.
    public static func tokenize(_ raw: String) -> [AcademyInlineToken] {
        if raw.isEmpty { return [] }
        let normalized = decodeEntities(
            raw.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
               .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
               .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        )

        var tokens: [AcademyInlineToken] = []
        var nextId = 0

        let pattern = #"\{\{([^|}]+)\|([^}]+)\}\}|\*\*([^*]+)\*\*|<strong>(.*?)</strong>|<b>(.*?)</b>|<code>(.*?)</code>|<em>(.*?)</em>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return [.text(id: 0, content: plainText(raw), isBold: false, isCode: false)]
        }

        let ns = normalized as NSString
        var cursor = 0
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length))

        for m in matches {
            if m.range.location > cursor {
                let before = stripResidualTags(ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor)))
                if !before.isEmpty {
                    tokens.append(.text(id: nextId, content: before, isBold: false, isCode: false))
                    nextId += 1
                }
            }

            if m.range(at: 1).location != NSNotFound && m.range(at: 2).location != NSNotFound {
                let key = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                let label = stripResidualTags(ns.substring(with: m.range(at: 2)))
                tokens.append(.bubble(id: nextId, key: key, label: label))
                nextId += 1
            } else if m.range(at: 3).location != NSNotFound {
                tokens.append(.text(id: nextId, content: stripResidualTags(ns.substring(with: m.range(at: 3))), isBold: true, isCode: false))
                nextId += 1
            } else if m.range(at: 4).location != NSNotFound {
                tokens.append(.text(id: nextId, content: stripResidualTags(ns.substring(with: m.range(at: 4))), isBold: true, isCode: false))
                nextId += 1
            } else if m.range(at: 5).location != NSNotFound {
                tokens.append(.text(id: nextId, content: stripResidualTags(ns.substring(with: m.range(at: 5))), isBold: true, isCode: false))
                nextId += 1
            } else if m.range(at: 6).location != NSNotFound {
                tokens.append(.text(id: nextId, content: stripResidualTags(ns.substring(with: m.range(at: 6))), isBold: false, isCode: true))
                nextId += 1
            } else if m.range(at: 7).location != NSNotFound {
                tokens.append(.text(id: nextId, content: stripResidualTags(ns.substring(with: m.range(at: 7))), isBold: false, isCode: false))
                nextId += 1
            }

            cursor = m.range.location + m.range.length
        }

        if cursor < ns.length {
            let tail = stripResidualTags(ns.substring(from: cursor))
            if !tail.isEmpty {
                tokens.append(.text(id: nextId, content: tail, isBold: false, isCode: false))
            }
        }

        return tokens
    }

    private static func stripResidualTags(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<[^>]+>"#) else { return s }
        return regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
    }

    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&rsquo;", with: "’")
         .replacingOccurrences(of: "&lsquo;", with: "‘")
         .replacingOccurrences(of: "&laquo;", with: "«")
         .replacingOccurrences(of: "&raquo;", with: "»")
         .replacingOccurrences(of: "&ndash;", with: "–")
         .replacingOccurrences(of: "&mdash;", with: "—")
         .replacingOccurrences(of: "&rarr;", with: "→")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
