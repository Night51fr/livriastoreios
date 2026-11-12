import SwiftUI

// MARK: - Coque de Navigation Principale Cenelis Academy (5 Onglets + Lecteur Natif Plein Écran + Modales Contextuelles)

public struct MainAcademyTabView: View {
    @ObservedObject var vm: AcademyStoreViewModel

    public init(vm: AcademyStoreViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $vm.activeTab) {
                HomeHubView(vm: vm)
                    .tabItem {
                        Label(AcademyMainTab.home.rawValue, systemImage: AcademyMainTab.home.sfSymbol)
                    }
                    .tag(AcademyMainTab.home)

                CoursesCatalogView(vm: vm)
                    .tabItem {
                        Label(AcademyMainTab.courses.rawValue, systemImage: AcademyMainTab.courses.sfSymbol)
                    }
                    .tag(AcademyMainTab.courses)

                MiniGamesArcadeView(vm: vm)
                    .tabItem {
                        Label(AcademyMainTab.arcade.rawValue, systemImage: AcademyMainTab.arcade.sfSymbol)
                    }
                    .tag(AcademyMainTab.arcade)

                ResourcesEncyclopediaView(vm: vm)
                    .tabItem {
                        Label(AcademyMainTab.resources.rawValue, systemImage: AcademyMainTab.resources.sfSymbol)
                    }
                    .tag(AcademyMainTab.resources)

                PassportProfileView(vm: vm)
                    .tabItem {
                        Label(AcademyMainTab.passport.rawValue, systemImage: AcademyMainTab.passport.sfSymbol)
                    }
                    .tag(AcademyMainTab.passport)
            }
            .tint(AcademyPalette.pine)

            // Lecteur de cours natif superposé en transition fluide (évite tout conflit de feuilles modales imbriquées)
            if let activeCourse = vm.activeCourse {
                NativeCourseReaderView(course: activeCourse, vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(10)
            }

            // Notification flottante de gain d'XP (+25 XP, +40 XP, +300 XP, Trophées…)
            if let toast = vm.xpToast {
                FloatingXPToastView(item: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(30)
            }

            // Pluie de confettis Motion Design lors des paliers majeurs (80 % Apte, 100 %, Nouveau Rang, Arcade)
            ConfettiBurstOverlayView(trigger: vm.confettiTrigger)
                .zIndex(40)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: vm.activeCourseId)
        .sheet(item: $vm.activeBubble) { bubble in
            BubbleExplainerSheet(bubble: bubble)
        }
        .sheet(item: $vm.activeDeepDive) { dive in
            DeepDiveReaderSheet(dive: dive, vm: vm)
        }
        .fullScreenCover(item: $vm.activeLightboxShot) { shot in
            ScreenshotLightboxSheet(context: shot)
        }
        .sheet(isPresented: $vm.isShowingSearch) {
            GlobalSearchSheet(vm: vm)
        }
        .sheet(isPresented: $vm.isShowingAuthSheet) {
            AcademyAuthSheet(vm: vm)
        }
    }
}
