import SwiftUI

// MARK: - Point d'Entrée Principal @main de Livria Store (Apple App Store ID: 6825159743 • iOS 18.0+ / iOS 26.0+)

@main
public struct LivriaApp: App {
    @StateObject private var store = LivriaStoreViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
