import SwiftUI

// MARK: - Native Interactive Reader & Quiz for Hidden Cenelis Academy Course (guide-espace-client-v4)

public struct NativeClientGuideView: View {
    @Bindable var store: VemStoreViewModel
    public let isPresentedModally: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPartIndex: Int = 0
    @State private var showQuizMode: Bool = false
    @State private var showSimplerCard: Bool = false
    @State private var activeBubblePopup: VemGuideBubble?

    // Quiz State
    @State private var quizSelections: [Int: Int] = [:]
    @State private var quizSubmitted: Bool = false

    public init(store: VemStoreViewModel, isPresentedModally: Bool = true) {
        self.store = store
        self.isPresentedModally = isPresentedModally
    }

    public var body: some View {
        Group {
            if store.isLoadingGuide && store.customerGuide == nil {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Chargement du guide interactif Espace Client de A à Z…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let course = store.customerGuide {
                courseBody(course)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 34))
                        .foregroundStyle(VemTheme.warmCoral)
                    Text("Impossible de charger le cours client pour le moment.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Button("Réessayer") {
                        Task { await store.ensureCustomerGuideLoaded() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(32)
            }
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Guide Espace Client A–Z")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
        .task {
            await store.ensureCustomerGuideLoaded()
            if let first = store.customerGuide?.parts.first {
                store.markGuidePartRead(first.id)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { activeBubblePopup != nil },
                set: { if !$0 { activeBubblePopup = nil } }
            )
        ) {
            if let bubble = activeBubblePopup {
                BubbleExplanationPopupSheet(bubble: bubble)
            }
        }
    }

    @ViewBuilder
    private func courseBody(_ course: VemGuideCourse) -> some View {
        let totalParts = max(1, course.parts.count)
        let readCount = course.parts.filter { store.completedGuidePartIDs.contains($0.id) }.count
        let progressRatio = Double(readCount) / Double(totalParts)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Course Progress Hero
                VemAuroraBackgroundCard(cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(course.duration, systemImage: "clock.fill")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.18)))
                            Spacer()
                            if store.bestGuideQuizScorePct > 0 {
                                Label("Meilleur score : \(store.bestGuideQuizScorePct)%", systemImage: "trophy.fill")
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.solarAmber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.black.opacity(0.28)))
                            }
                        }

                        Text(course.title)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        if !course.subtitle.isEmpty {
                            Text(course.subtitle)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.white.opacity(0.88))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Progression : \(readCount)/\(course.parts.count) leçons explorées")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                Spacer()
                                Text("\(Int((progressRatio * 100).rounded()))%")
                                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                                    .foregroundStyle(VemTheme.vipleMint)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.2))
                                    Capsule()
                                        .fill(VemTheme.vipleMint)
                                        .frame(width: max(12, geo.size.width * progressRatio))
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                    .padding(18)
                }

                // 2. Lesson & Quiz Selector Strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(course.parts.enumerated()), id: \.element.id) { idx, part in
                            let isCurrent = !showQuizMode && selectedPartIndex == idx
                            let isDone = store.completedGuidePartIDs.contains(part.id)
                            Button {
                                VemHaptics.selection()
                                withAnimation(VemTheme.snappySpring) {
                                    showQuizMode = false
                                    showSimplerCard = false
                                    selectedPartIndex = idx
                                }
                                store.markGuidePartRead(part.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "\(idx + 1).circle.fill")
                                        .font(.system(size: 12.5, weight: .bold))
                                    Text("\(idx + 1). \(part.title)")
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8.5)
                                .foregroundStyle(isCurrent ? .white : .primary)
                                .background(
                                    Capsule()
                                        .fill(isCurrent ? AnyShapeStyle(VemTheme.vibrantActionGradient) : AnyShapeStyle(VemTheme.cardSurface))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isCurrent ? Color.clear : VemTheme.subtleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }

                        if !course.quiz.isEmpty {
                            Button {
                                VemHaptics.selection()
                                withAnimation(VemTheme.snappySpring) {
                                    showQuizMode = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Quiz Final (\(course.quiz.count))")
                                }
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8.5)
                                .foregroundStyle(showQuizMode ? .white : VemTheme.electricIndigo)
                                .background(
                                    Capsule()
                                        .fill(showQuizMode ? VemTheme.electricIndigo : VemTheme.electricIndigo.opacity(0.13))
                                )
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                }

                // 3. Active Lesson OR Final Interactive Quiz
                if showQuizMode {
                    interactiveQuizSection(course)
                } else if course.parts.indices.contains(selectedPartIndex) {
                    lessonPartView(course: course, part: course.parts[selectedPartIndex], index: selectedPartIndex)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Lesson Part Renderer

    @ViewBuilder
    private func lessonPartView(course: VemGuideCourse, part: VemGuidePart, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lesson Intro Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VemStatusPill("Étape \(index + 1) sur \(course.parts.count)", tone: .indigo)
                    VemStatusPill(part.duration, tone: .emerald, icon: "clock")
                    Spacer()
                }
                Text(part.title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                if !part.summary.isEmpty {
                    Text(cleanInlineMarkup(part.summary))
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
            }
            .vemCard()

            // Pedagogical Blocks
            ForEach(part.blocks) { block in
                GuideBlockRenderer(
                    block: block,
                    bubbles: store.guideBubbles,
                    onOpenBubble: { b in
                        VemHaptics.selection()
                        activeBubblePopup = b
                    }
                )
            }

            // "Expliquer plus simplement" Re-explain Card
            if let rx = part.reexplain, (!rx.simple.isEmpty || !rx.analogy.isEmpty) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            showSimplerCard.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb.max.fill")
                                .foregroundStyle(VemTheme.solarAmber)
                            Text("Un doute ? Expliquer encore plus simplement")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showSimplerCard ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showSimplerCard {
                        Divider()
                        if !rx.analogy.isEmpty {
                            Text("En image : \(cleanInlineMarkup(rx.analogy))")
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        if !rx.simple.isEmpty {
                            Text(cleanInlineMarkup(rx.simple))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        if let ex = rx.example, !ex.isEmpty {
                            Text("Exemple concret : \(cleanInlineMarkup(ex))")
                                .font(.system(size: 12.5))
                                .italic()
                                .foregroundStyle(VemTheme.vipleEmerald)
                        }
                        if let ess = rx.essential, !ess.isEmpty {
                            Text("À retenir : \(cleanInlineMarkup(ess))")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(VemTheme.electricIndigo)
                        }
                    }
                }
                .vemCard()
            }

            // Prev / Next Footer Navigation
            HStack(spacing: 12) {
                if index > 0 {
                    Button {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            selectedPartIndex = index - 1
                            showSimplerCard = false
                        }
                    } label: {
                        Label("Précédent", systemImage: "arrow.left")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(.primary)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.cardSurface))
                    }
                    .buttonStyle(VemPressableButtonStyle())
                }

                Button {
                    VemHaptics.impact(.light)
                    if index + 1 < course.parts.count {
                        let nextIdx = index + 1
                        store.markGuidePartRead(course.parts[nextIdx].id)
                        withAnimation(VemTheme.snappySpring) {
                            selectedPartIndex = nextIdx
                            showSimplerCard = false
                        }
                    } else {
                        withAnimation(VemTheme.snappySpring) {
                            showQuizMode = true
                        }
                    }
                } label: {
                    HStack {
                        Text(index + 1 < course.parts.count ? "Leçon suivante" : "Passer au Quiz Final")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13.5)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.vibrantActionGradient))
                }
                .buttonStyle(VemPressableButtonStyle())
            }
        }
    }

    // MARK: - Interactive Final Quiz

    @ViewBuilder
    private func interactiveQuizSection(_ course: VemGuideCourse) -> some View {
        let total = max(1, course.quiz.count)
        let correctCount = course.quiz.enumerated().filter { idx, q in
            quizSelections[idx] == q.answer
        }.count
        let pct = Int((Double(correctCount) / Double(total) * 100.0).rounded())

        VStack(alignment: .leading, spacing: 16) {
            if quizSubmitted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: pct >= course.passThresholdPct ? "checkmark.seal.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                        Text(pct >= course.passThresholdPct ? "Bravo ! Maîtrise validée (\(pct)%)" : "Score obtenu : \(pct)%")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(pct >= course.passThresholdPct ? VemTheme.vipleEmerald : VemTheme.warmCoral)

                    Text("Vous avez répondu juste à \(correctCount) question(s) sur \(course.quiz.count). Retrouvez ci-dessous l'explication claire de chaque point.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Button("Recommencer le quiz") {
                        withAnimation(VemTheme.snappySpring) {
                            quizSelections = [:]
                            quizSubmitted = false
                        }
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .vemCard()
            }

            ForEach(Array(course.quiz.enumerated()), id: \.offset) { qIdx, item in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Question \(qIdx + 1) · \(cleanInlineMarkup(item.q))")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))

                    ForEach(Array(item.options.enumerated()), id: \.offset) { optIdx, optText in
                        let isChosen = quizSelections[qIdx] == optIdx
                        let isCorrectAnswer = item.answer == optIdx

                        Button {
                            guard !quizSubmitted else { return }
                            VemHaptics.selection()
                            quizSelections[qIdx] = optIdx
                        } label: {
                            HStack(spacing: 10) {
                                Image(
                                    systemName: quizSubmitted
                                        ? (isCorrectAnswer ? "checkmark.circle.fill" : (isChosen ? "xmark.circle.fill" : "circle"))
                                        : (isChosen ? "largecircle.fill.circle" : "circle")
                                )
                                .foregroundStyle(
                                    quizSubmitted
                                        ? (isCorrectAnswer ? VemTheme.vipleEmerald : (isChosen ? VemTheme.warmCoral : .secondary))
                                        : (isChosen ? VemTheme.electricIndigo : .secondary)
                                )
                                Text(cleanInlineMarkup(optText))
                                    .font(.system(size: 13.5, weight: isChosen ? .bold : .medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(11)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        quizSubmitted && isCorrectAnswer
                                            ? VemTheme.vipleMint.opacity(0.15)
                                            : (isChosen ? VemTheme.electricIndigo.opacity(0.11) : VemTheme.elevatedSurface)
                                    )
                            )
                        }
                        .buttonStyle(VemPressableButtonStyle())
                    }

                    if quizSubmitted && !item.explain.isEmpty {
                        Text(cleanInlineMarkup(item.explain))
                            .font(.system(size: 12.5))
                            .foregroundStyle(VemTheme.vipleEmerald)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VemTheme.vipleMint.opacity(0.10)))
                    }
                }
                .vemCard()
            }

            if !quizSubmitted {
                Button {
                    guard quizSelections.count == course.quiz.count else {
                        store.showToast("Répondez aux \(course.quiz.count) questions avant de valider.", isError: true)
                        return
                    }
                    withAnimation(VemTheme.snappySpring) {
                        quizSubmitted = true
                    }
                    store.recordGuideQuizScore(pct)
                } label: {
                    Text("Valider mes réponses (\(quizSelections.count)/\(course.quiz.count))")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VemTheme.vibrantActionGradient))
                }
                .buttonStyle(VemPressableButtonStyle())
            }
        }
    }
}

// MARK: - Block Renderer Supporting All Cenelis Academy Customer Guide Blocks

private struct GuideBlockRenderer: View {
    let block: VemGuideBlock
    let bubbles: [String: VemGuideBubble]
    let onOpenBubble: (VemGuideBubble) -> Void

    private var extractedBubbleKeys: [(key: String, label: String)] {
        let joined = ([block.text ?? "", block.intro ?? ""] + block.paragraphs).joined(separator: " ")
        var found: [(String, String)] = []
        let pattern = #"\{\{bubble:([^|}]+)\|([^}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = joined as NSString
            for match in regex.matches(in: joined, range: NSRange(location: 0, length: ns.length)) {
                if match.numberOfRanges >= 3 {
                    let k = ns.substring(with: match.range(at: 1))
                    let lbl = ns.substring(with: match.range(at: 2))
                    if !found.contains(where: { $0.0 == k }) {
                        found.append((k, lbl))
                    }
                }
            }
        }
        return found
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading ?? block.title, !heading.isEmpty {
                Text(cleanInlineMarkup(heading))
                    .font(.system(size: 16.5, weight: .heavy, design: .rounded))
            }

            if let intro = block.intro, !intro.isEmpty {
                Text(cleanInlineMarkup(intro))
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }

            if let text = block.text, !text.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(VemTheme.vipleEmerald)
                    Text(cleanInlineMarkup(text))
                        .font(.system(size: 13.5, weight: .medium))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.vipleMint.opacity(0.12)))
            }

            ForEach(block.paragraphs, id: \.self) { p in
                Text(cleanInlineMarkup(p))
                    .font(.system(size: 14))
                    .lineSpacing(3)
            }

            // Interactive Glossary Bubble Pills Detected in Paragraphs
            if !extractedBubbleKeys.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(extractedBubbleKeys, id: \.key) { pair in
                            if let b = bubbles[pair.key] {
                                Button {
                                    onOpenBubble(b)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "questionmark.bubble.fill")
                                        Text("C'est quoi « \(pair.label) » ?")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.electricIndigo)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6.5)
                                    .background(Capsule().fill(VemTheme.electricIndigo.opacity(0.12)))
                                }
                                .buttonStyle(VemPressableButtonStyle())
                            }
                        }
                    }
                }
            }

            // Terms Cards
            ForEach(block.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleanInlineMarkup(item.term))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(VemTheme.vipleEmerald)
                    Text(cleanInlineMarkup(item.plain))
                        .font(.system(size: 13))
                    if let why = item.why, !why.isEmpty {
                        Text("Pourquoi : \(cleanInlineMarkup(why))")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(VemTheme.elevatedSurface))
            }

            // UI Buttons Guide
            ForEach(block.buttons) { btn in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VemStatusPill(btn.label, tone: .indigo, icon: "hand.tap.fill")
                        Spacer()
                        Text(btn.location)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(cleanInlineMarkup(btn.plainDesc))
                        .font(.system(size: 13))
                        .padding(.top, 2)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(VemTheme.elevatedSurface))
            }

            // Real-Life Scenarios
            ForEach(block.cases) { sc in
                VStack(alignment: .leading, spacing: 5) {
                    Text(sc.who)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(VemTheme.warmCoral)
                    Text(cleanInlineMarkup(sc.situation))
                        .font(.system(size: 13, weight: .semibold))
                    Text("Solution : \(cleanInlineMarkup(sc.solution))")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(VemTheme.elevatedSurface))
            }

            // Visual Flow Steps
            if !block.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(block.steps.enumerated()), id: \.element.id) { sIdx, step in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(VemTheme.vipleEmerald)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("\(sIdx + 1)")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cleanInlineMarkup(step.label))
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                if !step.sub.isEmpty {
                                    Text(cleanInlineMarkup(step.sub))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Annotated Screenshot Preview
            if let src = block.src, !src.isEmpty {
                let fullImgURL = src.hasPrefix("http")
                    ? URL(string: src)
                    : URL(string: "https://academy.prod.cenelis.com\(src.hasPrefix("/") ? "" : "/")\(src)")
                if let fullImgURL {
                    AsyncImage(url: fullImgURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        default:
                            EmptyView()
                        }
                    }
                }
                if let cap = block.caption, !cap.isEmpty {
                    Text(cleanInlineMarkup(cap))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .vemCard()
    }
}

private struct BubbleExplanationPopupSheet: View {
    let bubble: VemGuideBubble
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VemStatusPill("Explication sans jargon", tone: .indigo, icon: "sparkles")
                Text(bubble.term)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(bubble.plain)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                if let ex = bubble.example, !ex.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXEMPLE CONCRET")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(VemTheme.vipleEmerald)
                        Text(ex)
                            .font(.system(size: 13.5))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.vipleMint.opacity(0.13)))
                }
                Spacer()
            }
            .padding(22)
            .background(VemTheme.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compris !") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private func cleanInlineMarkup(_ raw: String) -> String {
    var s = raw
    // Replace {{bubble:key|label}} with « label »
    if let regex = try? NSRegularExpression(pattern: #"\{\{bubble:[^|}]+\|([^}]+)\}\}"#) {
        let ns = s as NSString
        s = regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "$1")
    }
    // Strip basic HTML tags if any exist in prose
    if let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
        let ns = s as NSString
        s = tagRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "")
    }
    return s
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
}
