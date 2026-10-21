import SwiftUI

// MARK: - Navigation Principale Native Livria Store (Apple App ID: 6825159743 • iOS 18+ & iOS 26 Liquid Glass TabView)

public struct MainTabView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $store.selectedMainTab) {
                HomeView()
                    .tabItem {
                        Label("Accueil", systemImage: "house.fill")
                    }
                    .tag(0)

                BoutiqueView()
                    .tabItem {
                        Label("Boutique", systemImage: "bag.fill")
                    }
                    .tag(1)

                TradeView()
                    .tabItem {
                        Label("Troc", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    }
                    .tag(2)

                LoobyPlusView()
                    .tabItem {
                        Label("Looby+", systemImage: "crown.fill")
                    }
                    .tag(3)

                LivriaStoreAccountHubView()
                    .tabItem {
                        Label("Compte & Suivi", systemImage: "person.crop.circle.fill")
                    }
                    .tag(4)
            }
            .tint(LivriaPalette.primary)

            // Toast de notification flottant
            if let toast = store.activeToastMessage {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(LivriaPalette.gold)
                    Text(toast)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(LivriaPalette.ink.opacity(0.94))
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }
        }
        .sheet(isPresented: $store.isShowingCartSheet) {
            CartView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.isShowingCheckoutSheet) {
            CheckoutView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.isShowingAuthSheet) {
            VipleLiveAuthView()
                .environmentObject(store)
        }
    }
}

// MARK: - Hub Compte & Services de Livria Store (Commandes UPS, Points Relais, Assistance Viple, Profil Viple Live ID)

public struct LivriaStoreAccountHubView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    identitySummaryCard

                    hubSectionLink(
                        title: "Mes Commandes & Suivi UPS / Viple Delivery",
                        subtitle: "Historique d'achats Neuf & Occasion, bordereaux UPS 1Z et suivi temps réel sur delivery.viplenetwork.com",
                        icon: "shippingbox.fill",
                        color: .teal
                    ) {
                        OrdersView()
                    }

                    hubSectionLink(
                        title: "Points Relais Communautaires & UPS Access Point™",
                        subtitle: "Boîtes à livres citoyennes, relais partenaires et outil officiel Viple Delivery",
                        icon: "mappin.and.ellipse",
                        color: .orange
                    ) {
                        RelayPointsView()
                    }

                    hubSectionLink(
                        title: "Assistance Viple (Synchronisée avec VipleAPI)",
                        subtitle: "Tickets synchronisés en temps réel entre assistance.viplenetwork.com et Livria Store",
                        icon: "lifepreserver.fill",
                        color: .red
                    ) {
                        SupportAssistanceView()
                    }

                    hubSectionLink(
                        title: "Mon Profil & Thèmes Viple Live ID",
                        subtitle: "Adresse d'expédition UPS par défaut, thèmes d'arrière-plan et préférences Viple Live ID",
                        icon: "person.text.rectangle.fill",
                        color: LivriaPalette.primary
                    ) {
                        ProfileView()
                    }

                    vipleAppsEcosystemBanner
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Compte & Suivi")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var identitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                LevelRingView(
                    avatarUrl: store.currentUser?.avatarUrl,
                    displayName: store.currentUser?.displayName ?? "Invité",
                    level: store.currentUser?.level ?? 1,
                    xp: store.currentUser?.xp ?? 0,
                    size: 66
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isAuthenticated ? (store.currentUser?.displayName ?? "Membre Livria") : "Session Invité Livria Store")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(store.isAuthenticated
                         ? "Viple Live ID • \(store.currentUser?.email ?? "")"
                         : "Commandez sans compte ou connectez votre Viple Live ID")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label("\(store.currentUser?.loyaltyPoints ?? 0) pts", systemImage: "star.fill")
                        Label(String(format: "%.2f € Cashback", store.currentUser?.cashbackBalance ?? 0), systemImage: "eurosign.circle.fill")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(LivriaPalette.goldSoft)
                }
                Spacer()
            }

            if !store.isAuthenticated {
                Button {
                    store.isShowingAuthSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Se connecter / Créer un compte Viple Live ID")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    private var vipleAppsEcosystemBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "app.badge.checkmark.fill")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Suite d'Applications iOS Viple")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Text("App ID 6825159743")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(LivriaPalette.primary)
            }

            Text("• Livria Store (cette application) : Achat de livres Neuf & Occasion, Troc, Looby+ & Suivi UPS.\n• Livria Social (application dédiée) : Réseau social littéraire, fil d'actu, listes rémunérées et messagerie.\n• Viple & Moi (application dédiée) : Tous vos espaces clients Viple dont votre espace « Ma Bibliothèque ».")
                .font(.system(size: 12))
                .foregroundStyle(LivriaPalette.inkMuted)
                .lineSpacing(3)
        }
        .livriaCard(padding: 14)
    }

    private func hubSectionLink<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
            .livriaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}
