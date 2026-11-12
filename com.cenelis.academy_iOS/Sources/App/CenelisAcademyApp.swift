import SwiftUI

// MARK: - Point d'Entrée Application iOS Native « Cenelis Academy » (com.cenelis.academy)

@main
public struct CenelisAcademyApp: App {
    @StateObject private var store = AcademyStoreViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ZStack {
                MainAcademyTabView(vm: store)
                    .opacity(store.isInitialBooting ? 0 : 1)

                if store.isInitialBooting {
                    AcademyLaunchSplashView()
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                        .zIndex(50)
                }
            }
            .preferredColorScheme(store.themeMode.preferredColorScheme)
            .task {
                await store.bootstrapOnLaunch()
            }
            .onOpenURL { url in
                Task {
                    await store.handleSSOCallbackURL(url)
                }
            }
        }
    }
}
