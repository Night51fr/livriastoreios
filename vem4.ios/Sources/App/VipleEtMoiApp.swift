import SwiftUI

@main
struct VipleEtMoiApp: App {
    @State private var store = VemStoreViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                Group {
                    if store.isAuthenticated {
                        MainVemTabView(store: store)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        VemAuthLandingView(store: store)
                            .transition(.opacity)
                    }
                }

                // Floating Toast Banner
                if let banner = store.toast {
                    HStack(spacing: 10) {
                        Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(banner.message)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(banner.isError ? Color(red: 0.62, green: 0.11, blue: 0.14) : VemTheme.vipleEmerald)
                            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 8)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(90)
                }

                // Celebration Confetti Overlay
                VemConfettiOverlay(trigger: store.confettiCounter)
                    .zIndex(100)
            }
            .onOpenURL { url in
                Task {
                    await store.handleIncomingURL(url)
                }
            }
        }
    }
}
