import SwiftUI

// MARK: - Looby+ (Bientôt disponible dans l'application iOS)

public struct LoobyPlusView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    comingSoonHeroCard
                    comingSoonDetailsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Looby+")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var comingSoonHeroCard: some View {
        VStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LivriaPalette.gold.opacity(0.22))
                    .frame(width: 76, height: 76)
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(LivriaPalette.gold)
            }

            Label("BIENTÔT SUR IOS", systemImage: "sparkles")
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(LivriaPalette.gold))
                .foregroundStyle(.black)

            Text("Looby+ sera disponible prochainement dans l'appli iOS")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text("Nous préparons l'arrivée de l'expérience Looby+ directement au sein de votre application Livria Store pour iPhone et iPad.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LivriaPalette.loobyPlusGradient)
        )
        .shadow(color: LivriaPalette.primary.opacity(0.28), radius: 16, x: 0, y: 8)
    }

    private var comingSoonDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.sparkles.fill")
                    .font(.title3)
                    .foregroundStyle(LivriaPalette.primary)
                Text("Information")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
            }

            Text("Looby+ sera disponible prochainement dans l'appli iOS. En attendant, vous pouvez continuer à profiter de toute la librairie Livria Store (ouvrages neufs et d'occasion), du scan ISBN et de l'espace Troc entre lecteurs.")
                .font(.system(size: 13.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .lineSpacing(3)

            Button {
                store.selectedMainTab = 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill")
                    Text("Explorer la Boutique Livria")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LivriaPalette.primary)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .livriaCard()
    }
}

public struct LoobyPlusSubscriptionManagementView: View {
    public init() {}

    public var body: some View {
        LoobyPlusView()
    }
}
