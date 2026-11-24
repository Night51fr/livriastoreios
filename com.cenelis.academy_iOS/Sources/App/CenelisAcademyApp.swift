import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Point d'Entrée Application iOS Native « Cenelis Academy » (com.cenelis.academy)

@main
public struct CenelisAcademyApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AcademyAppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AcademyStoreViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            AcademySecurityRootContainerView(vm: store)
                .preferredColorScheme(store.themeMode.preferredColorScheme)
                .task {
                    AcademyNotificationManager.shared.bind(to: store)
                    await store.bootstrapOnLaunch()
                }
                .onOpenURL { url in
                    Task {
                        await store.handleIncomingURL(url)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        AcademyNotificationManager.shared.clearBadgeCount()
                    case .background:
                        AcademyNotificationManager.shared.scheduleNextBackgroundRefresh()
                    default:
                        break
                    }
                }
        }
    }
}
