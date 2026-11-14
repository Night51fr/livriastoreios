import SwiftUI

// MARK: - Accueil Cenelis Academy (Hero Orbital, Reprise 1-Clic, Postes, Parcours, Défi Arcade & 5 Paliers)

public struct HomeHubView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    private var rolesCourse: AcademyCourse? {
        vm.catalog.courses.first(where: { !$0.roleShortcuts.isEmpty })
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 1. Hero Motion Design & Tableau de Bord XP
                    OrbitalConstellationHeroView(vm: vm)

                    // 2. Carte « Reprendre en 1 touche »
                    if let resumeCourse = vm.resumeCandidateCourse {
                        resumeSpotlightCard(course: resumeCourse)
                    }

                    // 3. Lanceur rapide par Poste chez Cenelis
                    if let rc = rolesCourse, !rc.roleShortcuts.isEmpty {
                        roleQuickLauncherSection(course: rc)
                    }

                    // 4. Parcours Phares Synchronisés en Direct
                    flagshipCoursesSection

                    // 5. Défi Quotidien Mini-Jeux sur les Cours Appris
                    dailyArcadeChallengeBanner

                    // 6. Carrousel des 9 Approfondissements Progressifs (5 Paliers)
                    if !vm.catalog.deepDives.isEmpty {
                        deepDivesCarouselSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable {
                await vm.refreshCatalogAndSync(silent: false)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Cenelis Academy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if vm.learner.authenticated {
                            vm.activeTab = .passport
                        } else {
                            vm.isShowingAuthSheet = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: vm.learner.authenticated ? "checkmark.shield.fill" : "person.crop.circle.badge.plus")
                                .foregroundStyle(AcademyPalette.pine)
                            Text(vm.learner.authenticated ? "Synchronisé" : "Connexion")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            AcademyHaptics.selection()
                            vm.isShowingSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AcademyPalette.pine)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Carte Reprise Rapide

    private func resumeSpotlightCard(course: AcademyCourse) -> some View {
        let savedStep = vm.progress.lastStep[course.id] ?? 0
        let donePages = vm.completedPartsCount(for: course)

        return Button {
            vm.openCourse(course.id)
        } label: {
            HStack(spacing: 14) {
                AnimatedMasteryRing(
                    progress: vm.readingProgressFraction(for: course),
                    size: 54,
                    lineWidth: 5.5,
                    tint: AcademyPalette.copper,
                    trackColor: AcademyPalette.copperSoft,
                    centerText: "\(vm.courseReadingPercent(course))%"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(donePages == 0 ? "COMMENCER MON PARCOURS" : "REPRENDRE MA LECTURE")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)
                    Text(AcademyRichTextParser.plainText(course.title))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(savedStep >= course.parts.count
                         ? "Évaluation Finale prête · \(course.quiz.count) questions"
                         : "Page \(savedStep + 1) sur \(course.parts.count) · +25 XP par page")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AcademyPalette.pineSolid)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AcademyPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AcademyPalette.copperBorder, lineWidth: 1.3))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
    }

    // MARK: - Accès Direct par Poste chez Cenelis

    private func roleQuickLauncherSection(course: AcademyCourse) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Réussir mon poste chez Cenelis")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)
                    Text("Sautez directement au guide opérationnel de votre mission")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(course.roleShortcuts) { sc in
                        Button {
                            vm.openCourse(course.id, stepIndex: sc.startIndex)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: AcademyIcons.sfSymbol(for: sc.icon))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AcademyPalette.pine)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(AcademyPalette.pineSoft))

                                Text(sc.label)
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text("Pages \(sc.startIndex + 1)–\(sc.endIndex + 1) →")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AcademyPalette.copper)
                            }
                            .padding(13)
                            .frame(width: 162, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AcademyPalette.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
                            )
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Liste des Parcours Officiels

    private var flagshipCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parcours Officiels En Ligne")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Spacer()
                Button("Tout voir") {
                    AcademyHaptics.selection()
                    vm.activeTab = .courses
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AcademyPalette.pine)
            }

            ForEach(vm.visibleHomeCourses) { course in
                CourseSummaryRowCard(course: course, vm: vm)
            }
        }
    }

    // MARK: - Bannière Défi Quotidien Arcade

    private var dailyArcadeChallengeBanner: some View {
        Button {
            AcademyHaptics.medium()
            vm.activeTab = .arcade
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ARCADE MINI-JEUX · +90 À +150 XP")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                    Text("Testez vos réflexes sur vos cours appris !")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text("Swipe Éclair · Duel 3D · Urgence au Poste · Œil @2x · Séquences")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AcademyPalette.copperGradient)
                    .shadow(color: AcademyPalette.copperSolid.opacity(0.28), radius: 12, y: 6)
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
    }

    // MARK: - Carrousel Approfondissements 5 Paliers

    private var deepDivesCarouselSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dossiers d'Approfondissement (5 Paliers)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text("Du niveau débutant absolu jusqu'à la vision experte, palier par palier")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AcademyPalette.inkSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.catalog.deepDives) { dive in
                        let done = vm.progress.deepDives[dive.id]?.completed.count ?? 0
                        Button {
                            vm.openDeepDive(id: dive.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: AcademyIcons.sfSymbol(for: dive.icon))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(AcademyPalette.pine)
                                    Spacer()
                                    AcademyBadge("\(done)/\(dive.levels.count)", style: done == dive.levels.count ? .success : .pine)
                                }
                                Text(AcademyRichTextParser.plainText(dive.title))
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(AcademyRichTextParser.plainText(dive.subtitle))
                                    .font(.system(size: 12))
                                    .foregroundStyle(AcademyPalette.inkSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(width: 235, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AcademyPalette.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
                            )
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Carte Synthétique Réutilisable d'un Parcours Cenelis Academy

public struct CourseSummaryRowCard: View {
    public let course: AcademyCourse
    @ObservedObject var vm: AcademyStoreViewModel

    public init(course: AcademyCourse, vm: AcademyStoreViewModel) {
        self.course = course
        self.vm = vm
    }

    private var videoCapsulesCount: Int {
        var ids = Set<String>()
        for ch in course.chapters {
            if let v = ch.video { ids.insert(v.id) }
        }
        for part in course.parts {
            if let v = part.video { ids.insert(v.id) }
            for b in part.blocks {
                if let v = b.video { ids.insert(v.id) }
            }
        }
        return ids.count
    }

    public var body: some View {
        let donePages = vm.completedPartsCount(for: course)
        let certified = vm.isCourseCertified(course)
        let quizPct = vm.courseConsolidatedPct(course)
        let vidCount = videoCapsulesCount

        Button {
            vm.openCourse(course.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(course.isFlagshipOnboarding ? AcademyPalette.pineSolid : AcademyPalette.pineSoft)
                            .frame(width: 48, height: 48)
                        Image(systemName: AcademyIcons.sfSymbol(for: course.icon))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(course.isFlagshipOnboarding ? AcademyPalette.gold : AcademyPalette.pine)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            AcademyBadge(course.number, style: course.isFlagshipOnboarding ? .copper : .pine)
                            if vidCount > 0 {
                                AcademyBadge("\(vidCount) vidéo\(vidCount > 1 ? "s" : "")", icon: "play.rectangle.fill", style: .copper)
                            }
                            if certified {
                                AcademyBadge("Apte \(quizPct)%", icon: "checkmark.seal.fill", style: .success)
                            }
                        }

                        Text(AcademyRichTextParser.plainText(course.title))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                            .multilineTextAlignment(.leading)

                        Text(AcademyRichTextParser.plainText(course.subtitle))
                            .font(.system(size: 12.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                // Barre de progression et métadonnées
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AcademyPalette.surfaceSubtle)
                            Capsule()
                                .fill(certified ? AcademyPalette.success : AcademyPalette.pineSolid)
                                .frame(width: max(6, geo.size.width * vm.readingProgressFraction(for: course)))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Label("\(donePages)/\(course.parts.count) pages", systemImage: "book.pages")
                        Spacer()
                        Label("\(course.quiz.count) Q · \(course.duration)", systemImage: "clock")
                    }
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AcademyPalette.inkMuted)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AcademyPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(course.isFlagshipOnboarding ? AcademyPalette.pineBorder : AcademyPalette.border, lineWidth: course.isFlagshipOnboarding ? 1.4 : 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
    }
}
