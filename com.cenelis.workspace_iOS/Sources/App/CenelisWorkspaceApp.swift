import SwiftUI

// MARK: - Point d'Entrée Natif iOS « Cenelis Workspace / Admin Hub »

@main
public struct CenelisWorkspaceApp: App {
    @StateObject private var store = WorkspaceStoreViewModel()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            WorkspaceRootContainerView(vm: store, scenePhase: scenePhase)
                .task {
                    await store.bootstrapOnLaunch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    store.handleScenePhaseChange(to: newPhase)
                }
                .onOpenURL { incomingURL in
                    handleIncomingWorkspaceDeepLink(incomingURL)
                }
        }
    }

    private func handleIncomingWorkspaceDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "cenelisworkspace" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryMap = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if let panelId = queryMap["panel"] ?? queryMap["id"],
           let target = store.authorizedPanels.first(where: { $0.id == panelId }) {
            store.openPanel(target)
        }
    }
}

// MARK: - Conteneur Racine Multi-Couches (Session Persistante + Verrouillage PIN Systématique + Confidentialité Multitâche)

public struct WorkspaceRootContainerView: View {
    @ObservedObject public var vm: WorkspaceStoreViewModel
    public let scenePhase: ScenePhase
    @Environment(\.colorScheme) private var scheme

    public init(vm: WorkspaceStoreViewModel, scenePhase: ScenePhase) {
        self.vm = vm
        self.scenePhase = scenePhase
    }

    public var body: some View {
        ZStack {
            switch vm.activeSecurityState {
            case .booting:
                WorkspaceBootSplashView()
                    .transition(.opacity)

            case .loginRequired:
                VipleLiveLoginView(vm: vm)
                    .transition(.opacity)

            case .accessDenied:
                WorkspaceAccessDeniedView(vm: vm)
                    .transition(.opacity)

            case .pinLocked, .unlocked:
                // Maintien en mémoire du Hub et du WKWebView actif sous le verrouillage PIN pour préserver l'état DOM/formulaires
                ZStack {
                    if vm.activePanel != nil {
                        ActivePanelWorkspaceShellView(vm: vm)
                            .opacity(vm.isShowingHub ? 0 : 1)
                            .allowsHitTesting(!vm.isShowingHub && vm.activeSecurityState == .unlocked)
                            .accessibilityHidden(vm.isShowingHub || vm.activeSecurityState != .unlocked)
                    }

                    if vm.isShowingHub || vm.activePanel == nil {
                        WorkspaceHubView(vm: vm)
                            .allowsHitTesting(vm.activeSecurityState == .unlocked)
                            .accessibilityHidden(vm.activeSecurityState != .unlocked)
                            .transition(.opacity)
                    }
                }
                .zIndex(1)

                // Écran natif de verrouillage « Cenelis Connect PIN » (exigé à chaque ouverture et chaque retour au premier plan)
                if vm.activeSecurityState == .pinLocked {
                    NativeCenelisConnectPinLockView(vm: vm)
                        .zIndex(50)
                        .transition(.opacity)
                }
            }

            // Voile de confidentialité dans le sélecteur d'applications iOS (`scenePhase != .active`)
            if vm.operatorProfile.authenticated && scenePhase != .active {
                WorkspaceMultitaskingPrivacyShieldView()
                    .zIndex(100)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $vm.isShowingNativeAdminSheet) {
            NativeAdminPanelsSheetView(vm: vm)
        }
        .alert("Application Cenelis Academy requise", isPresented: $vm.academyInstallAlertShown) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text("Installez l'application iOS native « Cenelis Academy » sur cet appareil pour consulter les cours et guides interactifs avec déverrouillage automatique.")
        }
    }
}

// MARK: - Voile de Confidentialité Multitâche iOS (App Switcher)

private struct WorkspaceMultitaskingPrivacyShieldView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            WorkspaceTheme.background(for: scheme)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                CenelisMonogramBadge(size: 62)

                Text("CENELIS WORKSPACE")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .tracking(2.0)
                    .foregroundStyle(WorkspaceTheme.primaryInk(for: scheme))

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12))
                    Text("Session protégée par Cenelis Connect PIN")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(WorkspaceTheme.secondaryInk(for: scheme))
            }
        }
    }
}
