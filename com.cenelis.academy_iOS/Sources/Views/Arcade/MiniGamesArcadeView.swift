import SwiftUI

// MARK: - Arcade Pédagogique Cenelis Academy (5 Mini-Jeux Natifs Générés depuis les Cours Appris)

public struct MiniGamesArcadeView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var studyScope: MiniGameStudyScope = .learnedFirst
    @State private var activeGame: MiniGameKind? = nil

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    arcadeHeroHeader

                    // Sélecteur de source des questions : Sur mes cours appris vs Tout Cenelis
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SOURCE DES DÉFIS DYNAMIQUES")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.inkSecondary)

                        Picker("Périmètre des mini-jeux", selection: $studyScope) {
                            ForEach(MiniGameStudyScope.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: studyScope) { _, _ in AcademyHaptics.selection() }
                    }

                    // Grille des 5 Mini-Jeux Natifs
                    ForEach(MiniGameKind.allCases) { game in
                        miniGameCard(game)
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Arcade & Mini-Jeux")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.isShowingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AcademyPalette.pine)
                    }
                }
            }
            .fullScreenCover(item: $activeGame) { game in
                MiniGameSessionContainer(kind: game, scope: studyScope, vm: vm)
            }
        }
    }

    private var arcadeHeroHeader: some View {
        let totalPlays = vm.progress.miniGameRecords.values.reduce(0) { $0 + $1.plays }
        let learnedCount = vm.progress.completedParts.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                AcademyBadge("Ancrage mémoriel ludique", icon: "gamecontroller.fill", style: .gold)
                Spacer()
                Text("\(totalPlays) manche(s) jouée(s)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text("Apprendre en jouant sur vos vrais cours")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(learnedCount > 0
                 ? "Vos mini-jeux puisent en priorité dans vos \(learnedCount) page(s) déjà assimilées pour transformer la théorie en réflexes naturels."
                 : "Chaque manche génère ses cartes en direct depuis les parcours officiels Cenelis, Viple, Livria et Looby.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AcademyPalette.heroGradient)
        )
    }

    private func miniGameCard(_ kind: MiniGameKind) -> some View {
        let rec = vm.progress.miniGameRecords[kind.rawValue]

        return Button {
            AcademyHaptics.medium()
            activeGame = kind
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AcademyPalette.pineSoft)
                            .frame(width: 54, height: 54)
                        Image(systemName: kind.sfSymbol)
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(AcademyPalette.pine)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(kind.durationBadge)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.copper)
                            Spacer()
                            AcademyBadge("+\(kind.baseXPReward) XP", icon: "sparkles", style: .pine)
                        }
                        Text(kind.title)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                            .multilineTextAlignment(.leading)
                        Text(kind.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                HStack {
                    if let rec, rec.plays > 0 {
                        Label("Record : \(rec.highScore) pts · Combo max : \(rec.bestStreak)", systemImage: "trophy.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.copper)
                    } else {
                        Label("Nouveau défi prêt à lancer", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                    }
                    Spacer()
                    Text("Jouer")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AcademyPalette.pineSolid))
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AcademyPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AcademyPalette.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            )
        }
        .buttonStyle(SpringPressableButtonStyle())
    }
}

// MARK: - Conteneur de Session Mini-Jeu Plein Écran

private struct MiniGameSessionContainer: View {
    let kind: MiniGameKind
    let scope: MiniGameStudyScope
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch kind {
                case .swipeBlitz:
                    SwipeBlitzGameView(scope: scope, vm: vm, onFinish: { dismiss() })
                case .memoryMatch:
                    MemoryMatchGameView(vm: vm, onFinish: { dismiss() })
                case .roleShift:
                    RoleShiftGameView(scope: scope, vm: vm, onFinish: { dismiss() })
                case .screenshotDetective:
                    ScreenshotDetectiveGameView(scope: scope, vm: vm, onFinish: { dismiss() })
                case .orderFlow:
                    OrderFlowGameView(scope: scope, vm: vm, onFinish: { dismiss() })
                }
            }
            .background(AcademyPalette.background.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quitter") {
                        AcademyHaptics.light()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AcademyPalette.pine)
                }
            }
        }
    }
}

// MARK: - Jeu 1 : Swipe Éclair « Vrai ou Piège ? » (Physique Ressort & Multiplicateur Combo)

private struct SwipeBlitzGameView: View {
    let scope: MiniGameStudyScope
    @ObservedObject var vm: AcademyStoreViewModel
    let onFinish: () -> Void

    @State private var deck: [SwipeBlitzItem] = []
    @State private var index: Int = 0
    @State private var drag: CGSize = .zero
    @State private var score: Int = 0
    @State private var combo: Int = 0
    @State private var maxCombo: Int = 0
    @State private var correctCount: Int = 0
    @State private var lastFeedback: (ok: Bool, text: String)? = nil
    @State private var finished: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            if finished {
                MiniGameSummaryView(
                    title: "Manche Swipe Éclair terminée !",
                    score: score,
                    accuracyPct: deck.isEmpty ? 100 : Int((Double(correctCount) / Double(deck.count) * 100).rounded()),
                    maxCombo: maxCombo,
                    onReplay: startNewDeck,
                    onClose: onFinish
                )
            } else if deck.indices.contains(index) {
                let item = deck[index]

                // Barre de score & combo
                HStack {
                    AcademyBadge("Carte \(index + 1)/\(deck.count)", style: .pine)
                    Spacer()
                    if combo >= 2 {
                        AcademyBadge("Combo ×\(combo) 🔥", style: .copper)
                    }
                    Text("\(score) pts")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.pine)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()

                // Carte physique glissable
                ZStack {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            AcademyBadge(item.sourceCourseTitle, icon: "graduationcap.fill", style: .muted)
                            Spacer()
                            Text(item.topic)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.copper)
                        }

                        Text(item.statement)
                            .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                            .lineSpacing(4)

                        Spacer(minLength: 8)

                        HStack {
                            Label("← Glisser : PIÈGE", systemImage: "xmark.circle.fill")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.danger)
                            Spacer()
                            Label("RÉFLEXE : Glisser →", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.success)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(AcademyPalette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .strokeBorder(
                                        drag.width > 35 ? AcademyPalette.success : (drag.width < -35 ? AcademyPalette.danger : AcademyPalette.border),
                                        lineWidth: abs(drag.width) > 35 ? 2.5 : 1.2
                                    )
                            )
                            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                    )
                    .offset(x: drag.width, y: drag.height * 0.25)
                    .rotationEffect(.degrees(Double(drag.width / 15)))
                    .gesture(
                        DragGesture()
                            .onChanged { val in drag = val.translation }
                            .onEnded { val in
                                if val.translation.width > 85 {
                                    answerCard(believesTrue: true)
                                } else if val.translation.width < -85 {
                                    answerCard(believesTrue: false)
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                        drag = .zero
                                    }
                                }
                            }
                    )
                }
                .padding(.horizontal, 18)

                if let fb = lastFeedback {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: fb.ok ? "checkmark.seal.fill" : "lightbulb.fill")
                            .foregroundStyle(fb.ok ? AcademyPalette.success : AcademyPalette.copper)
                        Text(fb.text)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AcademyPalette.ink)
                            .lineLimit(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(fb.ok ? AcademyPalette.successSoft : AcademyPalette.copperSoft))
                    .padding(.horizontal, 18)
                }

                Spacer()

                // Boutons tactiles rapides au pouce
                HStack(spacing: 16) {
                    Button {
                        answerCard(believesTrue: false)
                    } label: {
                        Label("Piège", systemImage: "xmark")
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(AcademyPalette.copperSolid))
                    }
                    .buttonStyle(SpringPressableButtonStyle())

                    Button {
                        answerCard(believesTrue: true)
                    } label: {
                        Label("Vrai Réflexe", systemImage: "checkmark")
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(AcademyPalette.pineSolid))
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            } else {
                ProgressView("Préparation des cartes…")
            }
        }
        .onAppear(perform: startNewDeck)
    }

    private func startNewDeck() {
        deck = AcademyMiniGameDeckBuilder.buildSwipeDeck(from: vm.catalog, progress: vm.progress, scope: scope, count: 10)
        index = 0
        score = 0
        combo = 0
        maxCombo = 0
        correctCount = 0
        lastFeedback = nil
        finished = false
        drag = .zero
    }

    private func answerCard(believesTrue: Bool) {
        guard deck.indices.contains(index) else { return }
        let current = deck[index]
        let isCorrect = (believesTrue == current.isTrue)

        if isCorrect {
            AcademyHaptics.success()
            combo += 1
            maxCombo = max(maxCombo, combo)
            correctCount += 1
            score += 100 + (combo * 20)
        } else {
            AcademyHaptics.error()
            combo = 0
        }

        lastFeedback = (isCorrect, current.explanation)
        drag = .zero

        if index + 1 < deck.count {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                index += 1
            }
        } else {
            let acc = Int((Double(correctCount) / Double(max(1, deck.count)) * 100).rounded())
            vm.recordMiniGameCompletion(kind: .swipeBlitz, score: score, maxCombo: maxCombo, accuracyPct: acc)
            withAnimation(.spring()) { finished = true }
        }
    }
}

// MARK: - Jeu 2 : Duel des Connexions 3D (Memory Pédagogique Termes <-> Analogies)

private struct MemoryMatchGameView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    let onFinish: () -> Void

    private struct CardTile: Identifiable {
        let id = UUID()
        let pairId: String
        let isTerm: Bool
        let text: String
    }

    @State private var tiles: [CardTile] = []
    @State private var flippedIds: [UUID] = []
    @State private var matchedPairIds: Set<String> = []
    @State private var moves: Int = 0
    @State private var isLocked: Bool = false
    @State private var finished: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            if finished {
                let score = max(250, 900 - moves * 35)
                MiniGameSummaryView(
                    title: "Toutes les paires sont reliées !",
                    score: score,
                    accuracyPct: min(100, max(55, 130 - moves * 5)),
                    maxCombo: matchedPairIds.count,
                    onReplay: setupBoard,
                    onClose: onFinish
                )
            } else {
                HStack {
                    AcademyBadge("\(matchedPairIds.count)/6 paires trouvées", style: .pine)
                    Spacer()
                    Text("\(moves) coups")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(tiles) { tile in
                        let isMatched = matchedPairIds.contains(tile.pairId)
                        let isFaceUp = isMatched || flippedIds.contains(tile.id)

                        Button {
                            tapTile(tile)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isMatched ? AcademyPalette.successSoft : (isFaceUp ? AcademyPalette.surface : AcademyPalette.pineSolid))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(isMatched ? AcademyPalette.success : AcademyPalette.pineBorder, lineWidth: 1.3)
                                    )

                                if isFaceUp {
                                    VStack(spacing: 4) {
                                        Text(tile.isTerm ? "CONCEPT" : "EN CLAIR")
                                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                            .foregroundStyle(tile.isTerm ? AcademyPalette.pine : AcademyPalette.copper)
                                        Text(tile.text)
                                            .font(.system(size: tile.isTerm ? 12 : 10.5, weight: tile.isTerm ? .heavy : .semibold, design: .rounded))
                                            .foregroundStyle(AcademyPalette.ink)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(5)
                                            .minimumScaleFactor(0.75)
                                    }
                                    .padding(7)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(AcademyPalette.gold)
                                }
                            }
                            .frame(height: 112)
                            .rotation3DEffect(.degrees(isFaceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isFaceUp)
                        }
                        .buttonStyle(.plain)
                        .disabled(isFaceUp || isLocked)
                    }
                }
                .padding(.horizontal, 14)

                Spacer()
            }
        }
        .onAppear(perform: setupBoard)
    }

    private func setupBoard() {
        let pairs = AcademyMiniGameDeckBuilder.buildMemoryPairs(from: vm.catalog, progress: vm.progress, count: 6)
        var built: [CardTile] = []
        for p in pairs {
            built.append(CardTile(pairId: p.id, isTerm: true, text: p.term))
            built.append(CardTile(pairId: p.id, isTerm: false, text: p.definition))
        }
        tiles = built.shuffled()
        flippedIds = []
        matchedPairIds = []
        moves = 0
        isLocked = false
        finished = false
    }

    private func tapTile(_ tile: CardTile) {
        guard !isLocked else { return }
        AcademyHaptics.selection()
        flippedIds.append(tile.id)

        guard flippedIds.count == 2,
              let first = tiles.first(where: { $0.id == flippedIds[0] }),
              let second = tiles.first(where: { $0.id == flippedIds[1] }) else {
            return
        }

        moves += 1
        if first.pairId == second.pairId {
            AcademyHaptics.success()
            matchedPairIds.insert(first.pairId)
            flippedIds = []
            if matchedPairIds.count == tiles.count / 2 {
                let finalScore = max(250, 900 - moves * 35)
                let acc = min(100, max(60, 130 - moves * 5))
                vm.recordMiniGameCompletion(kind: .memoryMatch, score: finalScore, maxCombo: matchedPairIds.count, accuracyPct: acc)
                withAnimation(.spring()) { finished = true }
            }
        } else {
            isLocked = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 850_000_000)
                flippedIds = []
                isLocked = false
            }
        }
    }
}

// MARK: - Jeu 3 : Urgence au Poste ! (Simulation Métier en Direct)

private struct RoleShiftGameView: View {
    let scope: MiniGameStudyScope
    @ObservedObject var vm: AcademyStoreViewModel
    let onFinish: () -> Void

    @State private var scenarios: [RoleShiftScenario] = []
    @State private var idx: Int = 0
    @State private var pickedOption: Int? = nil
    @State private var score: Int = 0
    @State private var correctCount: Int = 0
    @State private var finished: Bool = false

    var body: some View {
        ScrollView {
            if finished {
                MiniGameSummaryView(
                    title: "Service terminé avec brio !",
                    score: score,
                    accuracyPct: scenarios.isEmpty ? 100 : Int((Double(correctCount) / Double(scenarios.count) * 100).rounded()),
                    maxCombo: correctCount,
                    onReplay: startShift,
                    onClose: onFinish
                )
            } else if scenarios.indices.contains(idx) {
                let sc = scenarios[idx]
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        AcademyBadge("Alerte \(idx + 1)/\(scenarios.count)", icon: "bell.badge.fill", style: .copper)
                        Spacer()
                        Text("\(score) pts")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(sc.roleBadge.uppercased())
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.gold)
                        Text(sc.incomingAlert)
                            .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.heroGradient))

                    ForEach(Array(sc.options.enumerated()), id: \.offset) { optIdx, opt in
                        let isChosen = (pickedOption == optIdx)
                        let isRight = (optIdx == sc.correctIndex)
                        Button {
                            guard pickedOption == nil else { return }
                            pickedOption = optIdx
                            if isRight {
                                AcademyHaptics.success()
                                correctCount += 1
                                score += 160
                            } else {
                                AcademyHaptics.error()
                            }
                        } label: {
                            HStack {
                                Text(opt)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if pickedOption != nil && (isRight || isChosen) {
                                    Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(isRight ? AcademyPalette.success : AcademyPalette.danger)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(pickedOption != nil && isRight ? AcademyPalette.successSoft : (isChosen ? AcademyPalette.dangerSoft : AcademyPalette.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(AcademyPalette.border, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if pickedOption != nil {
                        Text(sc.coachingNote)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(AcademyPalette.ink)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.pineSoft))

                        Button {
                            if idx + 1 < scenarios.count {
                                pickedOption = nil
                                idx += 1
                            } else {
                                let acc = Int((Double(correctCount) / Double(max(1, scenarios.count)) * 100).rounded())
                                vm.recordMiniGameCompletion(kind: .roleShift, score: score, maxCombo: correctCount, accuracyPct: acc)
                                finished = true
                            }
                        } label: {
                            Text(idx + 1 < scenarios.count ? "Urgence suivante →" : "Voir mon bilan")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.pineSolid))
                        }
                    }
                }
                .padding(16)
            }
        }
        .onAppear(perform: startShift)
    }

    private func startShift() {
        scenarios = AcademyMiniGameDeckBuilder.buildRoleShiftScenarios(from: vm.catalog, progress: vm.progress, scope: scope, count: 6)
        idx = 0
        pickedOption = nil
        score = 0
        correctCount = 0
        finished = false
    }
}

// MARK: - Jeu 4 : Œil d'Expert Interface (Identification de Vraies Captures @2x)

private struct ScreenshotDetectiveGameView: View {
    let scope: MiniGameStudyScope
    @ObservedObject var vm: AcademyStoreViewModel
    let onFinish: () -> Void

    @State private var challenges: [ScreenshotDetectiveChallenge] = []
    @State private var idx: Int = 0
    @State private var picked: Int? = nil
    @State private var score: Int = 0
    @State private var correctCount: Int = 0
    @State private var finished: Bool = false

    var body: some View {
        ScrollView {
            if finished {
                MiniGameSummaryView(
                    title: "Œil d'Expert validé !",
                    score: score,
                    accuracyPct: challenges.isEmpty ? 100 : Int((Double(correctCount) / Double(challenges.count) * 100).rounded()),
                    maxCombo: correctCount,
                    onReplay: startGame,
                    onClose: onFinish
                )
            } else if challenges.indices.contains(idx) {
                let ch = challenges[idx]
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        AcademyBadge("Capture \(idx + 1)/\(challenges.count)", icon: "viewfinder", style: .pine)
                        Spacer()
                        Text("\(score) pts")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                    }

                    CachedAcademyImage(path: ch.imagePath, contentMode: .fit, cornerRadius: 16, minPlaceholderHeight: 190)

                    Text(ch.prompt)
                        .font(.system(size: 15.5, weight: .heavy, design: .rounded))

                    ForEach(Array(ch.options.enumerated()), id: \.offset) { optIdx, opt in
                        let isRight = (optIdx == ch.correctIndex)
                        let isSelected = (picked == optIdx)
                        Button {
                            guard picked == nil else { return }
                            picked = optIdx
                            if isRight {
                                AcademyHaptics.success()
                                correctCount += 1
                                score += 150
                            } else {
                                AcademyHaptics.error()
                            }
                        } label: {
                            HStack {
                                Text(opt)
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if picked != nil && (isRight || isSelected) {
                                    Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(isRight ? AcademyPalette.success : AcademyPalette.danger)
                                }
                            }
                            .padding(13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(picked != nil && isRight ? AcademyPalette.successSoft : AcademyPalette.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AcademyPalette.border, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if picked != nil {
                        if !ch.captionHint.isEmpty {
                            Text(ch.captionHint)
                                .font(.system(size: 12.5))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                        }

                        Button {
                            if idx + 1 < challenges.count {
                                picked = nil
                                idx += 1
                            } else {
                                let acc = Int((Double(correctCount) / Double(max(1, challenges.count)) * 100).rounded())
                                vm.recordMiniGameCompletion(kind: .screenshotDetective, score: score, maxCombo: correctCount, accuracyPct: acc)
                                finished = true
                            }
                        } label: {
                            Text(idx + 1 < challenges.count ? "Capture suivante →" : "Terminer la manche")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.pineSolid))
                        }
                    }
                }
                .padding(16)
            }
        }
        .onAppear(perform: startGame)
    }

    private func startGame() {
        challenges = AcademyMiniGameDeckBuilder.buildScreenshotChallenges(from: vm.catalog, progress: vm.progress, scope: scope, count: 5)
        idx = 0
        picked = nil
        score = 0
        correctCount = 0
        finished = false
    }
}

// MARK: - Jeu 5 : Séquences Maîtrisées (Remise dans l'Ordre des Procédures Cenelis)

private struct OrderFlowGameView: View {
    let scope: MiniGameStudyScope
    @ObservedObject var vm: AcademyStoreViewModel
    let onFinish: () -> Void

    @State private var puzzles: [OrderFlowPuzzle] = []
    @State private var idx: Int = 0
    @State private var poolSteps: [String] = []
    @State private var chosenOrder: [String] = []
    @State private var isChecked: Bool = false
    @State private var isCurrentRight: Bool = false
    @State private var score: Int = 0
    @State private var correctCount: Int = 0
    @State private var finished: Bool = false

    var body: some View {
        ScrollView {
            if finished {
                MiniGameSummaryView(
                    title: "Séquences Cenelis maîtrisées !",
                    score: score,
                    accuracyPct: puzzles.isEmpty ? 100 : Int((Double(correctCount) / Double(puzzles.count) * 100).rounded()),
                    maxCombo: correctCount,
                    onReplay: startPuzzles,
                    onClose: onFinish
                )
            } else if puzzles.indices.contains(idx) {
                let p = puzzles[idx]
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        AcademyBadge("Séquence \(idx + 1)/\(puzzles.count)", style: .copper)
                        Spacer()
                        Text("\(score) pts")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                    }

                    Text(p.sourceTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                    Text("Touchez les propositions dans l'ordre chronologique exact (de l'étape 1 à la dernière) :")
                        .font(.system(size: 13))
                        .foregroundStyle(AcademyPalette.inkSecondary)

                    // Étapes déjà placées
                    VStack(spacing: 8) {
                        ForEach(Array(chosenOrder.enumerated()), id: \.offset) { pos, stepText in
                            Button {
                                guard !isChecked else { return }
                                AcademyHaptics.selection()
                                chosenOrder.remove(at: pos)
                                poolSteps.append(stepText)
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(pos + 1)")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(AcademyPalette.pineSolid))
                                    Text(stepText)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AcademyPalette.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(11)
                                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.pineSoft))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Propositions restantes
                    if !poolSteps.isEmpty {
                        Divider()
                        ForEach(Array(poolSteps.enumerated()), id: \.offset) { pIdx, stepText in
                            Button {
                                AcademyHaptics.selection()
                                poolSteps.remove(at: pIdx)
                                chosenOrder.append(stepText)
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AcademyPalette.copper)
                                    Text(stepText)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AcademyPalette.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(11)
                                .background(RoundedRectangle(cornerRadius: 13).fill(AcademyPalette.surface))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if poolSteps.isEmpty && !isChecked {
                        Button {
                            isChecked = true
                            isCurrentRight = (chosenOrder == p.orderedSteps)
                            if isCurrentRight {
                                AcademyHaptics.success()
                                correctCount += 1
                                score += 180
                            } else {
                                AcademyHaptics.warning()
                                chosenOrder = p.orderedSteps
                            }
                        } label: {
                            Text("Vérifier l'ordre")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.pineSolid))
                        }
                    }

                    if isChecked {
                        Text(isCurrentRight
                             ? "Ordre parfait du premier coup !"
                             : "Voici l'ordre officiel exact affiché ci-dessus pour bien le mémoriser.")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(isCurrentRight ? AcademyPalette.success : AcademyPalette.copper)

                        Button {
                            if idx + 1 < puzzles.count {
                                idx += 1
                                loadPuzzle(at: idx)
                            } else {
                                let acc = Int((Double(correctCount) / Double(max(1, puzzles.count)) * 100).rounded())
                                vm.recordMiniGameCompletion(kind: .orderFlow, score: score, maxCombo: correctCount, accuracyPct: acc)
                                finished = true
                            }
                        } label: {
                            Text(idx + 1 < puzzles.count ? "Séquence suivante →" : "Valider ma manche")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.copperGradient))
                        }
                    }
                }
                .padding(16)
            }
        }
        .onAppear(perform: startPuzzles)
    }

    private func startPuzzles() {
        puzzles = AcademyMiniGameDeckBuilder.buildOrderFlowPuzzles(from: vm.catalog, progress: vm.progress, scope: scope, count: 4)
        idx = 0
        score = 0
        correctCount = 0
        finished = false
        loadPuzzle(at: 0)
    }

    private func loadPuzzle(at i: Int) {
        guard puzzles.indices.contains(i) else { return }
        chosenOrder = []
        var shuf = puzzles[i].orderedSteps.shuffled()
        if shuf == puzzles[i].orderedSteps && shuf.count > 1 {
            shuf.swapAt(0, 1)
        }
        poolSteps = shuf
        isChecked = false
        isCurrentRight = false
    }
}

// MARK: - Écran de Bilan Célébratoire Commun aux 5 Mini-Jeux

private struct MiniGameSummaryView: View {
    let title: String
    let score: Int
    let accuracyPct: Int
    let maxCombo: Int
    let onReplay: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            AnimatedMasteryRing(
                progress: Double(accuracyPct) / 100.0,
                size: 110,
                lineWidth: 10,
                tint: accuracyPct >= 80 ? AcademyPalette.gold : AcademyPalette.pine,
                centerText: "\(accuracyPct)%"
            )

            Text(title)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.pine)
                    Text("Score")
                        .font(.system(size: 12))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                VStack {
                    Text("×\(max(1, maxCombo))")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)
                    Text("Série")
                        .font(.system(size: 12))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.surface))

            HStack(spacing: 12) {
                Button {
                    AcademyHaptics.medium()
                    onReplay()
                } label: {
                    Label("Rejouer", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.pineSoft))
                        .foregroundStyle(AcademyPalette.pine)
                }

                Button {
                    AcademyHaptics.selection()
                    onClose()
                } label: {
                    Text("Retour à l'Arcade")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.pineSolid))
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .padding(20)
    }
}
