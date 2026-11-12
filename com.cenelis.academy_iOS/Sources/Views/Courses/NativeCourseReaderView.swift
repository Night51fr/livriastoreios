import SwiftUI

// MARK: - Lecteur de Cours 100 % Natif SwiftUI (Mode Fluide + Mode Cartes Focus + Captures @2x Annotées)

public struct NativeCourseReaderView: View {
    public let course: AcademyCourse
    @ObservedObject var vm: AcademyStoreViewModel

    @State private var isShowingToc: Bool = false
    @State private var isReexplainExpanded: Bool = false
    @State private var focusBlockIndex: Int = 0

    public init(course: AcademyCourse, vm: AcademyStoreViewModel) {
        self.course = course
        self.vm = vm
    }

    private var isOnEvaluationStep: Bool {
        vm.activeStepIndex >= course.parts.count
    }

    private var currentPart: AcademyPart? {
        guard course.parts.indices.contains(vm.activeStepIndex) else { return nil }
        return course.parts[vm.activeStepIndex]
    }

    private var currentChapter: AcademyChapter? {
        guard !isOnEvaluationStep else { return nil }
        if let chId = currentPart?.chapter,
           let match = course.chapters.first(where: { $0.id == chId }) {
            return match
        }
        return course.chapters.first(where: { vm.activeStepIndex >= $0.startIndex && vm.activeStepIndex <= $0.endIndex })
    }

    public var body: some View {
        VStack(spacing: 0) {
            readerTopHeader
            progressBarStrip

            if isOnEvaluationStep {
                CourseEvaluationView(course: course, vm: vm)
            } else if let part = currentPart {
                if vm.readerStyle == .fluid {
                    fluidPageScrollView(part: part)
                } else {
                    focusDeckPageView(part: part)
                }
                readerBottomBar(part: part)
            }
        }
        .background(AcademyPalette.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingToc) {
            CourseTocSheet(course: course, vm: vm)
        }
        .onChange(of: vm.activeStepIndex) { _, _ in
            isReexplainExpanded = false
            focusBlockIndex = 0
        }
    }

    // MARK: - Barre Supérieure Compacte & Intuitive

    private var readerTopHeader: some View {
        HStack(spacing: 10) {
            Button {
                vm.closeCourseReader()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AcademyPalette.inkSecondary)
            }

            Button {
                AcademyHaptics.selection()
                isShowingToc = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 12.5, weight: .bold))
                    Text(isOnEvaluationStep
                         ? "Évaluation Finale"
                         : "Page \(vm.activeStepIndex + 1)/\(course.parts.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(AcademyPalette.pine)
                .background(Capsule().fill(AcademyPalette.pineSoft))
            }
            .buttonStyle(SpringPressableButtonStyle())

            Spacer()

            if !isOnEvaluationStep {
                // Bascule Mode Lecture Fluide / Cartes Focus
                Button {
                    AcademyHaptics.selection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        vm.readerStyle = (vm.readerStyle == .fluid) ? .focusDeck : .fluid
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: vm.readerStyle.sfSymbol)
                            .font(.system(size: 12, weight: .bold))
                        Text(vm.readerStyle == .fluid ? "Fluide" : "Focus")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6.5)
                    .background(Capsule().fill(AcademyPalette.surfaceSubtle))
                    .foregroundStyle(AcademyPalette.ink)
                }

                // Bascule Captures Mobile / PC
                Button {
                    AcademyHaptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.shotDeviceMode = (vm.shotDeviceMode == .mobile) ? .pc : .mobile
                    }
                } label: {
                    Image(systemName: vm.shotDeviceMode.sfSymbol)
                        .font(.system(size: 13.5, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AcademyPalette.copperSoft))
                        .foregroundStyle(AcademyPalette.copper)
                }

                if let part = currentPart {
                    Button {
                        vm.toggleBookmark(part.id)
                    } label: {
                        Image(systemName: vm.isPartBookmarked(part.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13.5, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(AcademyPalette.surfaceSubtle))
                            .foregroundStyle(vm.isPartBookmarked(part.id) ? AcademyPalette.copper : AcademyPalette.inkSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AcademyPalette.surface)
    }

    private var progressBarStrip: some View {
        let totalSteps = max(1, course.parts.count + 1)
        let frac = Double(min(vm.activeStepIndex + 1, totalSteps)) / Double(totalSteps)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AcademyPalette.pineSoft)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AcademyPalette.pineSolid, AcademyPalette.copperSolid],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * frac)
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.activeStepIndex)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Mode 1 : Lecture Fluide Éditoriale

    private func fluidPageScrollView(part: AcademyPart) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 1).id("PAGE_TOP")

                    if !course.roleShortcuts.isEmpty && vm.activeStepIndex == 0 {
                        roleShortcutsBanner
                    }

                    pageHeroCard(part: part)

                    ForEach(part.blocks) { block in
                        NativeBlockRendererView(block: block, vm: vm)
                    }

                    pedagogicalSupportSection(part: part)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
            .onChange(of: vm.activeStepIndex) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("PAGE_TOP", anchor: .top)
                }
            }
        }
    }

    // MARK: - Mode 2 : Cartes Focus (Swipe Deck Bloc par Bloc, Ultra-Intuitif Mobile)

    private func focusDeckPageView(part: AcademyPart) -> some View {
        let totalCards = max(1, part.blocks.count)
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let ch = currentChapter {
                        Text("CHAPITRE \(ch.id) · \(ch.title.uppercased())")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.copper)
                            .lineLimit(1)
                    }
                    Text(part.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)
                        .lineLimit(2)
                }
                Spacer()
                AcademyBadge("Carte \(min(focusBlockIndex + 1, totalCards))/\(totalCards)", icon: "rectangle.stack.fill", style: .copper)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            TabView(selection: $focusBlockIndex) {
                ForEach(Array(part.blocks.enumerated()), id: \.offset) { idx, block in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            NativeBlockRendererView(block: block, vm: vm)
                            if idx == part.blocks.count - 1 {
                                pedagogicalSupportSection(part: part)
                            }
                        }
                        .padding(16)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    // MARK: - Raccourcis par Poste & En-tête de Page

    private var roleShortcutsBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundStyle(AcademyPalette.copper)
                Text(course.shortcutBannerTitle ?? "Accès direct à votre poste chez Cenelis")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(course.roleShortcuts) { sc in
                        Button {
                            AcademyHaptics.medium()
                            vm.setStepIndex(sc.startIndex, for: course)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: AcademyIcons.sfSymbol(for: sc.icon))
                                    .font(.system(size: 12, weight: .bold))
                                Text(sc.label)
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AcademyPalette.pineSolid))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AcademyPalette.copperSoft)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.copperBorder, lineWidth: 1))
        )
    }

    private func pageHeroCard(part: AcademyPart) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let ch = currentChapter {
                    AcademyBadge("Chapitre \(ch.id) · \(ch.title)", icon: AcademyIcons.sfSymbol(for: ch.icon), style: .pine)
                }
                Spacer()
                Label(part.duration, systemImage: "clock")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AcademyPalette.inkSecondary)
            }

            Text(part.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)

            if !part.summary.isEmpty {
                Text(AcademyRichTextParser.plainText(part.summary))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(AcademyPalette.inkSecondary)
                    .lineSpacing(3)
            }

            if vm.isPartCompleted(part.id) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AcademyPalette.success)
                    Text("Page déjà assimilée (+25 XP acquis)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.success)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // MARK: - Aide Bienveillante : « Ré-expliquer plus simplement », Point à revoir & Approfondissement 5 Paliers

    private func pedagogicalSupportSection(part: AcademyPart) -> some View {
        VStack(spacing: 12) {
            // 1. Carte d'approfondissement progressif 5 paliers si disponible
            if let ddId = part.deepDiveId,
               let dive = vm.catalog.deepDives.first(where: { $0.id == ddId }) {
                Button {
                    vm.openDeepDive(id: dive.id)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(AcademyPalette.pineSolid)
                                .frame(width: 44, height: 44)
                            Image(systemName: AcademyIcons.sfSymbol(for: dive.icon))
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(AcademyPalette.gold)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ENVIE D'APPROFONDIR ? · 5 PALIERS PROGRESSIFS")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                            Text(dive.title)
                                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                                .multilineTextAlignment(.leading)
                            Text("Débloquez jusqu'à +175 XP à votre rythme")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AcademyPalette.pine)
                    }
                    .padding(15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AcademyPalette.pineSoft)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.pineBorder, lineWidth: 1.2))
                    )
                }
                .buttonStyle(SpringPressableButtonStyle())
            }

            // 2. Tiroir « Pas tout compris ? Ré-expliquer autrement » + Marqueur de point flou
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        AcademyHaptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                            isReexplainExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.max.fill")
                                .foregroundStyle(AcademyPalette.copper)
                            Text("Ré-expliquer plus simplement")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.ink)
                            Image(systemName: isReexplainExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(AcademyPalette.copperSoft))
                    }

                    Spacer()

                    let markedUnclear = vm.isPartMarkedUnclear(part.id)
                    Button {
                        vm.toggleUnclearPoint(part.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: markedUnclear ? "hand.raised.fill" : "hand.raised")
                            Text(markedUnclear ? "À revoir en fin de cours" : "Pas 100 % clair")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .foregroundStyle(markedUnclear ? .white : AcademyPalette.inkSecondary)
                        .background(Capsule().fill(markedUnclear ? AcademyPalette.copperSolid : AcademyPalette.surfaceSubtle))
                    }
                }

                if isReexplainExpanded {
                    let rx = part.reexplain
                    VStack(alignment: .leading, spacing: 10) {
                        if let rx, !rx.analogy.isEmpty {
                            reexplainItem(badge: "Analogie du quotidien", text: rx.analogy)
                            reexplainItem(badge: "En une phrase toute simple", text: rx.simple)
                            if let ex = rx.example, !ex.isEmpty {
                                reexplainItem(badge: "Exemple concret", text: ex)
                            }
                            if let ess = rx.essential, !ess.isEmpty {
                                reexplainItem(badge: "L'unique réflexe à garder", text: ess)
                            }
                        } else {
                            reexplainItem(
                                badge: "Résumé limpide de cette page",
                                text: part.summary.isEmpty
                                    ? "Retenez simplement l'idée centrale de « \(part.title) » : chaque outil Cenelis est conçu pour vous guider sans stress et protéger vos actions."
                                    : AcademyRichTextParser.plainText(part.summary)
                            )
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AcademyPalette.surface))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AcademyPalette.surfaceSubtle.opacity(0.75))
            )
        }
    }

    private func reexplainItem(badge: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(badge.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(AcademyPalette.copper)
            Text(AcademyRichTextParser.plainText(text))
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(AcademyPalette.ink)
        }
    }

    // MARK: - Barre d'Action Inférieure (Précédent / Validation +25 XP / Quiz Final)

    private func readerBottomBar(part: AcademyPart) -> some View {
        let isLastPart = (vm.activeStepIndex == course.parts.count - 1)
        let alreadyDone = vm.isPartCompleted(part.id)

        return HStack(spacing: 12) {
            Button {
                AcademyHaptics.selection()
                vm.setStepIndex(max(0, vm.activeStepIndex - 1), for: course)
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surfaceSubtle))
                    .foregroundStyle(vm.activeStepIndex > 0 ? AcademyPalette.ink : AcademyPalette.inkMuted)
            }
            .disabled(vm.activeStepIndex == 0)

            Button {
                vm.completePartAndAdvance(in: course)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isLastPart ? "medal.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(isLastPart
                         ? "Passer au Grand Quiz Final"
                         : (alreadyDone ? "Page suivante" : "J'ai compris · Suivant (+25 XP)"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isLastPart ? AcademyPalette.copperGradient : LinearGradient(colors: [AcademyPalette.pineSolid, AcademyPalette.pineDeep], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(SpringPressableButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            AcademyPalette.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(AcademyPalette.border).frame(height: 1)
                }
        )
    }
}

// MARK: - Rendu Polymorphe Natif des 10 Types de Blocs Cenelis Academy

public struct NativeBlockRendererView: View {
    public let block: AcademyBlock
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var selectedPinIdx: Int? = nil
    @State private var localDeviceOverride: AcademyDeviceCaptureMode? = nil

    public init(block: AcademyBlock, vm: AcademyStoreViewModel) {
        self.block = block
        self.vm = vm
    }

    public var body: some View {
        switch block.type {
        case "visual_scene":
            if let sceneId = block.scene, !sceneId.isEmpty {
                NativeVisualSceneView(sceneId: sceneId)
            }
        case "prose":
            proseCard
        case "callout":
            calloutCard
        case "visual_flow":
            visualFlowCard
        case "annotated_shot", "screenshot":
            annotatedScreenshotCard
        case "terms":
            termsGridCard
        case "scenarios":
            scenariosListCard
        case "table":
            nativeTableCard
        case "ui_buttons":
            uiButtonsDictionaryCard
        default:
            if !block.paragraphs.isEmpty || block.text != nil {
                proseCard
            }
        }
    }

    // 1. Bloc Prose Éditoriale + Bulles Interactives
    private var proseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading ?? block.title, !heading.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: AcademyIcons.sfSymbol(for: block.icon))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AcademyPalette.pine)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 9).fill(AcademyPalette.pineSoft))

                    Text(AcademyRichTextParser.plainText(heading))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)
                }
            }

            ForEach(Array(block.paragraphs.enumerated()), id: \.offset) { _, p in
                RichBubbleTextView(p) { key, label in
                    vm.openBubble(key: key, fallbackLabel: label)
                }
            }

            if let text = block.text, !text.isEmpty, block.paragraphs.isEmpty {
                RichBubbleTextView(text) { key, label in
                    vm.openBubble(key: key, fallbackLabel: label)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 2. Bloc Callout (Encadré clé / Astuce / Vigilance)
    private var calloutCard: some View {
        let isWarn = (block.variant == "warn" || block.variant == "amber" || block.variant == "copper")
        let tint = isWarn ? AcademyPalette.copper : AcademyPalette.pine
        let bg = isWarn ? AcademyPalette.copperSoft : AcademyPalette.pineSoft
        let border = isWarn ? AcademyPalette.copperBorder : AcademyPalette.pineBorder

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: isWarn ? "lightbulb.max.fill" : "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                Text(AcademyRichTextParser.plainText(block.title ?? "Repère essentiel"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
            }

            if let text = block.text, !text.isEmpty {
                RichBubbleTextView(text, fontSize: 14.5) { key, label in
                    vm.openBubble(key: key, fallbackLabel: label)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(border, lineWidth: 1.2))
        )
    }

    // 3. Bloc Visual Flow (Étapes Illustrées)
    private var visualFlowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title, !title.isEmpty {
                AcademyBadge("Parcours visuel étape par étape", icon: "point.topleft.down.to.point.bottomright.curvepath.fill", style: .pine)
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            ForEach(Array(block.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(AcademyPalette.pineSolid)
                                .frame(width: 34, height: 34)
                            Image(systemName: AcademyIcons.sfSymbol(for: step.icon))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        if idx < block.steps.count - 1 {
                            Rectangle()
                                .fill(AcademyPalette.pineBorder)
                                .frame(width: 2, height: 22)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if !step.tag.isEmpty {
                            Text(step.tag.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.copper)
                        }
                        Text(AcademyRichTextParser.plainText(step.title))
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        RichBubbleTextView(step.text, fontSize: 13.5) { key, label in
                            vm.openBubble(key: key, fallbackLabel: label)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surfaceSubtle))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 4. Bloc Capture Annotée @2x (Bascule PC / Mobile + Repères Numérotés + Lightbox Zoom)
    private var annotatedScreenshotCard: some View {
        let mobileCandidate = block.resolvedAutoMobileSrc
        let effectiveMode = localDeviceOverride ?? vm.shotDeviceMode
        let activeImagePath: String? = {
            if effectiveMode == .mobile, let mob = mobileCandidate {
                return mob
            }
            return block.src ?? mobileCandidate
        }()
        let showPinsOverlay = !block.pins.isEmpty && (effectiveMode == .pc || mobileCandidate == nil)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        AcademyBadge(block.crop ? "Zoom Bouton @2x" : "Capture Réelle @2x", icon: "viewfinder", style: .copper)
                        if let url = block.url, !url.isEmpty {
                            Text(url)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AcademyPalette.pine)
                                .lineLimit(1)
                        }
                    }
                    if let title = block.title, !title.isEmpty {
                        Text(AcademyRichTextParser.plainText(title))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                    }
                }
                Spacer()

                if mobileCandidate != nil && block.src != nil {
                    Button {
                        AcademyHaptics.selection()
                        localDeviceOverride = (effectiveMode == .mobile) ? .pc : .mobile
                    } label: {
                        Label(effectiveMode == .mobile ? "Mobile" : "PC", systemImage: effectiveMode.sfSymbol)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5.5)
                            .background(Capsule().fill(AcademyPalette.pineSoft))
                            .foregroundStyle(AcademyPalette.pine)
                    }
                }
            }

            if let activeImagePath {
                ZStack(alignment: .bottomTrailing) {
                    CachedAcademyImage(path: activeImagePath, contentMode: .fit, cornerRadius: 14)
                        .overlay {
                            if showPinsOverlay {
                                GeometryReader { geo in
                                    ForEach(Array(block.pins.enumerated()), id: \.offset) { idx, pin in
                                        let px = geo.size.width * CGFloat(pin.x / 100.0)
                                        let py = geo.size.height * CGFloat(pin.y / 100.0)
                                        Button {
                                            AcademyHaptics.selection()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
                                                selectedPinIdx = (selectedPinIdx == idx) ? nil : idx
                                            }
                                        } label: {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 11, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    Circle()
                                                        .fill(selectedPinIdx == idx ? AcademyPalette.pineSolid : AcademyPalette.copperSolid)
                                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                                )
                                                .shadow(color: .black.opacity(0.35), radius: 4)
                                        }
                                        .position(x: px, y: py)
                                    }
                                }
                            }
                        }
                        .onTapGesture {
                            AcademyHaptics.light()
                            vm.activeLightboxShot = LightboxShotContext(
                                path: activeImagePath,
                                title: AcademyRichTextParser.plainText(block.title ?? "Capture Cenelis"),
                                caption: block.caption ?? "",
                                pins: showPinsOverlay ? block.pins : []
                            )
                        }

                    Button {
                        AcademyHaptics.light()
                        vm.activeLightboxShot = LightboxShotContext(
                            path: activeImagePath,
                            title: AcademyRichTextParser.plainText(block.title ?? "Capture Cenelis"),
                            caption: block.caption ?? "",
                            pins: showPinsOverlay ? block.pins : []
                        )
                    } label: {
                        Label("Agrandir @2x", systemImage: "plus.magnifyingglass")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.black.opacity(0.72)))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }
            }

            if let caption = block.caption, !caption.isEmpty {
                RichBubbleTextView(caption, fontSize: 13) { key, label in
                    vm.openBubble(key: key, fallbackLabel: label)
                }
            }

            // Liste numérotée des repères explicatifs
            if !block.pins.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(block.pins.enumerated()), id: \.offset) { idx, pin in
                        let isHighlighted = (selectedPinIdx == idx)
                        Button {
                            AcademyHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPinIdx = (selectedPinIdx == idx) ? nil : idx
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(isHighlighted ? AcademyPalette.pineSolid : AcademyPalette.copperSolid))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AcademyRichTextParser.plainText(pin.title))
                                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AcademyPalette.ink)
                                    Text(AcademyRichTextParser.plainText(pin.text))
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(AcademyPalette.inkSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isHighlighted ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Points additionnels éventuels
            if !block.points.isEmpty {
                VStack(spacing: 7) {
                    ForEach(block.points) { pt in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AcademyRichTextParser.plainText(pt.title))
                                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                            Text(AcademyRichTextParser.plainText(pt.text))
                                .font(.system(size: 12.5))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 5. Bloc Repères / Contrats / Termes Clés
    private var termsGridCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = block.title, !title.isEmpty {
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }
            ForEach(block.termItems) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        if !item.code.isEmpty {
                            Text(item.code)
                                .font(.system(size: 11.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(AcademyPalette.pineSolid))
                                .foregroundStyle(.white)
                        }
                        Text(AcademyRichTextParser.plainText(item.title))
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                    }
                    RichBubbleTextView(item.def, fontSize: 13.5) { key, label in
                        vm.openBubble(key: key, fallbackLabel: label)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surfaceSubtle))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 6. Bloc Mises en Situation & Scénarios Concrets
    private var scenariosListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title, !title.isEmpty {
                AcademyBadge("Mises en situation concrètes", icon: "person.2.wave.2.fill", style: .copper)
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            ForEach(block.scenarioItems) { sc in
                VStack(alignment: .leading, spacing: 8) {
                    if !sc.tag.isEmpty {
                        Text(sc.tag.uppercased())
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.copper)
                    }
                    Text(AcademyRichTextParser.plainText(sc.title))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)

                    ForEach(Array(sc.steps.enumerated()), id: \.offset) { idx, st in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.system(size: 12.5, weight: .black, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                            RichBubbleTextView(st, fontSize: 13.5) { key, label in
                                vm.openBubble(key: key, fallbackLabel: label)
                            }
                        }
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.surfaceSubtle))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 7. Bloc Tableau Comparatif Responsive
    private var nativeTableCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = block.title, !title.isEmpty {
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if !block.headers.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(Array(block.headers.enumerated()), id: \.offset) { _, h in
                                Text(AcademyRichTextParser.plainText(h))
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 155, alignment: .leading)
                                    .padding(10)
                            }
                        }
                        .background(AcademyPalette.pineSolid)
                    }

                    ForEach(Array(block.rows.enumerated()), id: \.offset) { rIdx, row in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { cIdx, cell in
                                Text(AcademyRichTextParser.plainText(cell))
                                    .font(.system(size: 12.5, weight: cIdx == 0 ? .bold : .regular))
                                    .foregroundStyle(AcademyPalette.ink)
                                    .frame(width: 155, alignment: .leading)
                                    .padding(10)
                            }
                        }
                        .background(rIdx % 2 == 0 ? AcademyPalette.surface : AcademyPalette.surfaceSubtle)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AcademyPalette.border, lineWidth: 1))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // 8. Bloc Dictionnaire Visuel des Boutons d'Interface (ui_buttons)
    private var uiButtonsDictionaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AcademyBadge("Boutons & commandes expliqués un par un", icon: "cursorarrow.click.2", style: .pine)
            if let title = block.title, !title.isEmpty {
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            ForEach(block.uiButtonItems) { btn in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: AcademyIcons.sfSymbol(for: btn.icon ?? "mousePointer"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AcademyPalette.pine)
                        Text(AcademyRichTextParser.plainText(btn.label))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Spacer()
                        if let loc = btn.whereLabel, !loc.isEmpty {
                            Text(loc)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AcademyPalette.copperSoft))
                                .foregroundStyle(AcademyPalette.copper)
                        }
                    }

                    if let cropSrc = btn.src, !cropSrc.isEmpty {
                        CachedAcademyImage(path: cropSrc, contentMode: .fit, cornerRadius: 10, minPlaceholderHeight: 70)
                            .frame(maxHeight: 115)
                            .onTapGesture {
                                vm.activeLightboxShot = LightboxShotContext(
                                    path: cropSrc,
                                    title: btn.label,
                                    caption: btn.plainDesc ?? btn.desc ?? ""
                                )
                            }
                    }

                    if let desc = btn.plainDesc ?? btn.desc, !desc.isEmpty {
                        RichBubbleTextView(desc, fontSize: 13.5) { key, label in
                            vm.openBubble(key: key, fallbackLabel: label)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surfaceSubtle))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }
}

// MARK: - Sommaire Interactif des Chapitres & Pages (Table des Matières)

public struct CourseTocSheet: View {
    public let course: AcademyCourse
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss

    public init(course: AcademyCourse, vm: AcademyStoreViewModel) {
        self.course = course
        self.vm = vm
    }

    public var body: some View {
        NavigationStack {
            List {
                if !course.roleShortcuts.isEmpty {
                    Section("Raccourcis directs par poste") {
                        ForEach(course.roleShortcuts) { sc in
                            Button {
                                vm.setStepIndex(sc.startIndex, for: course)
                                dismiss()
                            } label: {
                                Label(sc.label, systemImage: AcademyIcons.sfSymbol(for: sc.icon))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(AcademyPalette.copper)
                            }
                        }
                    }
                }

                if !course.chapters.isEmpty {
                    ForEach(course.chapters) { chapter in
                        Section("Chapitre \(chapter.id) · \(chapter.title)") {
                            let lower = max(0, chapter.startIndex)
                            let upper = min(course.parts.count - 1, chapter.endIndex)
                            if lower <= upper {
                                ForEach(lower...upper, id: \.self) { idx in
                                    partRow(index: idx)
                                }
                            }
                        }
                    }
                } else {
                    Section("Pages du parcours") {
                        ForEach(Array(course.parts.indices), id: \.self) { idx in
                            partRow(index: idx)
                        }
                    }
                }

                Section("Validation & Attestation") {
                    Button {
                        vm.setStepIndex(course.parts.count, for: course)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(AcademyPalette.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grand Quiz Final & Rattrapage 100 %")
                                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                Text("\(course.quiz.count) questions · Seuil officiel \(course.passThresholdPct) %")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AcademyPalette.inkSecondary)
                            }
                            Spacer()
                            if vm.isCourseCertified(course) {
                                AcademyBadge("Apte \(vm.courseConsolidatedPct(course))%", icon: "checkmark.seal.fill", style: .success)
                            }
                        }
                    }
                }
            }
            .navigationTitle(course.number)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(AcademyPalette.pine)
                }
            }
        }
    }

    private func partRow(index: Int) -> some View {
        let part = course.parts[index]
        let isDone = vm.isPartCompleted(part.id)
        let isCurrent = (vm.activeStepIndex == index)
        let isUnclear = vm.isPartMarkedUnclear(part.id)

        return Button {
            vm.setStepIndex(index, for: course)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                    .foregroundStyle(isDone ? AcademyPalette.success : (isCurrent ? AcademyPalette.pine : AcademyPalette.inkMuted))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1). \(part.title)")
                        .font(.system(size: 13.5, weight: isCurrent ? .heavy : .semibold, design: .rounded))
                        .foregroundStyle(isCurrent ? AcademyPalette.pine : AcademyPalette.ink)
                    Text(part.duration)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AcademyPalette.inkMuted)
                }
                Spacer()
                if isUnclear {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AcademyPalette.copper)
                }
            }
        }
    }
}
