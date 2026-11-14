import SwiftUI

// MARK: - Point d'Entrée Application iOS Native « Cenelis Academy » (com.cenelis.academy)

@main
public struct CenelisAcademyApp: App {
    @StateObject private var store = AcademyStoreViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            AcademySecurityRootContainerView(vm: store)
                .preferredColorScheme(store.themeMode.preferredColorScheme)
                .task {
                    await store.bootstrapOnLaunch()
                }
                .onOpenURL { url in
                    Task {
                        await store.handleIncomingURL(url)
                    }
                }
        }
    }
}
