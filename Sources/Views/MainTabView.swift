import SwiftUI
import UIKit

// MARK: - Navigation Principale Native Livria Store

public struct MainTabView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            if store.paymentSettings.mobileAppMaintenanceEnabled {
                LivriaStoreMaintenanceView()
                    .environmentObject(store)
                    .transition(.opacity)
            } else if store.isInitialBootstrapping {
                LivriaStoreLoadingSplashView()
                    .environmentObject(store)
                    .transition(.opacity)
            } else if store.isServerUnreachable && store.books.isEmpty {
                LivriaStoreServerLunchBreakView()
                    .environmentObject(store)
                    .transition(.opacity)
            } else if !store.hasAcceptedTermsOfUse {
                LivriaStoreLegalTermsView(isFirstLaunchGate: true)
                    .environmentObject(store)
                    .transition(.opacity)
            } else {
                mainAppContent
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await store.refreshPaymentSettings()
                    await store.checkCrossAppVipleAccount()
                }
            }
        }
        .onOpenURL { url in
            store.handleIncomingURL(url)
        }
    }

    private var mainAppContent: some View {
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
                        Label("Mon Profil", systemImage: "person.crop.circle.fill")
                    }
                    .tag(4)
            }
            .tint(LivriaPalette.primary)
            .onChange(of: store.selectedMainTab) { _, newTab in
                Task {
                    await store.refreshPaymentSettings()
                }
                if !store.isAuthenticated && (newTab == 2 || newTab == 3) {
                    store.isShowingAuthSheet = true
                }
            }

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

            // Proposition automatique de connexion Viple Live ID inter-applications (depuis Livria Social)
            if store.isShowingCrossAppSSOPrompt, let account = store.detectedCrossAppAccount {
                LivriaStoreCrossAppSSOPromptView(account: account)
                    .environmentObject(store)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(150)
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
        .sheet(isPresented: $store.isShowingTermsReviewSheet) {
            LivriaStoreLegalTermsView(isFirstLaunchGate: false)
                .environmentObject(store)
        }
        .sheet(item: $store.scannedBookForDetail) { scannedBook in
            ZStack {
                NavigationStack {
                    BookDetailView(book: scannedBook)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Fermer") {
                                    store.scannedBookForDetail = nil
                                }
                            }
                        }
                }

                if store.isShowingCrossAppSSOPrompt, let account = store.detectedCrossAppAccount {
                    LivriaStoreCrossAppSSOPromptView(account: account)
                        .environmentObject(store)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(150)
                }
            }
            .environmentObject(store)
        }
    }
}

// MARK: - Proposition Automatique de Connexion Inter-Application (« Nous avons détecté que vous étiez connecté depuis Livria Social... »)

public struct LivriaStoreCrossAppSSOPromptView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    public let account: LivriaCrossAppAccount

    public init(account: LivriaCrossAppAccount) {
        self.account = account
    }

    private var fullNameLine: String {
        let combined = "\(account.firstName) \(account.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture {
                    store.dismissCrossAppPrompt()
                }

            VStack(spacing: 18) {
                // Badge Viple Live ID Inter-Apps
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                    Text("CONNEXION AUTOMATIQUE VIPLE LIVE ID")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.primaryDeep)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(LivriaPalette.primarySoft))

                // Texte exact demandé par l'utilisateur
                VStack(spacing: 8) {
                    Text("Nous avons détecté que vous étiez connecté depuis \(account.sourceApp)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                        .multilineTextAlignment(.center)

                    Text("Souhaitez-vous vous connecter au même compte avec Livria Store ?")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                // Carte Profil Viple (Photo de profil, Nom du compte, Nom/Prénom, Email, Niveau/XP, Badge Looby+)
                HStack(spacing: 14) {
                    LevelRingView(
                        avatarUrl: account.avatarUrl,
                        displayName: account.displayName,
                        level: max(1, account.level),
                        xp: max(0, account.xp),
                        size: 68
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(account.displayName)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(LivriaPalette.ink)
                                .lineLimit(1)

                            if account.isLivriaPlus {
                                Label("Looby+", systemImage: "crown.fill")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(LivriaPalette.goldSoft))
                                    .foregroundStyle(LivriaPalette.gold)
                            }
                        }

                        if !fullNameLine.isEmpty && fullNameLine.lowercased() != account.displayName.lowercased() {
                            Text(fullNameLine)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LivriaPalette.ink.opacity(0.85))
                                .lineLimit(1)
                        }

                        Text(account.email)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Label("Niveau \(max(1, account.level))", systemImage: "sparkles")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.primary)

                            Text("•")
                                .foregroundStyle(LivriaPalette.inkMuted)

                            Text("\(max(0, account.xp)) XP")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.coral)
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LivriaPalette.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LivriaPalette.primary.opacity(0.22), lineWidth: 1.2)
                )

                // Boutons d'action
                VStack(spacing: 10) {
                    Button {
                        Task {
                            await store.acceptDetectedCrossAppAccount()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if store.isAcceptingCrossAppSSO {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text("Continuer en tant que \(account.displayName)")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [LivriaPalette.primary, LivriaPalette.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: LivriaPalette.primary.opacity(0.32), radius: 10, x: 0, y: 4)
                    }
                    .disabled(store.isAcceptingCrossAppSSO)

                    Button {
                        store.dismissCrossAppPrompt()
                    } label: {
                        Text("Non merci, rester sur la session actuelle")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .disabled(store.isAcceptingCrossAppSSO)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LivriaPalette.cardPaper)
                    .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Écran de Chargement Livria Store (Logo « Livria » sur fond transparent + Texte + Icône de chargement animée)

public struct LivriaStoreLoadingSplashView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var isSpinning: Bool = false
    @State private var isPulsing: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 26) {
                Spacer()

                // 1. Logo « Livria » au-dessus (fond transparent)
                Group {
                    if let uiImage = UIImage(named: "LivriaLogoTransparent") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 82)
                    } else if let horizontalImg = UIImage(named: "LivriaStoreLogoHorizontal") {
                        Image(uiImage: horizontalImg)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 62)
                    } else {
                        Text("Livria")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 124.0 / 255.0, green: 77.0 / 255.0, blue: 1.0),
                                        Color(red: 1.0, green: 95.0 / 255.0, blue: 162.0 / 255.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .scaleEffect(isPulsing ? 1.03 : 0.97)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

                // 2. Texte d'accroche au centre
                Text("Mais sur quelles pépites allons-nous encore tomber !?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)

                // 3. Icône de chargement animée en dessous de tout ça
                ZStack {
                    Circle()
                        .stroke(LivriaPalette.primary.opacity(0.16), lineWidth: 4.5)
                        .frame(width: 54, height: 54)

                    Circle()
                        .trim(from: 0.08, to: 0.78)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    LivriaPalette.primary,
                                    LivriaPalette.coral,
                                    LivriaPalette.primary
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)

                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [LivriaPalette.primary, LivriaPalette.coral],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isPulsing ? 1.12 : 0.90)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
                }
                .padding(.top, 6)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .livriaThemedBackground(store.currentThemeId)
        .onAppear {
            isSpinning = true
            isPulsing = true
        }
    }
}

// MARK: - Écran « Maintenance en cours » (Contrôlé en direct depuis /admin sur Livria)

public struct LivriaStoreMaintenanceView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public init() {}

    public var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Text("Maintenance en cours")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .task {
            while !Task.isCancelled && store.paymentSettings.mobileAppMaintenanceEnabled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                await store.refreshPaymentSettings()
            }
        }
    }
}

// MARK: - Écran Serveur Indisponible / Timeout 20s / Erreur 503 (« Notre serveur est a sa pause dejeuner... »)

public struct LivriaStoreServerLunchBreakView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var isRetrying: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 22) {
                if let uiImage = UIImage(named: "LivriaLogoTransparent") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 68)
                }

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Notre serveur est a sa pause dejeuner, Merci de revenir une fois le serveur rétabli.")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Button {
                    isRetrying = true
                    Task {
                        await store.refreshBootstrap()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Réessayer")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .disabled(isRetrying)
            }
        }
    }
}

// MARK: - Mon Profil & Mon Espace Livria Store (Intuitif, Complet, Animé & Grand Public)

public struct LivriaStoreAccountHubView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var showingISBNScanner: Bool = false
    @State private var scannedBookDestination: LivriaBook? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    identitySummaryCard

                    quickShortcutsSection

                    ordersAndDeliverySection

                    bookstoreServicesSection

                    if store.isAuthenticated {
                        appearanceAndThemeSection
                    }

                    helpAndAccountSection
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle(store.isAuthenticated ? "Mon Profil" : "Menu Invité")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $scannedBookDestination) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingISBNScanner) {
                LivriaISBNScannerSheet { foundBook in
                    scannedBookDestination = foundBook
                }
                .environmentObject(store)
            }
        }
    }

    // MARK: - 1. Carte Profil & Fidélité

    private var identitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                LevelRingView(
                    avatarUrl: store.currentUser?.avatarUrl,
                    displayName: store.currentUser?.displayName ?? "Invité",
                    level: store.currentUser?.level ?? 1,
                    xp: store.currentUser?.xp ?? 0,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(store.isAuthenticated ? (store.currentUser?.displayName ?? "Membre Livria") : "Bienvenue sur Livria")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        if store.currentUser?.isLivriaPlus == true {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(LivriaPalette.gold)
                        }
                    }

                    Text(store.isAuthenticated
                         ? (store.currentUser?.email ?? "")
                         : "Connectez-vous pour retrouver vos commandes et vos avantages")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Label("\(store.currentUser?.loyaltyPoints ?? 0) pts", systemImage: "star.fill")
                        Label(String(format: "%.2f € cagnotte", store.currentUser?.cashbackBalance ?? 0), systemImage: "eurosign.circle.fill")
                        Label("\(store.orders.count) cmd", systemImage: "shippingbox.fill")
                    }
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.goldSoft)
                }
                Spacer()
            }

            if store.isAuthenticated {
                NavigationLink {
                    ProfileView()
                } label: {
                    HStack {
                        Image(systemName: "pencil.line")
                        Text("Modifier mes informations et mon adresse")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                }
            } else {
                Button {
                    store.isShowingAuthSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Se connecter ou créer mon compte")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
                }
            }
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    // MARK: - 2. Grille d'Accès Rapide Intuitive

    private var quickShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accès rapide")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                NavigationLink {
                    OrdersView()
                } label: {
                    shortcutTile(title: "Commandes", subtitle: "\(store.orders.count) suivi(s)", icon: "shippingbox.fill", color: .teal)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RelayPointsView()
                } label: {
                    shortcutTile(title: "Points Relais", subtitle: "Autour de moi", icon: "mappin.and.ellipse", color: .orange)
                }
                .buttonStyle(.plain)

                Button {
                    showingISBNScanner = true
                } label: {
                    shortcutTile(title: "Scan ISBN", subtitle: "Appareil photo", icon: "camera.viewfinder", color: LivriaPalette.coral)
                }
                .buttonStyle(.plain)

                Button {
                    store.openLivriaMarketplaceApp()
                } label: {
                    shortcutTile(title: "Marketplace", subtitle: "Acheter & Vendre", icon: "storefront.fill", color: LivriaPalette.primary)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    VipleTakerApplicationView()
                } label: {
                    shortcutTile(title: "Viple Taker", subtitle: "Relais 1€/colis", icon: "shippingbox.and.arrow.backward.fill", color: LivriaPalette.mint)
                }
                .buttonStyle(.plain)

                if store.isAuthenticated {
                    Button {
                        store.selectedMainTab = 2
                    } label: {
                        shortcutTile(title: "Espace Troc", subtitle: "Échanges", icon: "arrow.triangle.2.circlepath", color: .purple)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.selectedMainTab = 3
                    } label: {
                        shortcutTile(title: "Club Looby+", subtitle: "Avantages", icon: "crown.fill", color: LivriaPalette.gold)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SupportAssistanceView()
                    } label: {
                        shortcutTile(title: "Assistance", subtitle: "Service client", icon: "bubble.left.and.bubble.right.fill", color: LivriaPalette.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func shortcutTile(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LivriaPalette.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.cardPaper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LivriaPalette.border, lineWidth: 1))
    }

    // MARK: - 3. Section Achats, Commandes & Livraison

    private var ordersAndDeliverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mes achats & livraisons")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            VStack(spacing: 10) {
                hubSectionLink(
                    title: "Mes Commandes & Bordereaux UPS",
                    subtitle: "Suivre vos colis en direct, afficher votre bordereau d'expédition ou annuler une commande",
                    icon: "shippingbox.fill",
                    color: .teal
                ) {
                    OrdersView()
                }

                hubSectionLink(
                    title: "Points Relais UPS & Boîtes à Livres",
                    subtitle: "Localisez les points relais autour de vous ou recherchez par code postal",
                    icon: "location.magnifyingglass",
                    color: .orange
                ) {
                    RelayPointsView()
                }

                hubSectionLink(
                    title: "Devenir Viple Taker (Point Relais Particulier — 1 €/colis)",
                    subtitle: "Recevez les colis Viple Delivery & UPS chez vous, scannez via Looby Taker et gagnez 1,00 € par colis remis",
                    icon: "shippingbox.and.arrow.backward.fill",
                    color: LivriaPalette.mint
                ) {
                    VipleTakerApplicationView()
                }

                if store.isAuthenticated {
                    hubSectionLink(
                        title: "Mon Adresse de Livraison & Coordonnées",
                        subtitle: "Gérez votre adresse postale et votre numéro de téléphone pour vos colis",
                        icon: "house.and.flag.fill",
                        color: .indigo
                    ) {
                        ProfileView()
                    }
                }
            }
        }
    }

    // MARK: - 4. Section Librairie, Scan ISBN, Troc & Looby+

    private var bookstoreServicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mes services librairie")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            VStack(spacing: 10) {
                Button {
                    showingISBNScanner = true
                } label: {
                    hubActionRow(
                        title: "Scanner le code-barres d'un livre (ISBN)",
                        subtitle: "Ouvre directement l'appareil photo pour trouver un livre dans le catalogue",
                        icon: "camera.viewfinder",
                        color: LivriaPalette.coral
                    )
                }
                .buttonStyle(.plain)

                if store.isAuthenticated {
                    Button {
                        store.selectedMainTab = 3
                    } label: {
                        hubActionRow(
                            title: "Abonnement Club Looby+ (3,49 €/mois)",
                            subtitle: "Livraison 0 €, 1 livre audio offert par mois, 5% de cagnotte et partage familial",
                            icon: "crown.fill",
                            color: LivriaPalette.gold
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.selectedMainTab = 2
                    } label: {
                        hubActionRow(
                            title: "Mes Échanges & Espace Troc",
                            subtitle: "Proposez vos livres lus et suivez vos demandes d'échange entre lecteurs",
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5. Section Apparence & Thèmes en 1 clic

    private var appearanceAndThemeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ambiance & couleurs de l'application")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                NavigationLink("Tous les thèmes →") {
                    ProfileView()
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LivriaSiteThemeOption.all) { opt in
                        let isSelected = store.currentThemeId == opt.id
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.setTheme(opt.id)
                            }
                            if store.isAuthenticated, let u = store.currentUser {
                                Task {
                                    await store.updateProfile(
                                        displayName: u.displayName,
                                        bio: u.bio,
                                        motto: u.motto,
                                        favoriteGenres: u.favoriteGenres,
                                        yearlyGoal: max(1, u.yearlyGoal),
                                        themeId: opt.id,
                                        firstName: u.firstName,
                                        lastName: u.lastName,
                                        phone: u.phone,
                                        address: u.address,
                                        postalCode: u.postalCode,
                                        city: u.city
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(LinearGradient(colors: opt.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Image(systemName: opt.icon)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(LivriaPalette.ink)
                                    )
                                Text(opt.name)
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(isSelected ? LivriaPalette.primary : LivriaPalette.cardPaper)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 6. Section Aide, Service Client & Compte

    private var helpAndAccountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aide & compte")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            VStack(spacing: 10) {
                hubSectionLink(
                    title: "Aide & Service Client",
                    subtitle: "Une question sur une commande ou une livraison ? Écrivez à notre équipe",
                    icon: "lifepreserver.fill",
                    color: .red
                ) {
                    SupportAssistanceView()
                }

                if store.isAuthenticated {
                    hubSectionLink(
                        title: "Préférences & Profil Complet",
                        subtitle: "Biographie de lecteur, objectif annuel de lecture et paramètres",
                        icon: "person.text.rectangle.fill",
                        color: LivriaPalette.primary
                    ) {
                        ProfileView()
                    }
                }

                Button {
                    store.isShowingTermsReviewSheet = true
                } label: {
                    hubActionRow(
                        title: "Conditions Générales d'Utilisation & de Vente",
                        subtitle: "Consultez à tout moment les conditions générales Livria et Viple Live ID",
                        icon: "doc.text.magnifyingglass",
                        color: .teal
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hubSectionLink<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            hubActionRow(title: title, subtitle: subtitle, icon: icon, color: color)
        }
        .buttonStyle(.plain)
    }

    private func hubActionRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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
}
