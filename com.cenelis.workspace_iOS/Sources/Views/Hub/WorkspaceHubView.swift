import SwiftUI

// MARK: - Vue d'Accueil Native (Hub de Démarrage) & Recherche Multi-Onglets (Panels / Fonctions / Aide Academy)

public struct WorkspaceHubView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @FocusState private var isSearchFocused: Bool
    @State private var showLogoutConfirm: Bool = false

    public init(vm: WorkspaceStoreViewModel) {
        self.vm = vm
    }

    private var gridColumns: [GridItem] {
        if hubUsesList {
            return [GridItem(.flexible(), spacing: 12)]
        }
        let minWidth: CGFloat = (horizontalSizeClass == .regular) ? 260 : 162
        return [GridItem(.adaptive(minimum: minWidth, maximum: 360), spacing: 12)]
    }

    private var hubUsesList: Bool {
        vm.hubDisplayAsList
    }

    public var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                hubTopHeader

                // Barre de reprise instantanée si un panel est déjà actif en session WebView
                if let active = vm.activePanel {
                    activeSessionResumeBanner(panel: active)
                }

                // Barre de Recherche Native + 3 Scopes (Panels / Fonctions / Aide · Cenelis Academy)
                searchAndScopesHeader

                // Contenu dynamique selon l'onglet actif
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch vm.searchScope {
                        case .panels:
                            panelsScopeContent
                        case .functions:
                            functionsScopeContent
                        case .academyHelp:
                            academyHelpScopeContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 96)
                }
                .refreshable {
                    await vm.refreshOperatorAndRbacSession()
                    await vm.refreshAllPanelHealthProbes()
                }
            }
        }
        .confirmationDialog(
            "Se déconnecter du compte Viple Live ID ?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter (changer de compte)", role: .destructive) {
                Task { await vm.performFullLogout() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La session SSO Viple Live ID, les cookies WebView et l'état du code PIN seront intégralement réinitialisés.")
        }
    }

    // MARK: - 1. En-tête Institutionnel du Hub

    private var hubTopHeader: some View {
        HStack(spacing: 12) {
            CenelisMonogramBadge(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Cenelis Workspace")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                    Text("\(vm.authorizedPanels.count) PANELS")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WorkspaceTheme.forest.opacity(scheme == .dark ? 0.45 : 0.12))
                        .foregroundStyle(scheme == .dark ? Color.white : WorkspaceTheme.forest)
                        .clipShape(Capsule())
                }

                Text("\(vm.operatorProfile.displayName) · \(vm.operatorProfile.email)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    .lineLimit(1)
            }

            Spacer()

            // Raccourci direct vers l'application native Cenelis Academy (avec bypass PIN)
            Button {
                Task { await vm.openCenelisAcademyNativeApp() }
            } label: {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(WorkspaceTheme.cardSurface(for: scheme))
                    .foregroundStyle(WorkspaceTheme.forestAccent)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1))
            }
            .accessibilityLabel("Ouvrir Cenelis Academy")

            // Bouton d'ouverture du menu /admin complet ou déconnexion rapide
            Button {
                WorkspaceHaptics.light()
                vm.isShowingNativeAdminSheet = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(WorkspaceTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Menu d'administration unifié")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func activeSessionResumeBanner(panel: AdminPanelItem) -> some View {
        Button {
            WorkspaceHaptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                vm.isShowingHub = false
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(WorkspaceTheme.statusGreen)
                    .frame(width: 8, height: 8)

                Text("Reprendre : \(panel.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(panel.domainLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(WorkspaceTheme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Barre de Recherche Native & Sélecteur des 3 Onglets (Scopes)

    private var searchAndScopesHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))

                TextField(vm.searchScope.placeholder, text: $vm.searchQuery)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .font(.system(size: 14.5))

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(WorkspaceTheme.cardSurface(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
            )

            // 3 Onglets natifs (Panels / Fonctions / Aide · Academy)
            HStack(spacing: 8) {
                ForEach(WorkspaceSearchScope.allCases) { scope in
                    let selected = (vm.searchScope == scope)
                    Button {
                        WorkspaceHaptics.light()
                        withAnimation(.snappy(duration: 0.22)) {
                            vm.searchScope = scope
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.sfSymbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(scope.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? WorkspaceTheme.forest : WorkspaceTheme.secondaryBackground(for: scheme))
                        .foregroundStyle(selected ? Color.white : WorkspaceTheme.primaryInk(for: scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Color.clear : WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.borderRule(for: scheme))
                .frame(height: 1)
        }
    }

    // MARK: - Onglet 1 : Grille / Liste des Panels `/admin`

    private var panelsScopeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Filtres par Pôle Métier + Bascule Grille / Liste
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(EcosystemCatalogRegistry.allCategoriesOrdered, id: \.self) { category in
                            let active = (vm.selectedCategory == category)
                            Button {
                                WorkspaceHaptics.light()
                                vm.selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(active ? WorkspaceTheme.terracotta : WorkspaceTheme.cardSurface(for: scheme))
                                    .foregroundStyle(active ? Color.white : WorkspaceTheme.secondaryInk(for: scheme))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(active ? Color.clear : WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    WorkspaceHaptics.light()
                    withAnimation(.snappy(duration: 0.2)) {
                        vm.hubDisplayAsList.toggle()
                    }
                } label: {
                    Image(systemName: vm.hubDisplayAsList ? "square.grid.2x2" : "list.bullet")
                        .font(.system(size: 13.5, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(WorkspaceTheme.cardSurface(for: scheme))
                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                        )
                }
            }

            let items = vm.filteredHubPanels
            if items.isEmpty {
                emptySearchPlaceholder(
                    icon: "square.dashed",
                    title: "Aucun panel correspondant",
                    subtitle: "Aucun panel /admin habilité ne correspond au filtre « \(vm.searchQuery) »."
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(items) { panel in
                        HubPanelCardView(
                            panel: panel,
                            health: vm.panelHealthMap[panel.id] ?? .unknown,
                            isListMode: hubUsesList,
                            scheme: scheme
                        ) {
                            isSearchFocused = false
                            vm.openPanel(panel)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Onglet 2 : Recherche des Fonctions & Sous-Modules Métiers

    private var functionsScopeContent: some View {
        let items = vm.filteredFunctions
        return VStack(alignment: .leading, spacing: 10) {
            Text("ACCÈS DIRECT AUX SOUS-MODULES & ACTIONS (/ADMIN)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))

            if items.isEmpty {
                emptySearchPlaceholder(
                    icon: "command.square",
                    title: "Aucune fonction trouvée",
                    subtitle: "Essayez un terme comme « Habiliter », « Matrice RBAC », « Registre », « Devis CPQ » ou « Bristol »."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { fn in
                        Button {
                            isSearchFocused = false
                            vm.openPanelFunction(fn)
                        } label: {
                            HStack(alignment: .center, spacing: 13) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(WorkspaceTheme.forest.opacity(scheme == .dark ? 0.45 : 0.10))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: fn.sfSymbol)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(scheme == .dark ? Color.white : WorkspaceTheme.forest)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(fn.panelName.uppercased())
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(WorkspaceTheme.terracotta)
                                    }
                                    Text(fn.title)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                                        .multilineTextAlignment(.leading)
                                    Text(fn.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 4)

                                Image(systemName: "arrow.up.right.square.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(WorkspaceTheme.forestAccent)
                            }
                            .padding(14)
                            .background(WorkspaceTheme.cardSurface(for: scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Onglet 3 : Aide (Cenelis Academy) avec Deep-Link vers la Section Exacte & Bypass PIN

    private var academyHelpScopeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BASE DOCUMENTAIRE & PARCOURS CENELIS ACADEMY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    Text("Un tap ouvre directement la section exacte dans l'app Cenelis Academy sans redemander le code PIN.")
                        .font(.system(size: 12))
                        .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                }
                Spacer()
                if vm.isSearchingAcademy {
                    ProgressView()
                        .scaleEffect(0.85)
                }
            }

            if vm.academyHelpResults.isEmpty && !vm.isSearchingAcademy {
                emptySearchPlaceholder(
                    icon: "graduationcap",
                    title: "Aucun résultat dans Cenelis Academy",
                    subtitle: "Recherchez un outil (SysGRC, AdminGest, 2D-DOC, Livria, OTP…) pour ouvrir son guide exact."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.academyHelpResults) { item in
                        Button {
                            isSearchFocused = false
                            Task {
                                await vm.openAcademyHelpResult(item)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 13) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color(red: 0.059, green: 0.463, blue: 0.431).opacity(0.14))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: WorkspaceIcons.sfSymbol(for: item.icon, panelId: "cenelis-academy"))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.059, green: 0.463, blue: 0.431))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(item.badge)
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(WorkspaceTheme.terracotta)
                                            .lineLimit(1)

                                        Spacer()

                                        HStack(spacing: 3) {
                                            Text("App Academy")
                                            Image(systemName: "arrow.up.forward.app.fill")
                                        }
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.059, green: 0.463, blue: 0.431))
                                    }

                                    Text(item.title)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                                        .multilineTextAlignment(.leading)

                                    if !item.snippet.isEmpty {
                                        Text(item.snippet)
                                            .font(.system(size: 12))
                                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .padding(14)
                            .background(WorkspaceTheme.cardSurface(for: scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptySearchPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme).opacity(0.6))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
            Text(subtitle)
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Carte Individuelle d'un Panel dans le Hub

private struct HubPanelCardView: View {
    let panel: AdminPanelItem
    let health: AdminPanelHealthStatus
    let isListMode: Bool
    let scheme: ColorScheme
    let action: () -> Void

    private var accentColor: Color {
        WorkspaceTheme.color(fromHex: panel.accentHex)
    }

    private var statusDotColor: Color {
        switch health {
        case .operational: return WorkspaceTheme.statusGreen
        case .degraded: return WorkspaceTheme.statusAmber
        case .unreachable: return WorkspaceTheme.statusRed
        case .checking, .unknown: return Color.gray.opacity(0.55)
        }
    }

    var body: some View {
        Button(action: action) {
            if isListMode {
                HStack(spacing: 13) {
                    iconBadge(size: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(panel.name)
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                            if panel.isCenelisAcademyNativeApp {
                                nativeAppTag
                            }
                        }
                        Text(panel.domainLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 7, height: 7)
                        Image(systemName: panel.isCenelisAcademyNativeApp ? "arrow.up.forward.app" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                    }
                }
                .padding(13)
                .background(WorkspaceTheme.cardSurface(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        iconBadge(size: 40)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusDotColor)
                                .frame(width: 7, height: 7)
                            if panel.isCenelisAcademyNativeApp {
                                nativeAppTag
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(panel.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))
                            .lineLimit(1)

                        Text(panel.domainLabel)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(WorkspaceTheme.terracotta)
                            .lineLimit(1)

                        Text(panel.description)
                            .font(.system(size: 11.5))
                            .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
                .background(WorkspaceTheme.cardSurface(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 16
                    )
                    .fill(accentColor)
                    .frame(height: 3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(WorkspaceTheme.borderRule(for: scheme), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func iconBadge(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(accentColor.opacity(0.14))
                .frame(width: size, height: size)
            Image(systemName: WorkspaceIcons.sfSymbol(for: panel.iconKey, panelId: panel.id))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var nativeAppTag: some View {
        Text("APP iOS")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 0.059, green: 0.463, blue: 0.431).opacity(0.15))
            .foregroundStyle(Color(red: 0.059, green: 0.463, blue: 0.431))
            .clipShape(Capsule())
    }
}
