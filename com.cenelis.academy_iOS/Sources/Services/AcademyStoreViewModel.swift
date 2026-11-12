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

// MARK: - ViewModel Principal Cenelis Academy (État Réactif, Gamification & Sync Cloud)

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

    // Préférences d'interface
    @Published public var themeMode: AcademyThemeMode = .system {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "ca.themeMode") }
    }
    @Published public var readerStyle: AcademyReaderStyle = .fluid {
        didSet { UserDefaults.standard.set(readerStyle.rawValue, forKey: "ca.readerStyle") }
    }
    @Published public var shotDeviceMode: AcademyDeviceCaptureMode = .mobile {
        didSet { UserDefaults.standard.set(shotDeviceMode.rawValue, forKey: "ca.shotDeviceMode") }
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

        // Récupérer le jeton mobile Cenelis / Viple Live ID
        let storedToken = UserDefaults.standard.string(forKey: "ca.mobileToken")
            ?? sharedSuite?.string(forKey: "ca.mobileToken")
            ?? ""
        self.mobileToken = storedToken

        if let savedEmail = UserDefaults.standard.string(forKey: "ca.learnerEmail"), !savedEmail.isEmpty {
            let savedName = UserDefaults.standard.string(forKey: "ca.learnerName") ?? savedEmail
            let savedCid = UserDefaults.standard.string(forKey: "ca.learnerCid") ?? ""
            let savedGroups = UserDefaults.standard.stringArray(forKey: "ca.learnerGroups") ?? []
            self.learner = AcademyLearnerProfile(
                authenticated: !storedToken.isEmpty,
                email: savedEmail,
                displayName: savedName,
                cid: savedCid,
                groups: savedGroups
            )
        }

        // Pré-charger le cache local immédiatement
        if let localProg = AcademyAPIClient.shared.loadLocalProgress() {
            self.progress = localProg
        }
        if let cachedCat = AcademyAPIClient.shared.loadCachedBootstrap() {
            self.catalog = hydrateBubblesIfNeeded(cachedCat)
        }
    }

    // MARK: - Démarrage & Synchronisation Live avec https://academy.prod.cenelis.com

    public func bootstrapOnLaunch() async {
        let hadCachedCourses = !catalog.courses.isEmpty
        if hadCachedCourses {
            // Ne pas bloquer l'utilisateur si le cache local est déjà prêt
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isInitialBooting = false
            }
        }

        await refreshCatalogAndSync(silent: hadCachedCourses)

        if isInitialBooting {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isInitialBooting = false
            }
        }
    }

    public func refreshCatalogAndSync(silent: Bool = false) async {
        if !silent { isSyncing = true }
        defer { isSyncing = false }

        do {
            let livePayload = try await AcademyAPIClient.shared.fetchBootstrap(
                token: mobileToken.isEmpty ? nil : mobileToken,
                includeHidden: true
            )
            self.catalog = livePayload
            self.isOfflineMode = false

            if let srvLearner = livePayload.learner, srvLearner.authenticated {
                self.learner = srvLearner
                persistLearnerIdentity(srvLearner, token: mobileToken)
            }

            if let cloudProg = livePayload.progress {
                self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
            }

            refreshDailyStreakOnVisit()
            evaluateTrophies(silent: true)
            AcademyAPIClient.shared.saveLocalProgress(self.progress)

            if learner.authenticated && !mobileToken.isEmpty {
                _ = await AcademyAPIClient.shared.pushCloudProgress(self.progress, token: mobileToken)
                self.lastSyncStatus = "Synchronisé · v\(livePayload.contentVersion.prefix(8))"
            } else {
                self.lastSyncStatus = "Catalogue en direct · v\(livePayload.contentVersion.prefix(8))"
            }
        } catch {
            self.isOfflineMode = true
            self.lastSyncStatus = catalog.courses.isEmpty
                ? "Hors-ligne — vérifiez votre connexion Internet"
                : "Mode hors-ligne actif (cache local intégral)"
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

    // MARK: - Authentification Viple Live ID & SSO Mobile

    public func loginWithPassword(email: String, password: String) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let res = try await AcademyAPIClient.shared.login(email: email, password: password)
        guard let token = res.token, !token.isEmpty else {
            throw AcademyAPIError.invalidResponse
        }

        self.mobileToken = token
        if let profile = res.learner {
            self.learner = profile
            persistLearnerIdentity(profile, token: token)
        }
        if let cloudProg = res.progress {
            self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
        }

        evaluateTrophies(silent: true)
        AcademyAPIClient.shared.saveLocalProgress(self.progress)
        _ = await AcademyAPIClient.shared.pushCloudProgress(self.progress, token: token)

        AcademyHaptics.success()
        isShowingAuthSheet = false
        showXPToast(amount: 50, label: "Compte Cenelis synchronisé", isMajor: true)
    }

    public func handleSSOCallbackURL(_ url: URL) async {
        guard url.scheme?.lowercased() == "cenelisacademy",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        let items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        guard items["ok"] == "1", let token = items["token"], !token.isEmpty else {
            AcademyHaptics.warning()
            return
        }

        let email = items["email"] ?? ""
        let name = items["name"]?.isEmpty == false ? items["name"]! : email
        let cid = items["cid"] ?? ""
        let groups = (items["groups"] ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let profile = AcademyLearnerProfile(
            authenticated: true,
            email: email,
            displayName: name,
            cid: cid,
            groups: groups
        )
        self.mobileToken = token
        self.learner = profile
        persistLearnerIdentity(profile, token: token)

        if let cloudProg = await AcademyAPIClient.shared.fetchCloudProgress(token: token) {
            self.progress = Self.mergeProgress(local: self.progress, cloud: cloudProg)
        }
        AcademyAPIClient.shared.saveLocalProgress(self.progress)
        _ = await AcademyAPIClient.shared.pushCloudProgress(self.progress, token: token)

        AcademyHaptics.success()
        isShowingAuthSheet = false
        showXPToast(amount: 50, label: "SSO Cenelis Connect activé", isMajor: true)
    }

    public func logout() {
        AcademyHaptics.medium()
        mobileToken = ""
        learner = AcademyLearnerProfile()
        UserDefaults.standard.removeObject(forKey: "ca.mobileToken")
        UserDefaults.standard.removeObject(forKey: "ca.learnerEmail")
        UserDefaults.standard.removeObject(forKey: "ca.learnerName")
        UserDefaults.standard.removeObject(forKey: "ca.learnerCid")
        UserDefaults.standard.removeObject(forKey: "ca.learnerGroups")
        sharedSuite?.removeObject(forKey: "ca.mobileToken")
        lastSyncStatus = "Session locale active"
    }

    private func persistLearnerIdentity(_ profile: AcademyLearnerProfile, token: String) {
        UserDefaults.standard.set(token, forKey: "ca.mobileToken")
        UserDefaults.standard.set(profile.email, forKey: "ca.learnerEmail")
        UserDefaults.standard.set(profile.displayName, forKey: "ca.learnerName")
        UserDefaults.standard.set(profile.cid, forKey: "ca.learnerCid")
        UserDefaults.standard.set(profile.groups, forKey: "ca.learnerGroups")
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
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if let found = catalog.bubbles[cleanKey] {
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
        guard learner.authenticated, !mobileToken.isEmpty else { return }

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

        // 2. Pages de cours
        for course in catalog.courses {
            for (idx, part) in course.parts.enumerated() {
                let bodyConcat = part.blocks.flatMap { b in
                    [b.heading ?? "", b.title ?? "", b.text ?? ""] + b.paragraphs
                }.joined(separator: " ")

                if matches(part.title) || matches(part.summary) || matches(bodyConcat) {
                    results.append(GlobalSearchResult(
                        id: "part-\(course.id)-\(part.id)",
                        kind: course.number,
                        icon: AcademyIcons.sfSymbol(for: course.icon),
                        title: part.title,
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
                    title: dive.title,
                    snippet: dive.subtitle,
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

        let floorXP = (out.completedParts.count * 25) + (out.passedQuizzes.count * 250)
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
