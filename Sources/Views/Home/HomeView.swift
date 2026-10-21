import SwiftUI

// MARK: - Accueil Livria Store (Apple App ID: 6825159743 • Boutique Neuf & Occasion + Troc)

public struct HomeView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var selectedBook: LivriaBook? = nil
    @State private var showingISBNScanner: Bool = false

    public init() {}

    private var usedBooks: [LivriaBook] {
        store.books.filter { $0.hasUsedStock }
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroHeaderCard
                    quickModulesGrid
                    loobyPlusPromoBanner
                    tradeHighlightBanner

                    bookCarouselSection(
                        title: "Coups de cœur & Recommandations",
                        subtitle: "Sélection personnalisée Neuf & Occasion sur Livria Store",
                        icon: "sparkles",
                        books: store.homeData?.recommended ?? Array(store.books.prefix(8))
                    )

                    if !usedBooks.isEmpty {
                        bookCarouselSection(
                            title: "Livres d'Occasion Certifiés",
                            subtitle: "Seconde vie vérifiée via Viple Wingman à prix doux",
                            icon: "arrow.3.trianglepath",
                            books: usedBooks
                        )
                    }

                    bookCarouselSection(
                        title: "Nouveautés en Boutique",
                        subtitle: "Derniers ouvrages arrivés sur livria.store",
                        icon: "flame.fill",
                        books: store.homeData?.newest ?? Array(store.books.prefix(10))
                    )

                    bookCarouselSection(
                        title: "Petits Prix & Pépites",
                        subtitle: "Sélection à prix doux, livraison gratuite avec Looby+",
                        icon: "tag.fill",
                        books: store.homeData?.deals ?? Array(store.books.suffix(8))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Livria Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bag.fill")
                            .foregroundStyle(LivriaPalette.primary)
                        Text("Livria Store")
                            .font(.system(size: 19, weight: .black, design: .serif))
                            .foregroundStyle(LivriaPalette.ink)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            showingISBNScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(LivriaPalette.primary)
                        }

                        Button {
                            store.isShowingCartSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "cart.fill")
                                if store.cartItemsCount > 0 {
                                    Text("\(store.cartItemsCount)")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(LivriaPalette.coral))
                                        .foregroundStyle(.white)
                                }
                            }
                            .foregroundStyle(LivriaPalette.primary)
                        }
                    }
                }
            }
            .refreshable {
                await store.refreshBootstrap()
            }
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingISBNScanner) {
                LivriaISBNScannerSheet { foundBook in
                    selectedBook = foundBook
                }
                .environmentObject(store)
            }
        }
    }

    // MARK: - En-tête Utilisateur Viple Live ID / Invité (MeshGradient iOS 18+)

    private var heroHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                LevelRingView(
                    avatarUrl: store.currentUser?.avatarUrl,
                    displayName: store.currentUser?.displayName ?? "Lecteur",
                    level: store.currentUser?.level ?? 1,
                    xp: store.currentUser?.xp ?? 0,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bonjour, \(store.currentUser?.displayName ?? "Lecteur") 👋")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 5) {
                        Image(systemName: store.isAuthenticated ? "checkmark.seal.fill" : "cart.badge.clock")
                            .font(.caption)
                            .foregroundStyle(LivriaPalette.gold)
                        Text(store.isAuthenticated
                             ? "Membre Viple Live ID (\(store.currentUser?.email ?? ""))"
                             : "Achat sans compte activé • Apple Pay & Google Pay")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Label("\(store.currentUser?.xp ?? 0) XP", systemImage: "bolt.fill")
                        Label("\(store.currentUser?.loyaltyPoints ?? 0) pts", systemImage: "star.fill")
                        Label(String(format: "%.2f €", store.currentUser?.cashbackBalance ?? 0), systemImage: "eurosign.circle.fill")
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
                        Text("Se connecter avec Viple Live ID")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.28), radius: 14, x: 0, y: 6)
    }

    // MARK: - Grille d'Accès Rapide Livria Store (Boutique, Troc, Scanner ISBN, Looby+, Commandes, Relais, Jeux, Assistance)

    private var quickModulesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Livria Store & Troc")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                quickModulePill(title: "Boutique", icon: "bag.fill", color: LivriaPalette.primary) {
                    store.selectedMainTab = 1
                }
                quickModulePill(title: "Espace Troc", icon: "arrow.triangle.2.circlepath", color: .purple) {
                    store.selectedMainTab = 2
                }
                quickModulePill(title: "Scan ISBN", icon: "barcode.viewfinder", color: LivriaPalette.coral) {
                    showingISBNScanner = true
                }
                quickModulePill(title: "Looby+", icon: "crown.fill", color: LivriaPalette.gold) {
                    store.selectedMainTab = 3
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                NavigationLink {
                    OrdersView()
                } label: {
                    quickModuleLabel(title: "Commandes", icon: "shippingbox.fill", color: .teal)
                }
                NavigationLink {
                    RelayPointsView()
                } label: {
                    quickModuleLabel(title: "Relais & UPS", icon: "mappin.and.ellipse", color: .orange)
                }
                NavigationLink {
                    GamesHubView()
                } label: {
                    quickModuleLabel(title: "Jeux XP", icon: "gamecontroller.fill", color: .pink)
                }
                NavigationLink {
                    SupportAssistanceView()
                } label: {
                    quickModuleLabel(title: "Assistance", icon: "lifepreserver.fill", color: .red)
                }
            }
        }
    }

    private func quickModulePill(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickModuleLabel(title: title, icon: icon, color: color)
        }
        .buttonStyle(.plain)
    }

    private func quickModuleLabel(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LivriaPalette.cardPaper))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LivriaPalette.border, lineWidth: 1))
    }

    // MARK: - Bannière Looby+ (3,50 €/mois)

    private var loobyPlusPromoBanner: some View {
        Button {
            store.selectedMainTab = 3
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LivriaPalette.gold.opacity(0.25))
                        .frame(width: 48, height: 48)
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(LivriaPalette.gold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if store.currentUser?.isLivriaPlus == true {
                        Text("Espace Abonné Looby+ Actif")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Livraison 0 €, Box Surprise, Partage Familial & 5% Cashback")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.88))
                    } else {
                        Text("Découvrez Looby+ à 3,50 €/mois")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Livraison UPS 0 € dès 0,01 €, 1 crédit audio/mois, 5% cashback & Box Surprise")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(LivriaPalette.gold)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LivriaPalette.loobyPlusGradient)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bannière Troc Communautaire

    private var tradeHighlightBanner: some View {
        Button {
            store.selectedMainTab = 2
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.purple.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Troc de Livres entre Lecteurs (\(store.trades?.openOffers.count ?? 0) offres)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Échangez vos livres lus, scannez un ISBN et proposez un troc en 1 clic (+30 XP)")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
            }
            .livriaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Carrousels de Livres (Neuf & Occasion)

    private func bookCarouselSection(title: String, subtitle: String, icon: String, books: [LivriaBook]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundStyle(LivriaPalette.primary)
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Button("Boutique →") {
                    store.selectedMainTab = 1
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(books) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topLeading) {
                                    LivriaBookCoverView(
                                        coverUrl: book.coverUrl,
                                        title: book.title,
                                        width: 122,
                                        height: 176,
                                        cornerRadius: 14
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        if book.hasNewStock {
                                            Text("✨ Neuf")
                                                .font(.system(size: 9, weight: .heavy))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(Capsule().fill(LivriaPalette.mint))
                                                .foregroundStyle(.white)
                                        }
                                        if book.hasUsedStock {
                                            Text("♻️ \(book.usedConditionLabel)")
                                                .font(.system(size: 8.5, weight: .heavy))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(Capsule().fill(LivriaPalette.usedAmber))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(6)
                                }

                                Text(book.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                    .lineLimit(1)
                                    .frame(width: 122, alignment: .leading)

                                Text(book.author)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                    .lineLimit(1)
                                    .frame(width: 122, alignment: .leading)

                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        if book.hasNewStock {
                                            Text(String(format: "%.2f €", book.price))
                                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                                .foregroundStyle(LivriaPalette.primary)
                                        }
                                        if book.hasUsedStock {
                                            Text(String(format: "Occ. %.2f €", book.effectiveUsedPrice))
                                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(LivriaPalette.usedAmber)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        let formatToUse = book.hasNewStock ? "Broché" : book.cartFormatForUsed
                                        Task {
                                            await store.addToCart(bookId: book.id, format: formatToUse, quantity: 1)
                                        }
                                    } label: {
                                        Image(systemName: "cart.badge.plus")
                                            .font(.system(size: 13, weight: .bold))
                                            .padding(7)
                                            .background(Circle().fill(LivriaPalette.primarySoft))
                                            .foregroundStyle(LivriaPalette.primary)
                                    }
                                }
                                .frame(width: 122)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.cardPaper))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LivriaPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
