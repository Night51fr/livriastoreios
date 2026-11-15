import SwiftUI

// MARK: - 1. Coque d'Encapsulation Native des Panels Web (`WKWebView` + Badge Hamburger Flottant)

public struct ActivePanelWorkspaceShellView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Arrière-plan institutionnel couvrant les Safe Areas sans jamais masquer la barre d'état iOS
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            // Zone WebView strictement contenue dans les Safe Areas iOS (zéro barre d'URL Safari)
            ZStack(alignment: .top) {
                CenelisPanelWebView(
                    controller: vm.webController,
                    initialURL: vm.activePanel?.normalizedAdminURL,
                    onInterceptCenelisAcademyURL: { interceptedURL in
                        vm.handleInterceptedWebAcademyURL(interceptedURL)
                    },
                    onInterceptUnexpectedWebPinGate: { intendedURL in
                        vm.handleUnexpectedWebPinRedirect(intendedURL: intendedURL)
                    },
                    onInterceptWebLogoutRequest: {
                        Task {
                            await vm.performFullLogout()
                        }
                    },
                    onBarcodeScannerMessage: { action, scanRequest in
                        vm.handleWebBarcodeScannerBridge(action: action, request: scanRequest)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Indicateur fin de chargement natif (2 pt) en haut de la zone utile
                if vm.webController.isLoading {
                    GeometryReader { proxy in
                        let progress = max(0.08, min(1.0, vm.webController.estimatedProgress))
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 2.5)
                            Rectangle()
                                .fill(WorkspaceTheme.terracotta)
                                .frame(width: proxy.size.width * progress, height: 2.5)
                                .animation(.easeOut(duration: 0.18), value: progress)
                        }
                    }
                    .frame(height: 2.5)
                    .allowsHitTesting(false)
                }

                // Bandeau natif de reprise en cas d'erreur réseau temporaire sur le panel
                if let loadError = vm.webController.lastLoadError {
                    panelNetworkErrorBanner(message: loadError)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // Toast discret d'accompagnement lors du masquage par balayage vers la droite
            if vm.showHiddenBurgerHintToast {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WorkspaceTheme.terracotta)
                    Text("Menu masqué · Appui long (2 s) en bas à droite pour réafficher")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(red: 0.067, green: 0.102, blue: 0.090).opacity(0.95))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 4)
                .padding(.trailing, 16)
                .padding(.bottom, 76)
                .allowsHitTesting(false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Pastille Hamburger Native 100 % SwiftUI (remplaçant le dock web `.vua-dock`)
            NativeAdminFloatingBurgerOverlay(vm: vm)
        }
    }

    private func panelNetworkErrorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WorkspaceTheme.statusAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chargement interrompu")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button {
                vm.webController.reload()
            } label: {
                Text("Réessayer")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(WorkspaceTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Button {
                vm.returnToHub()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(7)
                    .background(WorkspaceTheme.secondaryBackground(for: scheme))
                    .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(WorkspaceTheme.cardSurface(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 2. Badge Rond Sombre Flottant (Icône Hamburger Uniquement + Swipe-Right Hide + 2s Long-Press Reveal)

public struct NativeAdminFloatingBurgerOverlay: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @State private var dragOffsetX: CGFloat = 0

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if vm.isFloatingBurgerHidden {
                // Zone tactile invisible exactement au même emplacement en bas à droite (Appui long 2,0 s)
                Color.white.opacity(0.001)
                    .frame(width: 64, height: 64)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 2.0, maximumDistance: 38) {
                        dragOffsetX = 0
                        vm.revealFloatingBurgerButtonAfterLongPress()
                    }
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
                    .accessibilityLabel("Zone de réaffichage du menu d'administration")
                    .accessibilityHint("Maintenez appuyé pendant 2 secondes pour réafficher le bouton menu.")
            } else {
                // Badge rond sombre contenant UNIQUEMENT l'icône hamburger (`line.3.horizontal`)
                ZStack {
                    Circle()
                        .fill(Color(red: 0.067, green: 0.102, blue: 0.090)) // #111A17
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.34), radius: 10, x: 0, y: 4)

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color(red: 0.969, green: 0.965, blue: 0.949))
                }
                .frame(width: 52, height: 52)
                .contentShape(Circle())
                .offset(x: dragOffsetX)
                .opacity(max(0.25, 1.0 - Double(dragOffsetX / 120.0)))
                .onTapGesture {
                    WorkspaceHaptics.medium()
                    vm.isShowingNativeAdminSheet = true
                }
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            // Autoriser uniquement le glissement horizontal vers la droite
                            if value.translation.width > 0 {
                                dragOffsetX = value.translation.width
                            } else {
                                dragOffsetX = max(-6, value.translation.width * 0.15)
                            }
                        }
                        .onEnded { value in
                            let shouldHide = value.translation.width > 34 || value.predictedEndTranslation.width > 65
                            if shouldHide {
                                withAnimation(.easeIn(duration: 0.16)) {
                                    dragOffsetX = 110
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    vm.hideFloatingBurgerButton()
                                    dragOffsetX = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                    dragOffsetX = 0
                                }
                            }
                        }
                )
                .padding(.trailing, 18)
                .padding(.bottom, 18)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.72)).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
                .accessibilityLabel("Menu d'administration Cenelis")
                .accessibilityHint("Touchez pour ouvrir la liste des panels /admin, ou balayez vers la droite pour masquer ce bouton.")
            }
        }
    }
}

// MARK: - 3. Modale Native `Sheet` du Menu `/admin` (Action « Se déconnecter » tout en haut de l'en-tête)

public struct NativeAdminPanelsSheetView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var sheetSearchText: String = ""
    @State private var showLogoutConfirmation: Bool = false

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    private var filteredSheetPanels: [AdminPanelItem] {
        let base = vm.authorizedPanels
        let q = sheetSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
        guard !q.isEmpty else { return base }

        return base.filter { p in
            p.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).contains(q)
                || p.domainLabel.lowercased().contains(q)
                || p.category.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).contains(q)
                || p.description.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).contains(q)
        }
    }

    public var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. EN-TÊTE TOUT EN HAUT DE LA MODALE : Profil Opérateur + Action « Se déconnecter » (Changement de compte)
                sheetTopHeader

                // 2. BARRE D'ACTIONS RAPIDES : Retour au Hub d'accueil + Navigation WebView
                quickNavigationToolbar

                // 3. FILTRE INSTANTANÉ DES PANELS
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))

                    TextField("Filtrer les consoles /admin autorisées…", text: $sheetSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14))

                    if !sheetSearchText.isEmpty {
                        Button {
                            sheetSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WorkspaceTheme.cardSurface(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // 4. LISTE HIÉRARCHIQUE DES PANELS `/ADMIN` AUTORISÉS AVEC INDICATEUR D'ÉTAT EN TEMPS RÉEL
                ScrollView(showsIndicators: false) {
                    let grouped = vm.panelsGroupedByCategory(filteredSheetPanels)
                    if grouped.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 26))
                                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme).opacity(0.6))
                            Text("Aucun panel correspondant")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(grouped, id: \.category) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(section.category.uppercased())
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .tracking(0.9)
                                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                                        Spacer()
                                        Text("\(section.items.count)")
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                                    }
                                    .padding(.horizontal, 4)

                                    VStack(spacing: 7) {
                                        ForEach(section.items) { panel in
                                            SheetAdminPanelRow(
                                                panel: panel,
                                                health: vm.panelHealthMap[panel.id] ?? .unknown,
                                                isActive: (!vm.isShowingHub && vm.activePanel?.id == panel.id),
                                                scheme: scheme
                                            ) {
                                                vm.openPanel(panel)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await vm.refreshAllPanelHealthProbes()
        }
        .confirmationDialog(
            "Se déconnecter du compte Viple Live ID ?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter et changer de compte", role: .destructive) {
                Task {
                    await vm.performFullLogout()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action purge le WKWebsiteDataStore, révoque les cookies SSO Viple Live ID et réinitialise le verrouillage Cenelis Connect PIN.")
        }
    }

    // MARK: - En-tête Supérieur avec Bouton « Se déconnecter » Tout en Haut

    private var sheetTopHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(WorkspaceTheme.forest)
                    .frame(width: 38, height: 38)
                Text(vm.operatorProfile.initials)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vm.operatorProfile.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                        .lineLimit(1)

                    if vm.operatorProfile.isSuperAdmin || vm.rbacSnapshot.isSuperAdmin {
                        Text("SUPER-ADMIN")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(WorkspaceTheme.terracotta.opacity(0.16))
                            .foregroundStyle(WorkspaceTheme.terracotta)
                            .clipShape(Capsule())
                    }
                }

                Text(vm.operatorProfile.email)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // Action « Se déconnecter » tout en haut de l'en-tête de la modale (§4)
            Button {
                WorkspaceHaptics.warning()
                showLogoutConfirmation = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Se déconnecter")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(WorkspaceTheme.statusRed.opacity(0.12))
                .foregroundStyle(WorkspaceTheme.statusRed)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(WorkspaceTheme.statusRed.opacity(0.28), lineWidth: 1)
                )
            }
            .accessibilityLabel("Se déconnecter du compte Viple Live ID")

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(WorkspaceTheme.secondaryBackground(for: scheme))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Fermer le menu")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.borderRule(for: scheme))
                .frame(height: 1)
        }
    }

    // MARK: - Barre d'Outils Rapide (Retour au Hub d'Accueil + Contrôles WebView)

    private var quickNavigationToolbar: some View {
        HStack(spacing: 8) {
            Button {
                vm.returnToHub()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Accueil Hub")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(vm.isShowingHub ? WorkspaceTheme.forest : WorkspaceTheme.cardSurface(for: scheme))
                .foregroundStyle(vm.isShowingHub ? Color.white : WorkspaceTheme.primaryInk(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(vm.isShowingHub ? Color.clear : WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if !vm.isShowingHub {
                HStack(spacing: 6) {
                    sheetToolbarIconButton(
                        symbol: "chevron.left",
                        label: "Page précédente",
                        disabled: !vm.webController.canGoBack
                    ) {
                        vm.webController.goBack()
                    }

                    sheetToolbarIconButton(
                        symbol: "chevron.right",
                        label: "Page suivante",
                        disabled: !vm.webController.canGoForward
                    ) {
                        vm.webController.goForward()
                    }

                    sheetToolbarIconButton(
                        symbol: "arrow.clockwise",
                        label: "Actualiser le panel",
                        disabled: false
                    ) {
                        vm.webController.reload()
                        dismiss()
                    }
                }
            }

            Spacer()

            Button {
                WorkspaceHaptics.light()
                Task {
                    await vm.refreshAllPanelHealthProbes()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("Sondes")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(WorkspaceTheme.secondaryBackground(for: scheme))
                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func sheetToolbarIconButton(
        symbol: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(WorkspaceTheme.cardSurface(for: scheme))
                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
        }
        .disabled(disabled)
        .opacity(disabled ? 0.38 : 1.0)
        .accessibilityLabel(label)
    }
}

// MARK: - Ligne d'un Panel `/admin` dans la Modale Native

private struct SheetAdminPanelRow: View {
    let panel: AdminPanelItem
    let health: AdminPanelHealthStatus
    let isActive: Bool
    let scheme: ColorScheme
    let action: () -> Void

    private var accentColor: Color {
        WorkspaceTheme.color(fromHex: panel.accentHex)
    }

    private var statusColor: Color {
        switch health {
        case .operational: return WorkspaceTheme.statusGreen
        case .degraded: return WorkspaceTheme.statusAmber
        case .unreachable: return WorkspaceTheme.statusRed
        case .checking, .unknown: return Color.gray.opacity(0.55)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: WorkspaceIcons.sfSymbol(for: panel.iconKey, panelId: panel.id))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(panel.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                            .lineLimit(1)

                        if isActive {
                            Text("ACTIF")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(WorkspaceTheme.forest)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        } else if panel.isCenelisAcademyNativeApp {
                            Text("APP iOS")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color(red: 0.059, green: 0.463, blue: 0.431).opacity(0.16))
                                .foregroundStyle(Color(red: 0.059, green: 0.463, blue: 0.431))
                                .clipShape(Capsule())
                        }
                    }

                    Text(panel.domainLabel)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Indicateur d'état en temps réel (pastille + latence ms)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(health.shortLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(WorkspaceTheme.secondaryBackground(for: scheme))
                .clipShape(Capsule())

                Image(systemName: panel.isCenelisAcademyNativeApp ? "arrow.up.forward.app" : "chevron.right")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? WorkspaceTheme.forest.opacity(scheme == .dark ? 0.28 : 0.08) : WorkspaceTheme.cardSurface(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isActive ? WorkspaceTheme.forestAccent : WorkspaceTheme.borderRule(for: scheme),
                        lineWidth: isActive ? 1.4 : 1.0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
