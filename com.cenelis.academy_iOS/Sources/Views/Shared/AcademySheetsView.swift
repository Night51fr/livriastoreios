import SwiftUI
import AuthenticationServices

// MARK: - 1. Rendu de Paragraphe Enrichi avec Bulles Interactives {{cle|libelle}}

public struct RichBubbleTextView: View {
    public let rawText: String
    public var fontSize: CGFloat = 15.5
    public var lineSpacing: CGFloat = 5
    public var onTapBubble: (String, String) -> Void

    public init(
        _ rawText: String,
        fontSize: CGFloat = 15.5,
        lineSpacing: CGFloat = 5,
        onTapBubble: @escaping (String, String) -> Void
    ) {
        self.rawText = rawText
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.onTapBubble = onTapBubble
    }

    public var body: some View {
        let tokens = AcademyRichTextParser.tokenize(rawText)
        let bubbleItems: [(key: String, label: String)] = tokens.compactMap { token in
            if case let .bubble(_, key, label) = token {
                return (key, label)
            }
            return nil
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(buildAttributed(from: tokens))
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "cenelisbubble",
                       let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        let qMap = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                        let key = qMap["key"] ?? ""
                        let label = qMap["label"] ?? key
                        onTapBubble(key, label)
                        return .handled
                    }
                    return .systemAction
                })

            if !bubbleItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(bubbleItems.enumerated()), id: \.offset) { _, item in
                            Button {
                                onTapBubble(item.key, item.label)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "questionmark.bubble.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("C'est quoi : \(item.label) ?")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5.5)
                                .foregroundStyle(AcademyPalette.copper)
                                .background(
                                    Capsule()
                                        .fill(AcademyPalette.copperSoft)
                                        .overlay(Capsule().strokeBorder(AcademyPalette.copperBorder, lineWidth: 1))
                                )
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func buildAttributed(from tokens: [AcademyInlineToken]) -> AttributedString {
        var result = AttributedString()

        for token in tokens {
            switch token {
            case let .text(_, content, isBold, isCode, isItalic):
                var part = AttributedString(content)
                if isCode {
                    part.font = .system(size: max(11, fontSize - 1), weight: .bold, design: .monospaced)
                    part.foregroundColor = AcademyPalette.pine
                    part.backgroundColor = AcademyPalette.pineSoft
                } else if isBold && isItalic {
                    part.font = .system(size: fontSize, weight: .bold).italic()
                    part.foregroundColor = AcademyPalette.ink
                } else if isBold {
                    part.font = .system(size: fontSize, weight: .bold)
                    part.foregroundColor = AcademyPalette.ink
                } else if isItalic {
                    part.font = .system(size: fontSize, weight: .regular).italic()
                    part.foregroundColor = AcademyPalette.ink
                } else {
                    part.font = .system(size: fontSize, weight: .regular)
                    part.foregroundColor = AcademyPalette.ink
                }
                result.append(part)

            case let .bubble(_, key, label):
                var part = AttributedString("\(label) ⓘ")
                part.font = .system(size: fontSize, weight: .bold, design: .rounded)
                part.foregroundColor = AcademyPalette.copper
                part.underlineStyle = .single
                var comps = URLComponents()
                comps.scheme = "cenelisbubble"
                comps.host = "open"
                comps.queryItems = [
                    URLQueryItem(name: "key", value: key),
                    URLQueryItem(name: "label", value: label)
                ]
                part.link = comps.url
                result.append(part)
            }
        }
        return result
    }
}

// MARK: - 2. Feuille Tactile « Bulle Vulgarisée : C'est quoi … ? »

public struct BubbleExplainerSheet: View {
    public let bubble: AcademyBubble
    @Environment(\.dismiss) private var dismiss

    public init(bubble: AcademyBubble) {
        self.bubble = bubble
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        AcademyBadge("Explication 100 % sans jargon", icon: "lightbulb.max.fill", style: .copper)
                        AcademyBadge("+10 XP", icon: "sparkles", style: .pine)
                    }

                    Text(bubble.q)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)

                    Text(bubble.title)
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(AcademyPalette.ink)

                    // Analogie du quotidien
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Imaginez dans la vie de tous les jours", systemImage: "sparkles")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.copper)
                        Text(AcademyRichTextParser.plainText(bubble.analogy))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AcademyPalette.ink)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AcademyPalette.copperSoft)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.copperBorder, lineWidth: 1))
                    )

                    // Définition claire
                    VStack(alignment: .leading, spacing: 8) {
                        Label("En clair, qu'est-ce que c'est ?", systemImage: "book.pages.fill")
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                        Text(AcademyRichTextParser.plainText(bubble.def))
                            .font(.system(size: 15))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AcademyPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.border, lineWidth: 1))
                    )

                    // Pourquoi chez Cenelis
                    if !bubble.why.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Pourquoi c'est précieux chez Cenelis", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)
                            Text(AcademyRichTextParser.plainText(bubble.why))
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundStyle(AcademyPalette.ink)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AcademyPalette.pineSoft)
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AcademyPalette.pineBorder, lineWidth: 1))
                        )
                    }

                    Button {
                        AcademyHaptics.selection()
                        dismiss()
                    } label: {
                        Text("Parfait, c'est limpide !")
                            .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(AcademyPalette.pineSolid))
                    }
                    .buttonStyle(SpringPressableButtonStyle())
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Bulle Vulgarisée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(AcademyPalette.pine)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 3. Dossier d'Approfondissement Progressif (5 Paliers Déblocables)

public struct DeepDiveReaderSheet: View {
    public let dive: AcademyDeepDive
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLevel: Int = 1

    public init(dive: AcademyDeepDive, vm: AcademyStoreViewModel) {
        self.dive = dive
        self.vm = vm
    }

    public var body: some View {
        let rec = vm.progress.deepDives[dive.id] ?? AcademyDeepDiveProgressRecord(maxLevel: 1, completed: [:])
        let maxUnlocked = max(1, rec.maxLevel)
        let currentObj = dive.levels.first(where: { $0.level == selectedLevel }) ?? dive.levels.first

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // En-tête du dossier
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            AcademyBadge(dive.badge, icon: AcademyIcons.sfSymbol(for: dive.icon), style: .pine)
                            Spacer()
                            Text("\(rec.completed.count)/\(dive.levels.count) paliers validés")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                        }
                        Text(AcademyRichTextParser.plainText(dive.title))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Text(AcademyRichTextParser.plainText(dive.subtitle))
                            .font(.system(size: 14))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }

                    // Sélecteur des 5 paliers progressifs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dive.levels) { lvl in
                                let isUnlocked = lvl.level <= maxUnlocked
                                let isDone = rec.completed["\(lvl.level)"] != nil
                                let isCurrent = selectedLevel == lvl.level

                                Button {
                                    guard isUnlocked else {
                                        AcademyHaptics.warning()
                                        return
                                    }
                                    AcademyHaptics.selection()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        selectedLevel = lvl.level
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isDone ? "checkmark.circle.fill" : (isUnlocked ? "lock.open.fill" : "lock.fill"))
                                            .font(.system(size: 11.5, weight: .bold))
                                        Text("Palier \(lvl.level)")
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 9)
                                    .foregroundStyle(isCurrent ? .white : (isUnlocked ? AcademyPalette.ink : AcademyPalette.inkMuted))
                                    .background(
                                        Capsule()
                                            .fill(isCurrent ? AcademyPalette.pineSolid : (isDone ? AcademyPalette.pineSoft : AcademyPalette.surfaceSubtle))
                                    )
                                }
                                .buttonStyle(SpringPressableButtonStyle())
                            }
                        }
                    }

                    if let levelData = currentObj {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Palier \(levelData.level) · \(AcademyRichTextParser.plainText(levelData.title))")
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                                .foregroundStyle(AcademyPalette.pine)

                            Text(AcademyRichTextParser.plainText(levelData.summary))
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(AcademyPalette.inkSecondary)

                            if !levelData.analogy.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Image mentale pour tout comprendre", systemImage: "lightbulb.max.fill")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AcademyPalette.copper)
                                    Text(AcademyRichTextParser.plainText(levelData.analogy))
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundStyle(AcademyPalette.ink)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.copperSoft))
                            }

                            ForEach(Array(levelData.paragraphs.enumerated()), id: \.offset) { _, p in
                                RichBubbleTextView(p, fontSize: 15) { key, label in
                                    vm.openBubble(key: key, fallbackLabel: label)
                                }
                            }

                            if !levelData.unlockedWords.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Nouveaux repères débloqués à ce palier", systemImage: "key.fill")
                                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AcademyPalette.pine)

                                    ForEach(levelData.unlockedWords) { w in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(AcademyRichTextParser.plainText(w.word))
                                                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                                .foregroundStyle(AcademyPalette.ink)
                                            Text(AcademyRichTextParser.plainText(w.def))
                                                .font(.system(size: 13))
                                                .foregroundStyle(AcademyPalette.inkSecondary)
                                        }
                                        .padding(11)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                                    }
                                }
                                .padding(.top, 4)
                            }

                            Button {
                                vm.completeDeepDiveLevel(dive: dive, level: levelData.level)
                                if levelData.level < dive.levels.count {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                        selectedLevel = levelData.level + 1
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text(levelData.level < dive.levels.count
                                         ? "J'ai assimilé le Palier \(levelData.level) — Débloquer le Palier \(levelData.level + 1) (+35 XP)"
                                         : "Valider la maîtrise complète du Palier 5 (+65 XP)")
                                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.pineSolid))
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                            .padding(.top, 6)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AcademyPalette.surface)
                                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
                        )
                    }
                }
                .padding(18)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Approfondissement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(AcademyPalette.pine)
                }
            }
            .onAppear {
                selectedLevel = min(dive.levels.count, max(1, rec.maxLevel))
            }
        }
    }
}

// MARK: - 4. Lightbox Plein Écran @2x (Pinch-to-Zoom, Double-Tap & Repères Numérotés)

public struct ScreenshotLightboxSheet: View {
    public let context: LightboxShotContext
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var activePinIndex: Int? = nil

    public init(context: LightboxShotContext) {
        self.context = context
    }

    public var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.07, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // Barre supérieure
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("Pincez à deux doigts ou touchez 2× pour zoomer en @2x")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    Button {
                        AcademyHaptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer()

                // Zone image zoomable + repères interactifs
                ZStack {
                    CachedAcademyImage(path: context.path, contentMode: .fit, cornerRadius: 12, minPlaceholderHeight: 260)
                        .overlay {
                            if !context.pins.isEmpty {
                                GeometryReader { geo in
                                    ForEach(Array(context.pins.enumerated()), id: \.offset) { idx, pin in
                                        let px = geo.size.width * CGFloat(pin.x / 100.0)
                                        let py = geo.size.height * CGFloat(pin.y / 100.0)
                                        Button {
                                            AcademyHaptics.selection()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                activePinIndex = (activePinIndex == idx) ? nil : idx
                                            }
                                        } label: {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 12, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                                .frame(width: 26, height: 26)
                                                .background(
                                                    Circle()
                                                        .fill(activePinIndex == idx ? AcademyPalette.gold : AcademyPalette.copperSolid)
                                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                                )
                                                .shadow(color: .black.opacity(0.45), radius: 5)
                                        }
                                        .position(x: px, y: py)
                                    }
                                }
                            }
                        }
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { val in
                                    let next = lastScale * val.magnification
                                    scale = min(4.0, max(1.0, next))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale <= 1.02 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { val in
                                    guard scale > 1.05 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + val.translation.width,
                                        height: lastOffset.height + val.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            AcademyHaptics.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if scale > 1.2 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.2
                                    lastScale = 2.2
                                }
                            }
                        }
                }
                .padding(.horizontal, 12)

                Spacer()

                // Légende ou détail du repère sélectionné
                if let idx = activePinIndex, context.pins.indices.contains(idx) {
                    let pin = context.pins[idx]
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repère #\(idx + 1) · \(AcademyRichTextParser.plainText(pin.title))")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.gold)
                        Text(AcademyRichTextParser.plainText(pin.text))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.12)))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } else if !context.caption.isEmpty {
                    Text(AcademyRichTextParser.plainText(context.caption))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - 5. Recherche Globale Instantanée (Tout Cenelis Academy)

public struct GlobalSearchSheet: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let results = vm.searchEverywhere(query: query)

        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AcademyPalette.pine)
                    TextField("Rechercher un cours, outil, contrat e.GL, bulle…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AcademyPalette.inkMuted)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.surfaceSubtle))
                .padding(16)

                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 38))
                            .foregroundStyle(AcademyPalette.pine)
                        Text("Recherche universelle instantanée")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                        Text("Tapez un mot (« Wingman », « Loi Lang », « Zéro Fibre », « GVN_u », « Stalwart », « PIN »…) pour sauter directement à la page, bulle ou procédure correspondante.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        // Suggestions rapides
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["SysGRC", "Cenelis Connect", "Wingman", "Loi Lang", "Zéro Fibre", "Modération", "Opt-in"], id: \.self) { sug in
                                    Button(sug) {
                                        AcademyHaptics.selection()
                                        query = sug
                                    }
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(AcademyPalette.pineSoft))
                                    .foregroundStyle(AcademyPalette.pine)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 6)
                    }
                    .frame(maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "Aucun résultat pour « \(query) »",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Essayez un terme plus court ou explorez l'onglet Ressources.")
                    )
                } else {
                    List(results) { item in
                        Button {
                            handleResultSelection(item)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AcademyPalette.pine)
                                    .frame(width: 34, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.pineSoft))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.kind.uppercased())
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AcademyPalette.copper)
                                    Text(AcademyRichTextParser.plainText(item.title))
                                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AcademyPalette.ink)
                                    Text(AcademyRichTextParser.plainText(item.snippet))
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(AcademyPalette.inkSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(AcademyPalette.background)
            .navigationTitle("Rechercher")
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

    private func handleResultSelection(_ item: GlobalSearchResult) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            if let bubbleKey = item.actionBubbleKey {
                vm.openBubble(key: bubbleKey, fallbackLabel: item.title)
            } else if let courseId = item.actionCourseId {
                vm.openCourse(courseId, stepIndex: item.actionPartIndex)
            } else if let ddId = item.actionDeepDiveId {
                vm.openDeepDive(id: ddId)
            } else if let resId = item.actionResourceTabId {
                vm.preselectedResourceTabId = resId
                vm.activeTab = .resources
            }
        }
    }
}

// MARK: - 6. Authentification Native Viple Live ID & SSO Cenelis Connect

public struct AcademyAuthSheet: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthSession

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSubmitting: Bool = false

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // En-tête institutionnel
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(AcademyPalette.heroGradient)
                                .frame(width: 72, height: 72)
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AcademyPalette.gold)
                        }
                        Text("Connexion Cenelis Academy")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Text("Synchronisez vos cours, attestations 80 % → 100 %, points XP et trophées entre le site web et votre iPhone.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Bouton SSO Web officiel Cenelis Connect / Viple Live ID
                    Button {
                        Task { await startWebSSO() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("Connexion unique SSO Cenelis / Viple")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.pineSolid))
                    }
                    .buttonStyle(SpringPressableButtonStyle())

                    HStack {
                        Rectangle().fill(AcademyPalette.border).frame(height: 1)
                        Text("OU IDENTIFIANTS DIRECTS")
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.inkMuted)
                        Rectangle().fill(AcademyPalette.border).frame(height: 1)
                    }

                    // Formulaire natif direct
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Adresse e-mail (@viplemail.fr ou compte Viple)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                            TextField("prenom.nom@viplemail.fr", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Mot de passe")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AcademyPalette.inkSecondary)
                            SecureField("Votre mot de passe personnel", text: $password)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                        }

                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AcademyPalette.danger)
                                Text(errorMessage)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(AcademyPalette.danger)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AcademyPalette.dangerSoft))
                        }

                        Button {
                            Task { await submitDirectLogin() }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Se connecter et synchroniser")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AcademyPalette.copperGradient))
                        }
                        .buttonStyle(SpringPressableButtonStyle())
                        .disabled(isSubmitting || email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AcademyPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
                    )
                }
                .padding(20)
            }
            .background(AcademyPalette.background)
            .navigationTitle("Compte Apprenant")
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

    private func submitDirectLogin() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await vm.loginWithPassword(email: email, password: password)
            dismiss()
        } catch {
            AcademyHaptics.error()
            errorMessage = error.localizedDescription
        }
    }

    private func startWebSSO() async {
        errorMessage = nil
        do {
            let callbackURL = try await webAuthSession.authenticate(
                using: AcademyAPIClient.shared.ssoStartURL(),
                callback: .customScheme("cenelisacademy"),
                additionalHeaderFields: [:]
            )
            await vm.handleSSOCallbackURL(callbackURL)
            dismiss()
        } catch {
            // Ignorer silencieusement l'annulation volontaire de la feuille SSO par l'utilisateur
        }
    }
}
