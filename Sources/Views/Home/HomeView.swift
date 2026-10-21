import SwiftUI

// MARK: - Accueil Librairie Livria Store (Espace Home Éditorial + Algorithme de Recommandation Intelligent < 5 livres -> Plus Récents)

public struct HomeView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State private var selectedBook: LivriaBook? = nil
    @State private var showingISBNScanner: Bool = false
    @State private var selectedHomeGenre: String = "Tous"
    @State private var animateHero: Bool = false

    public init() {}

    private var usedBooks: [LivriaBook] {
        store.books.filter { $0.hasUsedStock }
    }

    private var featuredBook: LivriaBook? {
        store.smartRecommendationResult.books.first ?? store.books.first
    }

    private var genreFilteredBooks: [LivriaBook] {
        if selectedHomeGenre == "Tous" {
            return Array(store.books.prefix(10))
        }
        return store.books.filter {
            $0.displayGenre.localizedCaseInsensitiveCompare(selectedHomeGenre) == .orderedSame
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroWelcomeBanner

                    smartRecommendationSection

                    if let spotlight = featuredBook {
                        spotlightBookCard(book: spotlight)
                    }

                    genreExplorerSection

                    loobyPlusPromoBanner

                    if !usedBooks.isEmpty {
                        bookCarouselSection(
                            title: "Seconde Vie & Occasions",
                            subtitle: "Ouvrages d'occasion contrôlés et garantis à prix doux",
                            icon: "leaf.arrow.triangle.circlepath",
                            books: usedBooks
                        )
                    }

                    bookCarouselSection(
                        title: "Derniers livres ajoutés",
                        subtitle: "Les nouveautés tout juste arrivées en librairie",
                        icon: "sparkles.rectangle.stack.fill",
                        books: store.homeData?.newest ?? Array(store.books.sorted { $0.id > $1.id }.prefix(10))
                    )

                    bookCarouselSection(
                        title: "Petits Prix & Pépites",
                        subtitle: "De belles lectures à prix tout doux",
                        icon: "tag.fill",
                        books: store.homeData?.deals ?? Array(store.books.sorted { $0.price < $1.price }.prefix(8))
                    )

                    tradeCommunityBanner
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Livria Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(LivriaPalette.primary)
                        Text("Livria Store")
                            .font(.system(size: 19, weight: .black, design: .serif))
                            .foregroundStyle(LivriaPalette.ink)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingISBNScanner = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 15, weight: .bold))
                            Text("ISBN")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primaryDeep)
                    }

                    Button {
                        store.isShowingCartSheet = true
                    } label: {
                        if store.cartItemsCount > 0 {
                            Text("\(Image(systemName: "cart.fill")) \(store.cartItemsCount)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        } else {
                            Image(systemName: "cart.fill")
                        }
                    }
                    .tint(LivriaPalette.primary)
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
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6)) {
                    animateHero = true
                }
            }
        }
    }

    // MARK: - 1. En-tête d'Accueil Éditorial + Bouton Caméra Scan ISBN Direct

    private var heroWelcomeBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LevelRingView(
                    avatarUrl: store.currentUser?.avatarUrl,
                    displayName: store.currentUser?.displayName ?? "Lecteur",
                    level: store.currentUser?.level ?? 1,
                    xp: store.currentUser?.xp ?? 0,
                    size: 68
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Bonjour, \(store.currentUser?.displayName ?? "Lecteur") ✨")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(store.isAuthenticated
                         ? "Quelle sera votre prochaine lecture aujourd'hui ?"
                         : "Bienvenue dans votre librairie Neuf, Occasion & Troc")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Label("\(store.currentUser?.loyaltyPoints ?? 0) pts fidélité", systemImage: "star.fill")
                        Label(String(format: "%.2f € cagnotte", store.currentUser?.cashbackBalance ?? 0), systemImage: "eurosign.circle.fill")
                    }
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.goldSoft)
                }
                Spacer()
            }

            // Barre d'actions directe : Scanner un code-barres ISBN avec l'appareil photo ou parcourir la librairie
            HStack(spacing: 10) {
                Button {
                    showingISBNScanner = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 16, weight: .bold))
                        Text("Scanner un ISBN")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
                }

                Button {
                    store.selectedMainTab = 1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Explorer la Boutique")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.18)))
                    .foregroundStyle(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.26), radius: 14, x: 0, y: 6)
    }

    // MARK: - 2. Algorithme de Recommandation (< 5 livres -> Affiche les plus récemment ajoutés)

    private var smartRecommendationSection: some View {
        let rec = store.smartRecommendationResult
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: rec.isFallbackToRecent ? "clock.badge.sparkles.fill" : "wand.and.stars")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                        Text(rec.isFallbackToRecent ? "Derniers livres ajoutés" : "Recommandés pour vous")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                    }

                    Text(rec.subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }

                Spacer()

                Text(rec.isFallbackToRecent ? "Récents" : "Pour vous")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(rec.books) { book in
                        homeBookCard(book: book)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 3. Coup de Projecteur ("À la Une")

    private func spotlightBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("COUP DE CŒUR DU LIBRAIRE", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.goldSoft))
                    .foregroundStyle(Color(red: 0.58, green: 0.32, blue: 0.02))

                Spacer()

                Text(book.displayGenre)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }

            HStack(alignment: .top, spacing: 16) {
                Button {
                    selectedBook = book
                } label: {
                    LivriaBookCoverView(
                        coverUrl: book.coverUrl,
                        title: book.title,
                        width: 108,
                        height: 158,
                        cornerRadius: 14
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 7) {
                    Text(book.title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(2)

                    Text("de \(book.author)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)

                    Text(book.description)
                        .font(.system(size: 12.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(3)

                    HStack(spacing: 10) {
                        Text(String(format: "%.2f €", book.price))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.primary)

                        if book.hasUsedStock {
                            Text(String(format: "Occasion %.2f €", book.effectiveUsedPrice))
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(LivriaPalette.usedAmberSoft))
                                .foregroundStyle(LivriaPalette.usedAmber)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            selectedBook = book
                        } label: {
                            Text("Découvrir")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(LivriaPalette.primarySoft))
                                .foregroundStyle(LivriaPalette.primaryDeep)
                        }
                        .buttonStyle(.plain)

                        Button {
                            let fmt = book.hasNewStock ? "Broché" : book.cartFormatForUsed
                            Task {
                                await store.addToCart(bookId: book.id, format: fmt, quantity: 1)
                            }
                        } label: {
                            Label("Ajouter", systemImage: "cart.badge.plus")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .livriaCard(cornerRadius: 22, padding: 16)
    }

    // MARK: - 4. Exploration par Catégorie (Catégorie > 11 caractères -> "Inconnu")

    private var genreExplorerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "compass.drawing")
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Explorer par univers")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }
                Spacer()
                Button("Tout voir →") {
                    store.selectedMainTab = 1
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LivriaPalette.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    genrePill("Tous")
                    ForEach(store.genres, id: \.self) { g in
                        genrePill(g)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(genreFilteredBooks) { book in
                        homeBookCard(book: book)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func genrePill(_ genre: String) -> some View {
        let isSelected = selectedHomeGenre == genre
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedHomeGenre = genre
            }
        } label: {
            Text(genre)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? LivriaPalette.primary : LivriaPalette.cardPaper)
                )
                .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Bannière Looby+ (3,50 €/mois)

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
                        Text("Club Looby+ Actif")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Livraison 0 €, Box Surprise, Partage Familial & 5% Cashback")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.88))
                    } else {
                        Text("Rejoignez le Club Looby+ à 3,50 €/mois")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Livraison UPS 0 € dès le 1er livre, 1 livre audio offert/mois & 5% de cagnotte")
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

    // MARK: - 6. Bannière Troc Communautaire

    private var tradeCommunityBanner: some View {
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
                    Text("Troc de Livres entre Lecteurs (\(store.trades?.openOffers.count ?? 0) annonces)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Donnez une seconde vie à vos livres lus et échangez-les près de chez vous")
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

    // MARK: - Carrousels & Cartes de Livres

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
                        homeBookCard(book: book)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func homeBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                selectedBook = book
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .topLeading) {
                        LivriaBookCoverView(
                            coverUrl: book.coverUrl,
                            title: book.title,
                            width: 126,
                            height: 180,
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

                    Text(book.displayGenre)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(LivriaPalette.primarySoft))

                    Text(book.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(1)
                        .frame(width: 126, alignment: .leading)

                    Text(book.author)
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)
                        .frame(width: 126, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    if book.hasNewStock {
                        Text(String(format: "%.2f €", book.price))
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
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
                    Image(systemName: "cart.fill")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 13, weight: .bold))
                        .padding(7)
                        .background(Circle().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 126)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.cardPaper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LivriaPalette.border, lineWidth: 1))
    }
}
