import SwiftUI

// MARK: - Boutique Livria Store (Catalogue Neuf & Occasion + Recherche Double Livres / Membres + Scanner ISBN)

public struct BoutiqueView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum SearchScope: String, CaseIterable {
        case books = "📚 Livres"
        case members = "👥 Membres"
    }

    public enum ConditionFilter: String, CaseIterable {
        case all = "Tous états"
        case newOnly = "✨ Neuf"
        case usedOnly = "♻️ Occasion"
    }

    public enum SortOption: String, CaseIterable {
        case popular = "Pertinence"
        case priceAsc = "Prix croissant"
        case priceDesc = "Prix décroissant"
        case titleAz = "Titre A-Z"
    }

    @State private var searchScope: SearchScope = .books
    @State private var searchText: String = ""
    @State private var selectedGenre: String = "Tous"
    @State private var conditionFilter: ConditionFilter = .all
    @State private var sortOption: SortOption = .popular
    @State private var selectedBook: LivriaBook? = nil
    @State private var showingISBNScanner: Bool = false

    public init() {}

    private var filteredBooks: [LivriaBook] {
        var list = store.books

        switch conditionFilter {
        case .all:
            break
        case .newOnly:
            list = list.filter { $0.hasNewStock }
        case .usedOnly:
            list = list.filter { $0.hasUsedStock }
        }

        if selectedGenre != "Tous" {
            list = list.filter { $0.genre.localizedCaseInsensitiveContains(selectedGenre) }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.author.localizedCaseInsensitiveContains(q) ||
                $0.isbn.localizedCaseInsensitiveContains(q) ||
                $0.genre.localizedCaseInsensitiveContains(q)
            }
        }

        switch sortOption {
        case .popular:
            return list
        case .priceAsc:
            return list.sorted { $0.price < $1.price }
        case .priceDesc:
            return list.sorted { $0.price > $1.price }
        case .titleAz:
            return list.sorted { $0.title < $1.title }
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilterHeader

                if searchScope == .books {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(filteredBooks) { book in
                                boutiqueBookCard(book: book)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    memberSearchResultsView
                }
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingISBNScanner = true
                    } label: {
                        Label("ISBN", systemImage: "barcode.viewfinder")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingISBNScanner) {
                LivriaISBNScannerSheet { foundBook in
                    selectedBook = foundBook
                }
                .environmentObject(store)
            }
            .onChange(of: searchText) { _, newValue in
                if searchScope == .members {
                    Task {
                        await store.searchMembers(query: newValue)
                    }
                }
            }
            .onChange(of: searchScope) { _, newScope in
                if newScope == .members {
                    Task {
                        await store.searchMembers(query: searchText)
                    }
                }
            }
        }
    }

    // MARK: - En-tête de Recherche Double (📚 Livres / 👥 Membres) + Filtres Neuf/Occasion

    private var searchAndFilterHeader: some View {
        VStack(spacing: 10) {
            // Sélecteur Livres vs Membres
            Picker("Mode de recherche", selection: $searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LivriaPalette.primary)
                    TextField(
                        searchScope == .books
                            ? "Titre, auteur, ISBN (Neuf ou Occasion)..."
                            : "Rechercher un membre public Livria...",
                        text: $searchText
                    )
                    .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.cardPaper))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.border, lineWidth: 1))

                if searchScope == .books {
                    Button {
                        showingISBNScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft))
                            .foregroundStyle(LivriaPalette.primary)
                    }

                    Menu {
                        Picker("Tri", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }

            if searchScope == .books {
                // Filtre d'état Neuf / Occasion
                HStack(spacing: 8) {
                    ForEach(ConditionFilter.allCases, id: \.self) { cond in
                        let isSelected = conditionFilter == cond
                        Button {
                            conditionFilter = cond
                        } label: {
                            Text(cond.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        isSelected
                                            ? (cond == .usedOnly ? LivriaPalette.usedAmber : LivriaPalette.primary)
                                            : LivriaPalette.background
                                    )
                                )
                                .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                                .overlay(Capsule().stroke(LivriaPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                // Genres
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        genreChip("Tous")
                        ForEach(store.genres, id: \.self) { genre in
                            genreChip(genre)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LivriaPalette.cardPaper.opacity(0.95))
    }

    private func genreChip(_ genre: String) -> some View {
        let isSelected = selectedGenre == genre
        return Button {
            selectedGenre = genre
        } label: {
            Text(genre)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? LivriaPalette.primary : LivriaPalette.primarySoft.opacity(0.75))
                )
                .foregroundStyle(isSelected ? .white : LivriaPalette.primaryDeep)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Carte Livre Boutique (Neuf & Occasion)

    private func boutiqueBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                selectedBook = book
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        LivriaBookCoverView(
                            coverUrl: book.coverUrl,
                            title: book.title,
                            width: 144,
                            height: 204,
                            cornerRadius: 14
                        )
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            if book.hasNewStock {
                                Text("✨ Neuf")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(LivriaPalette.mint))
                            }
                            if book.hasUsedStock {
                                Text("♻️ \(book.usedConditionLabel)")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(LivriaPalette.usedAmber))
                            }
                        }
                        .padding(6)
                    }

                    Text(book.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)

                    // Affichage des prix Neuf et/ou Occasion
                    VStack(alignment: .leading, spacing: 2) {
                        if book.hasNewStock {
                            HStack(spacing: 4) {
                                Text("Neuf :")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                Text(String(format: "%.2f €", book.price))
                                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                        }
                        if book.hasUsedStock {
                            HStack(spacing: 4) {
                                Text("Occasion :")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LivriaPalette.usedAmber)
                                Text(String(format: "%.2f €", book.effectiveUsedPrice))
                                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(LivriaPalette.usedAmber)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            HStack {
                if book.hasNewStock && book.hasUsedStock {
                    Menu {
                        Button("✨ Ajouter Neuf (\(String(format: "%.2f €", book.price)))") {
                            Task {
                                await store.addToCart(bookId: book.id, format: "Broché", quantity: 1)
                            }
                        }
                        Button("♻️ Ajouter \(book.usedConditionLabel) (\(String(format: "%.2f €", book.effectiveUsedPrice)))") {
                            Task {
                                await store.addToCart(bookId: book.id, format: book.cartFormatForUsed, quantity: 1)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.fill")
                                .symbolRenderingMode(.monochrome)
                            Text("Choisir l'état")
                        }
                        .font(.system(size: 11.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                    }
                } else {
                    Button {
                        let fmt = book.hasNewStock ? "Broché" : book.cartFormatForUsed
                        Task {
                            await store.addToCart(bookId: book.id, format: fmt, quantity: 1)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.fill")
                                .symbolRenderingMode(.monochrome)
                            Text(book.hasNewStock ? "Ajouter (Neuf)" : "Ajouter (Occasion)")
                        }
                        .font(.system(size: 11.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(book.hasNewStock ? LivriaPalette.primary : LivriaPalette.usedAmber))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.cardPaper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LivriaPalette.border, lineWidth: 1))
        .shadow(color: LivriaPalette.primary.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    // MARK: - Résultats de Recherche de Membres Publics

    private var memberSearchResultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(store.searchedMembers) { member in
                    HStack(spacing: 14) {
                        LevelRingView(
                            avatarUrl: member.avatarUrl,
                            displayName: member.displayName,
                            level: member.level,
                            xp: member.xp,
                            size: 56
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(member.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                if member.isLivriaPlus {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2)
                                        .foregroundStyle(LivriaPalette.gold)
                                }
                            }
                            if !member.bio.isEmpty {
                                Text(member.bio)
                                    .font(.system(size: 12))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                    .lineLimit(2)
                            }
                            if !member.favoriteGenres.isEmpty {
                                Text("Genres : \(member.favoriteGenres)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                        }

                        Spacer()

                        if let url = URL(string: member.socialProfileUrl) {
                            Link(destination: url) {
                                Label("Profil", systemImage: "arrow.up.right.square.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                                    .foregroundStyle(LivriaPalette.primaryDeep)
                            }
                        }
                    }
                    .livriaCard(padding: 12)
                }
            }
            .padding(16)
        }
        .task {
            if store.searchedMembers.isEmpty {
                await store.searchMembers(query: searchText)
            }
        }
    }
}
