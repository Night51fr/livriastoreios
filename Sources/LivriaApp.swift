import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Point d'Entrée Principal @main de Livria Store (Apple App Store ID: 6825159743 • iOS 18.0+ / iOS 26.0+)

@main
public struct LivriaApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(LivriaAppDelegate.self) private var appDelegate
    #endif

    @StateObject private var store = LivriaStoreViewModel()
    @StateObject private var notifManager = LivriaNotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(notifManager)
                .preferredColorScheme(.light)
                .onAppear {
                    notifManager.attachedStore = store
                    if scenePhase != .background {
                        notifManager.enterForegroundMode()
                    } else {
                        notifManager.scheduleBackgroundTasks()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        notifManager.attachedStore = store
                        notifManager.enterForegroundMode()
                    case .inactive:
                        notifManager.handleSceneBecameInactive()
                    case .background:
                        notifManager.enterBackgroundMode()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
