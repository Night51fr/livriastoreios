import SwiftUI

// MARK: - Mode Ressources & Encyclopédie Native (7 Onglets Synchronisés, Consoles /admin, SOPs & Glossaire A–Z)

public struct ResourcesEncyclopediaView: View {
    @ObservedObject var vm: AcademyStoreViewModel
    @State private var selectedTabId: String = ""
    @State private var glossaryQuery: String = ""
    @State private var glossaryLetter: String = "TOUT"

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    private var activeTabObj: AcademyResourceTab? {
        if let found = vm.catalog.resources.first(where: { $0.id == selectedTabId }) {
            return found
        }
        return vm.catalog.resources.first
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sélecteur horizontal des 7 onglets encyclopédiques
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.catalog.resources) { tab in
                            let isCurrent = (activeTabObj?.id == tab.id)
                            Button {
                                AcademyHaptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTabId = tab.id
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: AcademyIcons.sfSymbol(for: tab.icon))
                                        .font(.system(size: 12, weight: .bold))
                                    Text(tab.label)
                                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8.5)
                                .foregroundStyle(isCurrent ? .white : AcademyPalette.ink)
                                .background(Capsule().fill(isCurrent ? AcademyPalette.pineSolid : AcademyPalette.surfaceSubtle))
                            }
                            .buttonStyle(SpringPressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(AcademyPalette.surface)

                if let tab = activeTabObj {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // En-tête de l'onglet
                            VStack(alignment: .leading, spacing: 6) {
                                AcademyBadge(tab.badge, icon: AcademyIcons.sfSymbol(for: tab.icon), style: .copper)
                                Text(tab.title)
                                    .font(.system(size: 21, weight: .black, design: .rounded))
                                    .foregroundStyle(AcademyPalette.ink)
                                Text(tab.subtitle)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(AcademyPalette.inkSecondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.surface))

                            // 1. Couches d'architecture (si présentes)
                            if !tab.archLayers.isEmpty {
                                ForEach(tab.archLayers) { layer in
                                    archLayerCard(layer)
                                }
                            }

                            // 2. Cartes des Consoles /admin avec captures @2x PC / Mobile
                            if !tab.cards.isEmpty {
                                HStack {
                                    Text("Affichage des captures consoles :")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(AcademyPalette.inkSecondary)
                                    Spacer()
                                    Picker("Appareil", selection: $vm.shotDeviceMode) {
                                        ForEach(AcademyDeviceCaptureMode.allCases) { m in
                                            Text(m.rawValue).tag(m)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 190)
                                }

                                ForEach(tab.cards) { card in
                                    adminConsoleResourceCard(card)
                                }
                            }

                            // 3. Sections riches & SOPs cochables (+5 XP par étape)
                            ForEach(tab.sections) { sec in
                                if sec.type == "scenarios" && tab.id.localizedCaseInsensitiveContains("sop") {
                                    interactiveSopScenarioBlock(sec, tabId: tab.id)
                                } else {
                                    NativeBlockRendererView(block: sec, vm: vm)
                                }
                            }

                            // 4. Glossaire A–Z interactif
                            if !tab.glossary.isEmpty {
                                glossaryExplorerSection(entries: tab.glossary)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 28)
                    }
                } else {
                    ProgressView("Chargement de l'encyclopédie…")
                        .frame(maxHeight: .infinity)
                }
            }
            .background(AcademyPalette.background)
            .navigationTitle("Ressources")
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear {
                if let pre = vm.preselectedResourceTabId {
                    selectedTabId = pre
                    vm.preselectedResourceTabId = nil
                } else if selectedTabId.isEmpty, let first = vm.catalog.resources.first {
                    selectedTabId = first.id
                }
            }
            .onChange(of: vm.preselectedResourceTabId) { _, newValue in
                if let newValue {
                    selectedTabId = newValue
                    vm.preselectedResourceTabId = nil
                }
            }
        }
    }

    // MARK: - Couche d'Architecture 5 Niveaux

    private func archLayerCard(_ layer: AcademyArchLayer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: AcademyIcons.sfSymbol(for: layer.icon))
                    .foregroundStyle(AcademyPalette.pine)
                Text(layer.label)
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(AcademyPalette.ink)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(layer.nodes) { node in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.title)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(AcademyPalette.pine)
                        Text(node.sub)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AcademyPalette.inkSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surfaceSubtle))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // MARK: - Fiche Console /admin avec Capture @2x

    private func adminConsoleResourceCard(_ card: AcademyResourceCard) -> some View {
        let chosenShot: String? = {
            if vm.shotDeviceMode == .mobile, let mob = card.mobileShot, !mob.isEmpty {
                return mob
            }
            return card.shot ?? card.mobileShot
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                AcademyBadge(card.tag, style: .pine)
                Spacer()
                AcademyBadge(card.rbac, icon: "lock.shield.fill", style: .copper)
            }

            Text(card.title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(AcademyPalette.ink)

            Text(card.url)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AcademyPalette.pine)

            if let chosenShot, !chosenShot.isEmpty {
                CachedAcademyImage(path: chosenShot, contentMode: .fit, cornerRadius: 14)
                    .onTapGesture {
                        vm.activeLightboxShot = LightboxShotContext(
                            path: chosenShot,
                            title: card.title,
                            caption: "\(card.url) — Habilitation : \(card.rbac)"
                        )
                    }
            }

            ForEach(card.points, id: \.self) { pt in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AcademyPalette.pine)
                        .padding(.top, 2)
                    Text(AcademyRichTextParser.plainText(pt))
                        .font(.system(size: 13))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AcademyPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AcademyPalette.border, lineWidth: 1))
        )
    }

    // MARK: - Procédures SOP Interactives Cochables sur le Terrain

    private func interactiveSopScenarioBlock(_ block: AcademyBlock, tabId: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AcademyBadge("Checklist terrain interactive (+5 XP / étape)", icon: "checklist", style: .pine)
            if let title = block.title {
                Text(AcademyRichTextParser.plainText(title))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }

            ForEach(block.scenarioItems) { sc in
                VStack(alignment: .leading, spacing: 9) {
                    Text(sc.tag.uppercased())
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(AcademyPalette.copper)
                    Text(AcademyRichTextParser.plainText(sc.title))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))

                    ForEach(Array(sc.steps.enumerated()), id: \.offset) { idx, st in
                        let stepKey = "\(tabId)-\(sc.id)-\(idx)"
                        let isChecked = (vm.progress.checkedSopSteps[stepKey] == true)
                        Button {
                            vm.toggleSopStep(stepKey: stepKey)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(isChecked ? AcademyPalette.success : AcademyPalette.pine)
                                Text(AcademyRichTextParser.plainText(st))
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(isChecked ? AcademyPalette.inkSecondary : AcademyPalette.ink)
                                    .strikethrough(isChecked)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isChecked ? AcademyPalette.successSoft : AcademyPalette.surface))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 15).fill(AcademyPalette.surfaceSubtle))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(AcademyPalette.surface))
    }

    // MARK: - Glossaire A–Z Interactif

    private func glossaryExplorerSection(entries: [AcademyGlossaryEntry]) -> some View {
        let letters = ["TOUT"] + Array(Set(entries.map(\.initialLetter))).sorted()
        let filtered = entries.filter { g in
            let matchLetter = (glossaryLetter == "TOUT") || (g.initialLetter == glossaryLetter)
            let q = glossaryQuery.trimmingCharacters(in: .whitespaces)
            let matchQuery = q.isEmpty
                || g.term.localizedCaseInsensitiveContains(q)
                || g.def.localizedCaseInsensitiveContains(q)
                || g.cat.localizedCaseInsensitiveContains(q)
            return matchLetter && matchQuery
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AcademyPalette.pine)
                TextField("Filtrer les \(entries.count) termes du glossaire…", text: $glossaryQuery)
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(AcademyPalette.surface))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(letters, id: \.self) { letter in
                        Button {
                            AcademyHaptics.selection()
                            glossaryLetter = letter
                        } label: {
                            Text(letter)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(glossaryLetter == letter ? AcademyPalette.pineSolid : AcademyPalette.surface))
                                .foregroundStyle(glossaryLetter == letter ? .white : AcademyPalette.ink)
                        }
                    }
                }
            }

            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.term)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(AcademyPalette.ink)
                        Spacer()
                        AcademyBadge(item.cat, style: .copper)
                    }
                    Text(AcademyRichTextParser.plainText(item.def))
                        .font(.system(size: 13.5))
                        .foregroundStyle(AcademyPalette.inkSecondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AcademyPalette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AcademyPalette.border, lineWidth: 1))
                )
            }
        }
    }
}
