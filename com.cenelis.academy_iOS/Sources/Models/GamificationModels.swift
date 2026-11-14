import Foundation

// MARK: - Système de Progression, Points XP, Séries, Rangs, Trophées & Mini-Jeux (Synchronisé Web + iOS)

public struct AcademyPassedQuizRecord: Codable, Sendable, Equatable {
    public var score: Int
    public var total: Int
    public var pct: Int?
    public var ts: Double

    public init(score: Int, total: Int, pct: Int? = nil, ts: Double = Date().timeIntervalSince1970 * 1000) {
        self.score = score
        self.total = total
        self.pct = pct
        self.ts = ts
    }

    public var effectivePct: Int {
        if let pct { return pct }
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100.0).rounded())
    }
}

public struct AcademyCourseScoreRecord: Codable, Sendable, Equatable {
    public var lastDirectScore: Int
    public var lastDirectPct: Int
    public var consolidatedScore: Int
    public var consolidatedPct: Int
    public var total: Int
    public var bestDirectPct: Int
    public var bestConsolidatedPct: Int
    public var apte: Bool
    public var attempts: Int
    public var remediatedIndices: [String: Bool]
    public var lastAnswers: [String: Int]
    public var updatedAt: Double

    public init(
        lastDirectScore: Int = 0,
        lastDirectPct: Int = 0,
        consolidatedScore: Int = 0,
        consolidatedPct: Int = 0,
        total: Int = 0,
        bestDirectPct: Int = 0,
        bestConsolidatedPct: Int = 0,
        apte: Bool = false,
        attempts: Int = 0,
        remediatedIndices: [String: Bool] = [:],
        lastAnswers: [String: Int] = [:],
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.lastDirectScore = lastDirectScore
        self.lastDirectPct = lastDirectPct
        self.consolidatedScore = consolidatedScore
        self.consolidatedPct = consolidatedPct
        self.total = total
        self.bestDirectPct = bestDirectPct
        self.bestConsolidatedPct = bestConsolidatedPct
        self.apte = apte
        self.attempts = attempts
        self.remediatedIndices = remediatedIndices
        self.lastAnswers = lastAnswers
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case lastDirectScore, lastDirectPct, consolidatedScore, consolidatedPct, total
        case bestDirectPct, bestConsolidatedPct, apte, attempts, remediatedIndices, lastAnswers, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lastDirectScore = (try? c.decode(Int.self, forKey: .lastDirectScore)) ?? 0
        self.lastDirectPct = (try? c.decode(Int.self, forKey: .lastDirectPct)) ?? 0
        self.consolidatedScore = (try? c.decode(Int.self, forKey: .consolidatedScore)) ?? 0
        self.consolidatedPct = (try? c.decode(Int.self, forKey: .consolidatedPct)) ?? 0
        self.total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        self.bestDirectPct = (try? c.decode(Int.self, forKey: .bestDirectPct)) ?? 0
        self.bestConsolidatedPct = (try? c.decode(Int.self, forKey: .bestConsolidatedPct)) ?? 0
        self.apte = (try? c.decode(Bool.self, forKey: .apte)) ?? false
        self.attempts = (try? c.decode(Int.self, forKey: .attempts)) ?? 0
        self.remediatedIndices = (try? c.decode([String: Bool].self, forKey: .remediatedIndices)) ?? [:]
        self.lastAnswers = (try? c.decode([String: Int].self, forKey: .lastAnswers)) ?? [:]
        self.updatedAt = (try? c.decode(Double.self, forKey: .updatedAt)) ?? 0
    }
}

public struct AcademyDeepDiveProgressRecord: Codable, Sendable, Equatable {
    public var maxLevel: Int
    public var completed: [String: Double]

    public init(maxLevel: Int = 1, completed: [String: Double] = [:]) {
        self.maxLevel = maxLevel
        self.completed = completed
    }

    enum CodingKeys: String, CodingKey { case maxLevel, completed }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.maxLevel = (try? c.decode(Int.self, forKey: .maxLevel)) ?? 1
        // Sur le web, completed[lvl] peut être un booléen ou un timestamp numérique
        if let numMap = try? c.decode([String: Double].self, forKey: .completed) {
            self.completed = numMap
        } else if let boolMap = try? c.decode([String: Bool].self, forKey: .completed) {
            var conv: [String: Double] = [:]
            for (k, v) in boolMap where v { conv[k] = 1 }
            self.completed = conv
        } else {
            self.completed = [:]
        }
    }
}

public struct MiniGameScoreRecord: Codable, Sendable, Equatable {
    public var highScore: Int
    public var plays: Int
    public var bestStreak: Int
    public var lastPlayedDay: String

    public init(highScore: Int = 0, plays: Int = 0, bestStreak: Int = 0, lastPlayedDay: String = "") {
        self.highScore = highScore
        self.plays = plays
        self.bestStreak = bestStreak
        self.lastPlayedDay = lastPlayedDay
    }
}

public struct AcademyUserProgress: Codable, Sendable, Equatable {
    // Champs natifs partagés avec la version Web (/api/progress)
    public var completedParts: [String: Double]
    public var passedQuizzes: [String: AcademyPassedQuizRecord]
    public var lastStep: [String: Int]
    public var courseScores: [String: AcademyCourseScoreRecord]
    public var unclearPoints: [String: Double]
    public var deepDives: [String: AcademyDeepDiveProgressRecord]

    // Champs Gamification, XP, Série quotidienne & Mini-Jeux iOS
    public var xp: Int
    public var streakDays: Int
    public var lastActiveDay: String
    public var streakShields: Int
    public var dailyGoalXP: Int
    public var dailyXPEarnedByDay: [String: Int]
    public var unlockedBadges: [String: Double]
    public var miniGameRecords: [String: MiniGameScoreRecord]
    public var exploredBubbles: [String: Bool]
    public var bookmarkedParts: [String: Bool]
    public var checkedSopSteps: [String: Bool]
    public var watchedVideos: [String: Double]

    public init(
        completedParts: [String: Double] = [:],
        passedQuizzes: [String: AcademyPassedQuizRecord] = [:],
        lastStep: [String: Int] = [:],
        courseScores: [String: AcademyCourseScoreRecord] = [:],
        unclearPoints: [String: Double] = [:],
        deepDives: [String: AcademyDeepDiveProgressRecord] = [:],
        xp: Int = 0,
        streakDays: Int = 0,
        lastActiveDay: String = "",
        streakShields: Int = 1,
        dailyGoalXP: Int = 120,
        dailyXPEarnedByDay: [String: Int] = [:],
        unlockedBadges: [String: Double] = [:],
        miniGameRecords: [String: MiniGameScoreRecord] = [:],
        exploredBubbles: [String: Bool] = [:],
        bookmarkedParts: [String: Bool] = [:],
        checkedSopSteps: [String: Bool] = [:],
        watchedVideos: [String: Double] = [:]
    ) {
        self.completedParts = completedParts
        self.passedQuizzes = passedQuizzes
        self.lastStep = lastStep
        self.courseScores = courseScores
        self.unclearPoints = unclearPoints
        self.deepDives = deepDives
        self.xp = xp
        self.streakDays = streakDays
        self.lastActiveDay = lastActiveDay
        self.streakShields = streakShields
        self.dailyGoalXP = dailyGoalXP
        self.dailyXPEarnedByDay = dailyXPEarnedByDay
        self.unlockedBadges = unlockedBadges
        self.miniGameRecords = miniGameRecords
        self.exploredBubbles = exploredBubbles
        self.bookmarkedParts = bookmarkedParts
        self.checkedSopSteps = checkedSopSteps
        self.watchedVideos = watchedVideos
    }

    enum CodingKeys: String, CodingKey {
        case completedParts, passedQuizzes, lastStep, courseScores, unclearPoints, deepDives
        case xp, streakDays, lastActiveDay, streakShields, dailyGoalXP, dailyXPEarnedByDay
        case unlockedBadges, miniGameRecords, exploredBubbles, bookmarkedParts, checkedSopSteps, watchedVideos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let numMap = try? c.decode([String: Double].self, forKey: .completedParts) {
            self.completedParts = numMap
        } else if let boolMap = try? c.decode([String: Bool].self, forKey: .completedParts) {
            var conv: [String: Double] = [:]
            for (k, v) in boolMap where v { conv[k] = 1 }
            self.completedParts = conv
        } else {
            self.completedParts = [:]
        }

        self.passedQuizzes = (try? c.decode([String: AcademyPassedQuizRecord].self, forKey: .passedQuizzes)) ?? [:]
        self.lastStep = (try? c.decode([String: Int].self, forKey: .lastStep)) ?? [:]
        self.courseScores = (try? c.decode([String: AcademyCourseScoreRecord].self, forKey: .courseScores)) ?? [:]

        if let numUnclear = try? c.decode([String: Double].self, forKey: .unclearPoints) {
            self.unclearPoints = numUnclear
        } else if let boolUnclear = try? c.decode([String: Bool].self, forKey: .unclearPoints) {
            var conv: [String: Double] = [:]
            for (k, v) in boolUnclear where v { conv[k] = 1 }
            self.unclearPoints = conv
        } else {
            self.unclearPoints = [:]
        }

        self.deepDives = (try? c.decode([String: AcademyDeepDiveProgressRecord].self, forKey: .deepDives)) ?? [:]
        self.xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        self.streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        self.lastActiveDay = (try? c.decode(String.self, forKey: .lastActiveDay)) ?? ""
        self.streakShields = (try? c.decode(Int.self, forKey: .streakShields)) ?? 1
        self.dailyGoalXP = (try? c.decode(Int.self, forKey: .dailyGoalXP)) ?? 120
        self.dailyXPEarnedByDay = (try? c.decode([String: Int].self, forKey: .dailyXPEarnedByDay)) ?? [:]
        self.unlockedBadges = (try? c.decode([String: Double].self, forKey: .unlockedBadges)) ?? [:]
        self.miniGameRecords = (try? c.decode([String: MiniGameScoreRecord].self, forKey: .miniGameRecords)) ?? [:]
        self.exploredBubbles = (try? c.decode([String: Bool].self, forKey: .exploredBubbles)) ?? [:]
        self.bookmarkedParts = (try? c.decode([String: Bool].self, forKey: .bookmarkedParts)) ?? [:]
        self.checkedSopSteps = (try? c.decode([String: Bool].self, forKey: .checkedSopSteps)) ?? [:]
        if let numVid = try? c.decode([String: Double].self, forKey: .watchedVideos) {
            self.watchedVideos = numVid
        } else if let boolVid = try? c.decode([String: Bool].self, forKey: .watchedVideos) {
            var conv: [String: Double] = [:]
            for (k, v) in boolVid where v { conv[k] = 1 }
            self.watchedVideos = conv
        } else {
            self.watchedVideos = [:]
        }

        // Si un apprenant vient du Web avec des pages déjà validées mais 0 XP mobile, créditer automatiquement ses acquis !
        if self.xp == 0 && (!self.completedParts.isEmpty || !self.passedQuizzes.isEmpty) {
            self.xp = (self.completedParts.count * 25) + (self.passedQuizzes.count * 250)
        }
    }
}

// MARK: - Rangs Institutionnels Cenelis Academy

public struct AcademyRank: Identifiable, Sendable, Equatable {
    public let id: String
    public let level: Int
    public let title: String
    public let subtitle: String
    public let minXP: Int
    public let nextMinXP: Int?
    public let sfSymbol: String

    public static let ladder: [AcademyRank] = [
        AcademyRank(id: "r1", level: 1, title: "Nouvel Arrivant", subtitle: "Découverte des 4 univers Cenelis", minXP: 0, nextMinXP: 250, sfSymbol: "leaf.fill"),
        AcademyRank(id: "r2", level: 2, title: "Initié Cenelis", subtitle: "Les bases Viple, Livria & Looby prennent vie", minXP: 250, nextMinXP: 700, sfSymbol: "sparkles"),
        AcademyRank(id: "r3", level: 3, title: "Agent Éclairé", subtitle: "Réflexes sécurité, SSO & outils maîtrisés", minXP: 700, nextMinXP: 1400, sfSymbol: "bolt.shield.fill"),
        AcademyRank(id: "r4", level: 4, title: "Praticien Métier", subtitle: "Autonome sur son poste & ses procédures", minXP: 1400, nextMinXP: 2400, sfSymbol: "briefcase.fill"),
        AcademyRank(id: "r5", level: 5, title: "Référent d'Excellence", subtitle: "Maîtrise transversale de l'écosystème", minXP: 2400, nextMinXP: 3800, sfSymbol: "medal.fill"),
        AcademyRank(id: "r6", level: 6, title: "Ambassadeur Cenelis SA", subtitle: "« À tous, pour tous, par tous. » incarné à 100 %", minXP: 3800, nextMinXP: nil, sfSymbol: "crown.fill")
    ]

    public static func current(forXP xp: Int) -> AcademyRank {
        ladder.last(where: { xp >= $0.minXP }) ?? ladder[0]
    }

    public func progressFraction(forXP xp: Int) -> Double {
        guard let nextMinXP, nextMinXP > minXP else { return 1.0 }
        return min(1.0, max(0.0, Double(xp - minXP) / Double(nextMinXP - minXP)))
    }
}

// MARK: - 12 Trophées & Distinctions Déblocables

public struct AcademyTrophy: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let sfSymbol: String
    public let xpBonus: Int
    public let isCopper: Bool

    public static let catalog: [AcademyTrophy] = [
        AcademyTrophy(id: "first_page", title: "Premier Pas à Charleville", description: "Valider votre toute première page de cours.", sfSymbol: "flag.checkered", xpBonus: 30, isCopper: false),
        AcademyTrophy(id: "curious_bubbles_5", title: "Zéro Jargon", description: "Ouvrir 5 bulles « C'est quoi … ? » pour comprendre chaque mot simplement.", sfSymbol: "text.bubble.fill", xpBonus: 50, isCopper: true),
        AcademyTrophy(id: "pages_20", title: "Explorateur Assidu", description: "Assimiler 20 pages de formation sur l'application.", sfSymbol: "book.pages.fill", xpBonus: 80, isCopper: false),
        AcademyTrophy(id: "streak_3", title: "Flamme Régulière", description: "Maintenir une série d'apprentissage de 3 jours.", sfSymbol: "flame.fill", xpBonus: 90, isCopper: true),
        AcademyTrophy(id: "deepdive_tier5", title: "Bâtisseur de Savoir", description: "Atteindre le Palier 5 complet d'un dossier d'approfondissement.", sfSymbol: "square.stack.3d.up.fill", xpBonus: 120, isCopper: false),
        AcademyTrophy(id: "arcade_first_win", title: "Joueur Éclairé", description: "Terminer votre première manche dans l'Arcade Mini-Jeux.", sfSymbol: "gamecontroller.fill", xpBonus: 60, isCopper: true),
        AcademyTrophy(id: "swipe_combo_8", title: "Réflexes Éclair", description: "Enchaîner un combo de 8 bonnes réponses en Swipe Éclair.", sfSymbol: "bolt.horizontal.circle.fill", xpBonus: 100, isCopper: true),
        AcademyTrophy(id: "apte_80", title: "Apte à Rejoindre Cenelis", description: "Dépasser le seuil officiel de 80 % sur un parcours majeur.", sfSymbol: "checkmark.seal.fill", xpBonus: 200, isCopper: false),
        AcademyTrophy(id: "mastery_100", title: "Zéro Lacune (100 %)", description: "Atteindre 100 % de maîtrise consolidée sur un parcours.", sfSymbol: "star.circle.fill", xpBonus: 300, isCopper: true),
        AcademyTrophy(id: "arcade_all_5", title: "Pentathlon Cenelis", description: "Jouer aux 5 mini-jeux pédagogiques de l'Arcade.", sfSymbol: "trophy.fill", xpBonus: 180, isCopper: true),
        AcademyTrophy(id: "pages_72", title: "Grand Marathonien", description: "Assimiler au moins 72 pages à travers les cours Cenelis.", sfSymbol: "laurel.leading", xpBonus: 250, isCopper: false),
        AcademyTrophy(id: "all_courses_certified", title: "Maître de l'Institution", description: "Valider l'attestation de tous les parcours principaux.", sfSymbol: "crown.fill", xpBonus: 500, isCopper: true)
    ]
}

// MARK: - Catalogue des 5 Mini-Jeux Natifs & Générateur Dynamique sur les Cours Appris

public enum MiniGameKind: String, CaseIterable, Identifiable, Sendable {
    case swipeBlitz = "swipe_blitz"
    case memoryMatch = "memory_match"
    case roleShift = "role_shift"
    case screenshotDetective = "screenshot_detective"
    case orderFlow = "order_flow"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .swipeBlitz: return "Swipe Éclair : Vrai ou Piège ?"
        case .memoryMatch: return "Duel des Connexions 3D"
        case .roleShift: return "Urgence au Poste !"
        case .screenshotDetective: return "Œil d'Expert Interface"
        case .orderFlow: return "Séquences Maîtrisées"
        }
    }

    public var subtitle: String {
        switch self {
        case .swipeBlitz:
            return "Glissez les cartes à droite (Réflexe Cenelis) ou à gauche (Piège à éviter) avant la fin du chrono !"
        case .memoryMatch:
            return "Reliez en retournant les cartes 3D chaque terme, contrat ou outil Cenelis à sa mission exacte."
        case .roleShift:
            return "Les notifications tombent en direct à votre poste : prenez la décision juste sous pression."
        case .screenshotDetective:
            return "Observez une vraie capture @2x des outils Cenelis et identifiez la console ou l'action exacte."
        case .orderFlow:
            return "Remettez dans l'ordre exact les étapes clés des parcours et procédures officielles Cenelis."
        }
    }

    public var sfSymbol: String {
        switch self {
        case .swipeBlitz: return "rectangle.portrait.on.rectangle.portrait.angled.fill"
        case .memoryMatch: return "square.grid.2x2.fill"
        case .roleShift: return "bell.badge.waveform.fill"
        case .screenshotDetective: return "viewfinder.rectangular"
        case .orderFlow: return "arrow.up.arrow.down.square.fill"
        }
    }

    public var durationBadge: String {
        switch self {
        case .swipeBlitz: return "60 sec · Physique & Combo"
        case .memoryMatch: return "6 paires · Cartes 3D"
        case .roleShift: return "6 urgences · Simulation"
        case .screenshotDetective: return "5 captures @2x · Visuel"
        case .orderFlow: return "4 séquences · Logique"
        }
    }

    public var baseXPReward: Int {
        switch self {
        case .swipeBlitz: return 90
        case .memoryMatch: return 85
        case .roleShift: return 110
        case .screenshotDetective: return 95
        case .orderFlow: return 100
        }
    }
}

public enum MiniGameStudyScope: String, CaseIterable, Identifiable, Sendable {
    case learnedFirst = "Sur mes cours appris"
    case allEcosystem = "Tout Cenelis"

    public var id: String { rawValue }
}

public struct SwipeBlitzItem: Identifiable, Sendable {
    public let id = UUID()
    public let topic: String
    public let statement: String
    public let isTrue: Bool
    public let explanation: String
    public let sourceCourseTitle: String
}

public struct MemoryPairConcept: Identifiable, Sendable {
    public let id: String
    public let term: String
    public let definition: String
    public let category: String
}

public struct RoleShiftScenario: Identifiable, Sendable {
    public let id = UUID()
    public let roleBadge: String
    public let incomingAlert: String
    public let options: [String]
    public let correctIndex: Int
    public let coachingNote: String
}

public struct ScreenshotDetectiveChallenge: Identifiable, Sendable {
    public let id = UUID()
    public let imagePath: String
    public let prompt: String
    public let correctTitle: String
    public let options: [String]
    public let correctIndex: Int
    public let captionHint: String
}

public struct OrderFlowPuzzle: Identifiable, Sendable {
    public let id = UUID()
    public let sourceTitle: String
    public let orderedSteps: [String]
}

// MARK: - Constructeur Dynamique de Manches Mini-Jeux depuis les Cours En Ligne

public enum AcademyMiniGameDeckBuilder {
    private static func prioritizedCourses(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, scope: MiniGameStudyScope) -> [AcademyCourse] {
        let visible = payload.courses.filter { !$0.hiddenFromHome }
        guard scope == .learnedFirst else { return visible.isEmpty ? payload.courses : visible }

        let touched = visible.filter { course in
            if progress.passedQuizzes[course.id] != nil || progress.courseScores[course.id] != nil {
                return true
            }
            return course.parts.contains { progress.completedParts[$0.id] != nil }
        }
        return touched.isEmpty ? visible : touched
    }

    public static func buildSwipeDeck(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, scope: MiniGameStudyScope, count: Int = 12) -> [SwipeBlitzItem] {
        let courses = prioritizedCourses(from: payload, progress: progress, scope: scope)
        var pool: [SwipeBlitzItem] = []

        for course in courses {
            for q in course.quiz where q.options.indices.contains(q.correct) {
                let goodText = AcademyRichTextParser.plainText(q.options[q.correct])
                let cleanQ = AcademyRichTextParser.plainText(q.q)
                let cleanExplain = AcademyRichTextParser.plainText(q.explain)
                let topic = q.topic ?? course.number

                // Carte VRAIE construite depuis la bonne réponse du quiz officiel
                pool.append(SwipeBlitzItem(
                    topic: topic,
                    statement: "\(cleanQ)\n→ \(goodText)",
                    isTrue: true,
                    explanation: cleanExplain,
                    sourceCourseTitle: course.number
                ))

                // Carte PIÈGE construite depuis un distracteur réaliste du quiz officiel
                let wrongIndices = q.options.indices.filter { $0 != q.correct }
                if let trapIdx = wrongIndices.randomElement() {
                    let trapText = AcademyRichTextParser.plainText(q.options[trapIdx])
                    pool.append(SwipeBlitzItem(
                        topic: topic,
                        statement: "\(cleanQ)\n→ \(trapText)",
                        isTrue: false,
                        explanation: q.whyWrong.map { "\(AcademyRichTextParser.plainText($0)) — \(cleanExplain)" } ?? cleanExplain,
                        sourceCourseTitle: course.number
                    ))
                }
            }
        }

        return Array(pool.shuffled().prefix(count))
    }

    public static func buildMemoryPairs(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, count: Int = 6) -> [MemoryPairConcept] {
        var pool: [MemoryPairConcept] = []

        // Prioriser d'abord les bulles déjà explorées par l'utilisateur, puis l'ensemble des 51+ bulles & glossaire
        let sortedBubbleKeys = payload.bubbles.keys.sorted { a, b in
            let aSeen = progress.exploredBubbles[a] == true
            let bSeen = progress.exploredBubbles[b] == true
            if aSeen != bSeen { return aSeen && !bSeen }
            return a < b
        }

        for key in sortedBubbleKeys {
            guard let b = payload.bubbles[key] else { continue }
            let shortDef = shorten(AcademyRichTextParser.plainText(b.analogy.isEmpty ? b.def : b.analogy), maxLen: 105)
            pool.append(MemoryPairConcept(
                id: "bub-\(key)",
                term: b.title.isEmpty ? b.q : b.title,
                definition: shortDef,
                category: "Concept Vulgarisé"
            ))
        }

        for tab in payload.resources {
            for g in tab.glossary {
                pool.append(MemoryPairConcept(
                    id: "glo-\(g.term)",
                    term: g.term,
                    definition: shorten(AcademyRichTextParser.plainText(g.def), maxLen: 105),
                    category: g.cat
                ))
            }
        }

        return Array(pool.shuffled().prefix(count))
    }

    public static func buildRoleShiftScenarios(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, scope: MiniGameStudyScope, count: Int = 6) -> [RoleShiftScenario] {
        let courses = prioritizedCourses(from: payload, progress: progress, scope: scope)
        var scenarios: [RoleShiftScenario] = []

        for course in courses {
            for q in course.quiz where q.options.count >= 3 && q.options.indices.contains(q.correct) {
                scenarios.append(RoleShiftScenario(
                    roleBadge: q.topic ?? course.badgeLabel,
                    incomingAlert: AcademyRichTextParser.plainText(q.q),
                    options: q.options.map { AcademyRichTextParser.plainText($0) },
                    correctIndex: q.correct,
                    coachingNote: AcademyRichTextParser.plainText(q.explain)
                ))
            }
        }

        return Array(scenarios.shuffled().prefix(count))
    }

    public static func buildScreenshotChallenges(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, scope: MiniGameStudyScope, count: Int = 5) -> [ScreenshotDetectiveChallenge] {
        let courses = prioritizedCourses(from: payload, progress: progress, scope: scope)
        var rawShots: [(src: String, title: String, caption: String)] = []

        for course in courses {
            let learnedPartIds = Set(course.parts.filter { progress.completedParts[$0.id] != nil }.map(\.id))
            let partsToScan = (scope == .learnedFirst && !learnedPartIds.isEmpty)
                ? course.parts.filter { learnedPartIds.contains($0.id) }
                : course.parts

            for part in partsToScan {
                for block in part.blocks where (block.type == "annotated_shot" || block.type == "screenshot") {
                    if let src = block.src, !src.isEmpty, let title = block.title, !title.isEmpty {
                        rawShots.append((
                            src: src,
                            title: AcademyRichTextParser.plainText(title),
                            caption: AcademyRichTextParser.plainText(block.caption ?? part.summary)
                        ))
                    }
                }
            }
        }

        // Compléter depuis toutes les captures si l'apprenant vient de débuter
        if rawShots.count < 4 {
            for course in payload.courses {
                for part in course.parts {
                    for block in part.blocks where (block.type == "annotated_shot" || block.type == "screenshot") {
                        if let src = block.src, !src.isEmpty, let title = block.title, !title.isEmpty {
                            rawShots.append((
                                src: src,
                                title: AcademyRichTextParser.plainText(title),
                                caption: AcademyRichTextParser.plainText(block.caption ?? part.summary)
                            ))
                        }
                    }
                }
            }
        }

        var uniqueByTitle: [String: (src: String, title: String, caption: String)] = [:]
        for item in rawShots {
            if uniqueByTitle[item.title] == nil {
                uniqueByTitle[item.title] = item
            }
        }
        let distinct = Array(uniqueByTitle.values).shuffled()
        guard distinct.count >= 4 else { return [] }

        var challenges: [ScreenshotDetectiveChallenge] = []
        for target in distinct.prefix(count) {
            let distractors = distinct.filter { $0.title != target.title }.shuffled().prefix(3).map(\.title)
            var opts = Array(distractors) + [target.title]
            opts.shuffle()
            if let correctIdx = opts.firstIndex(of: target.title) {
                challenges.append(ScreenshotDetectiveChallenge(
                    imagePath: target.src,
                    prompt: "À quel outil, écran ou fonction Cenelis correspond cette capture officielle ?",
                    correctTitle: target.title,
                    options: opts,
                    correctIndex: correctIdx,
                    captionHint: target.caption
                ))
            }
        }
        return challenges
    }

    public static func buildOrderFlowPuzzles(from payload: AcademyBootstrapPayload, progress: AcademyUserProgress, scope: MiniGameStudyScope, count: Int = 4) -> [OrderFlowPuzzle] {
        let courses = prioritizedCourses(from: payload, progress: progress, scope: scope)
        var puzzles: [OrderFlowPuzzle] = []

        for course in courses {
            for part in course.parts {
                for block in part.blocks {
                    if block.type == "visual_flow" && block.steps.count >= 3 {
                        let steps = block.steps.map { step in
                            let cleanTitle = AcademyRichTextParser.plainText(step.title)
                            let cleanText = shorten(AcademyRichTextParser.plainText(step.text), maxLen: 80)
                            return "\(cleanTitle) — \(cleanText)"
                        }
                        puzzles.append(OrderFlowPuzzle(
                            sourceTitle: AcademyRichTextParser.plainText(block.title ?? part.title),
                            orderedSteps: Array(steps.prefix(4))
                        ))
                    } else if block.type == "scenarios" {
                        for sc in block.scenarioItems where sc.steps.count >= 3 {
                            puzzles.append(OrderFlowPuzzle(
                                sourceTitle: AcademyRichTextParser.plainText(sc.title),
                                orderedSteps: Array(sc.steps.prefix(4).map { shorten(AcademyRichTextParser.plainText($0), maxLen: 95) })
                            ))
                        }
                    }
                }
            }
        }

        for tab in payload.resources {
            for sec in tab.sections where sec.type == "scenarios" {
                for sc in sec.scenarioItems where sc.steps.count >= 4 {
                    puzzles.append(OrderFlowPuzzle(
                        sourceTitle: AcademyRichTextParser.plainText(sc.title),
                        orderedSteps: Array(sc.steps.prefix(4).map { shorten(AcademyRichTextParser.plainText($0), maxLen: 95) })
                    ))
                }
            }
        }

        return Array(puzzles.shuffled().prefix(count))
    }

    private static func shorten(_ text: String, maxLen: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLen else { return trimmed }
        let prefix = trimmed.prefix(maxLen)
        return String(prefix) + "…"
    }
}
