import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Boutique Livria Store (Catalogue Neuf & Occasion + Recherche Double Livres / Membres + Scanner ISBN)

public struct BoutiqueView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum SearchScope: String, CaseIterable {
        case books = "Livres"
        case members = "Membres"

        public var iconName: String {
            switch self {
            case .books: return "book"
            case .members: return "person.2"
            }
        }
    }

    public enum ConditionFilter: String, CaseIterable {
        case all = "Tous états"
        case favoritesOnly = "Favoris"
        case newOnly = "Neuf"
        case usedOnly = "Occasion"
        case digitalOnly = "Audio / E-Book"

        public var iconName: String? {
            switch self {
            case .all: return nil
            case .favoritesOnly: return "heart"
            case .newOnly: return "tag"
            case .usedOnly: return "arrow.triangle.2.circlepath"
            case .digitalOnly: return "headphones"
            }
        }
    }

    public enum SortOption: String, CaseIterable {
        case popular = "Pertinence"
        case newest = "Nouveautés"
        case priceAsc = "Prix croissant"
        case priceDesc = "Prix décroissant"
        case titleAz = "Titre A-Z"
    }

    private struct BoutiqueScrollMetrics: Equatable, Sendable {
        var offsetY: CGFloat
        var maxScrollY: CGFloat
        var viewportHeight: CGFloat
    }

    @State private var searchScope: SearchScope = .books
    @State private var searchText: String = ""
    @State private var selectedGenre: String = "Tous"
    @State private var conditionFilter: ConditionFilter = .all
    @State private var sortOption: SortOption = .popular
    @State private var maxPriceCeiling: Double = 0 // 0 = sans plafond
    @State private var selectedBook: LivriaBook? = nil
    @State private var showingISBNScanner: Bool = false
    @State private var showingLoobySocialWaitAlert: Bool = false
    @State private var pendingWebMemberProfileUrl: String = ""

    // États d'affichage dynamique du panneau Recherche + Filtres au swipe
    @State private var isScrolledPastTop: Bool = false
    @State private var isManuallyExpanded: Bool = false
    @State private var isForceCollapsedBySwipe: Bool = false
    @State private var isFingerTouchingScroll: Bool = false
    @State private var isUserScrollGestureActive: Bool = false
    @State private var dragStartOffsetY: CGFloat = 0
    @State private var currentScrollOffsetY: CGFloat = 0
    @State private var measuredBooksDrawerHeight: CGFloat = 148
    @State private var measuredMembersDrawerHeight: CGFloat = 64
    @State private var scrollViewportHeight: CGFloat = 520
    @FocusState private var isSearchFieldFocused: Bool

    public init() {}

    private var isFilterDrawerExpanded: Bool {
        if isManuallyExpanded {
            return true
        }
        if isForceCollapsedBySwipe {
            return false
        }
        return !isScrolledPastTop
    }

    private var hasActiveSearchOrFilter: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        conditionFilter != .all ||
        selectedGenre != "Tous" ||
        maxPriceCeiling > 0 ||
        sortOption != .popular
    }

    private var activeDrawerSpacerHeight: CGFloat {
        if isForceCollapsedBySwipe && !isManuallyExpanded {
            return 14
        }
        let base = searchScope == .books ? measuredBooksDrawerHeight : measuredMembersDrawerHeight
        return base + 14
    }

    private var filteredBooks: [LivriaBook] {
        var list = store.books

        switch conditionFilter {
        case .all:
            break
        case .favoritesOnly:
            list = list.filter { store.isFavoriteBook($0.id) }
        case .newOnly:
            list = list.filter { $0.hasNewStock }
        case .usedOnly:
            list = list.filter { $0.hasUsedStock }
        case .digitalOnly:
            list = list.filter { $0.hasAudio || $0.hasEpub }
        }

        if maxPriceCeiling > 0 {
            list = list.filter {
                let effectiveMin = $0.hasUsedStock ? min($0.price, $0.effectiveUsedPrice) : $0.price
                return effectiveMin <= maxPriceCeiling
            }
        }

        if selectedGenre != "Tous" {
            list = list.filter {
                $0.displayGenre.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame ||
                $0.genre.localizedCaseInsensitiveContains(selectedGenre)
            }
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
        case .newest:
            return list.sorted { $0.id > $1.id }
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
                persistentScopeHeader
                    .zIndex(20)

                ZStack(alignment: .top) {
                    if searchScope == .books {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: activeDrawerSpacerHeight)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isForceCollapsedBySwipe)

                                boutiqueDailyReleasesBanner
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)

                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                                    ForEach(filteredBooks) { book in
                                        boutiqueBookCard(book: book)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 100)
                            }
                            .frame(minHeight: scrollViewportHeight + 2, alignment: .top)
                        }
                        .onScrollPhaseChange { oldPhase, newPhase in
                            handleScrollPhaseChange(from: oldPhase, to: newPhase)
                        }
                        .onScrollGeometryChange(for: BoutiqueScrollMetrics.self) { geo in
                            let rawY = geo.contentOffset.y + geo.contentInsets.top
                            let maxScroll = max(0, geo.contentSize.height - geo.containerSize.height)
                            return BoutiqueScrollMetrics(
                                offsetY: (rawY * 2).rounded() / 2,
                                maxScrollY: (maxScroll * 2).rounded() / 2,
                                viewportHeight: max(320, (geo.containerSize.height * 2).rounded() / 2)
                            )
                        } action: { _, metrics in
                            handleScrollMetricsUpdate(metrics)
                        }
                    } else {
                        memberSearchResultsView
                    }

                    // Tiroir rétractable : barre de recherche + catégories d'état + genres (se retire vers le haut au swipe)
                    VStack(spacing: 0) {
                        if isFilterDrawerExpanded {
                            expandableSearchAndCategoriesContent
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    )
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .clipped()
                    .zIndex(10)
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
                    store.trackUserActivity(
                        eventType: "isbn_scan",
                        category: "Livres & Fiches consultées",
                        subCategory: "Scan code-barres ISBN",
                        actionLabel: "Livre scanné via ISBN : « \(foundBook.title) »",
                        detail: "ISBN \(foundBook.isbn)",
                        book: foundBook,
                        screen: "ios://livria/boutique/isbn-scan"
                    )
                    selectedBook = foundBook
                }
                .environmentObject(store)
            }
            .task(id: searchText) {
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard q.count >= 2 else { return }
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard !Task.isCancelled else { return }
                store.trackUserActivity(
                    eventType: searchScope == .books ? "search" : "member_search",
                    category: "Recherches & Filtres",
                    subCategory: searchScope == .books ? "Recherche de livres" : "Recherche de membres",
                    actionLabel: "Recherche \(searchScope.rawValue) : « \(q) »",
                    detail: searchScope == .books ? "\(filteredBooks.count) ouvrage(s) correspondant(s)" : "\(store.searchedMembers.count) membre(s) trouvé(s)",
                    itemTitle: q,
                    screen: "ios://livria/boutique/search"
                )
            }
            .onChange(of: searchText) { _, newValue in
                if searchScope == .members {
                    Task {
                        await store.searchMembers(query: newValue)
                    }
                }
            }
            .onChange(of: searchScope) { _, newScope in
                withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                    isScrolledPastTop = false
                    isManuallyExpanded = false
                    isForceCollapsedBySwipe = false
                }
                store.trackUserActivity(
                    eventType: "tab_switch",
                    category: "Navigation & Pages visitées",
                    subCategory: "Sous-onglet Boutique",
                    actionLabel: "Bascule Boutique vers « \(newScope.rawValue) »",
                    itemTitle: newScope.rawValue,
                    screen: "ios://livria/boutique/\(newScope == .books ? "livres" : "membres")"
                )
                if newScope == .members {
                    Task {
                        await store.searchMembers(query: searchText)
                    }
                }
            }
            .onChange(of: sortOption) { _, newSort in
                store.trackUserActivity(
                    eventType: "sort_change",
                    category: "Recherches & Filtres",
                    subCategory: "Tri du catalogue",
                    actionLabel: "Tri appliqué : \(newSort.rawValue)",
                    itemTitle: newSort.rawValue,
                    screen: "ios://livria/boutique/sort"
                )
            }
            .alert("LoobySocial", isPresented: $showingLoobySocialWaitAlert) {
                if let webUrl = URL(string: pendingWebMemberProfileUrl), !pendingWebMemberProfileUrl.isEmpty {
                    Button("Consulter sur le site web") {
                        #if canImport(UIKit)
                        UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("LoobySocial devrais arrivé sur l'App Store, en attendant : vous pouvez consulter les profils sur le site web de Livria")
            }
        }
    }

    // MARK: - Gestion du Swipe / Scroll pour replier ou restaurer le menu Recherche & Catégories

    private var boutiqueDailyReleasesBanner: some View {
        let count = store.todayNewReleasesCount
        return Button {
            store.openDailyReleases()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(
                            colors: [LivriaPalette.primary, LivriaPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("✨ Les nouvelles sorties du jour")
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(1)
                    Text(count > 0
                         ? "\(count) parution\(count > 1 ? "s" : "") ajoutée\(count > 1 ? "s" : "") aujourd'hui"
                         : "Voir les arrivages du jour & nouveautés récentes")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)
                }

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LivriaPalette.coral))
                        .foregroundStyle(.white)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LivriaPalette.cardPaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(LivriaPalette.primary.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleScrollPhaseChange(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
        if newPhase == .interacting {
            isFingerTouchingScroll = true
            isUserScrollGestureActive = true
            dragStartOffsetY = currentScrollOffsetY
        } else if newPhase == .decelerating {
            isFingerTouchingScroll = false
        } else if newPhase == .idle {
            isFingerTouchingScroll = false
            isUserScrollGestureActive = false
        }
    }

    private func handleScrollMetricsUpdate(_ metrics: BoutiqueScrollMetrics) {
        if abs(metrics.viewportHeight - scrollViewportHeight) > 4 {
            scrollViewportHeight = metrics.viewportHeight
        }
        let y = metrics.offsetY
        currentScrollOffsetY = y
        let deltaFromDragStart = y - dragStartOffsetY

        // 1. Si on reswipe tout tout en haut -> remet automatiquement tout le menu et retire l'icône loupe
        if isForceCollapsedBySwipe {
            if isFingerTouchingScroll && y < -14 {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                    isForceCollapsedBySwipe = false
                    isScrolledPastTop = false
                    isManuallyExpanded = false
                }
                dragStartOffsetY = y
                return
            }
        } else if y <= 8 && isScrolledPastTop {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                isScrolledPastTop = false
                isManuallyExpanded = false
            }
            dragStartOffsetY = y
            return
        }

        // 2. Si le menu a été ré-affiché via l'icône loupe : reste visible tant qu'on cherche/filtre, et se retire vers le haut dès qu'on reswipe
        if isManuallyExpanded {
            guard isFingerTouchingScroll else { return }
            let swipedDown = deltaFromDragStart > 12
            let swipedUpAwayFromTop = deltaFromDragStart < -18 && y > 24
            if swipedDown || swipedUpAwayFromTop {
                isSearchFieldFocused = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isManuallyExpanded = false
                    isScrolledPastTop = true
                    if metrics.maxScrollY < 45 || y <= 28 {
                        isForceCollapsedBySwipe = true
                    }
                }
                dragStartOffsetY = y
            }
            return
        }

        // 3. Swipe vers le bas dans le catalogue -> replie la recherche et les catégories vers le haut et affiche l'icône loupe
        guard isUserScrollGestureActive else { return }
        if !isScrolledPastTop && !isForceCollapsedBySwipe {
            if y > 26 && deltaFromDragStart > 10 {
                isSearchFieldFocused = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isScrolledPastTop = true
                    isManuallyExpanded = false
                }
                dragStartOffsetY = y
            } else if isFingerTouchingScroll && metrics.maxScrollY < 45 && deltaFromDragStart > 16 {
                isSearchFieldFocused = false
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isScrolledPastTop = true
                    isForceCollapsedBySwipe = true
                    isManuallyExpanded = false
                }
                dragStartOffsetY = y
            }
        }
    }

    // MARK: - Barre Persistante « Livres / Membres » + Icône Loupe au Swipe

    private var persistentScopeHeader: some View {
        HStack(spacing: 8) {
            // Sélecteur Livres vs Membres toujours persistant en haut
            HStack(spacing: 6) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    let isSelected = searchScope == scope
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            searchScope = scope
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.iconName)
                                .symbolRenderingMode(.monochrome)
                                .font(.system(size: 13, weight: .semibold))
                            Text(scope.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? LivriaPalette.cardPaper : Color.clear)
                                .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 3, x: 0, y: 1)
                        )
                        .foregroundStyle(isSelected ? LivriaPalette.ink : LivriaPalette.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LivriaPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(LivriaPalette.border, lineWidth: 1)
            )

            // Icône loupe ajoutée uniquement quand le menu est replié après un swipe
            if !isFilterDrawerExpanded {
                Button {
                    store.triggerHaptic()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isManuallyExpanded = true
                        isForceCollapsedBySwipe = false
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(hasActiveSearchOrFilter ? .white : LivriaPalette.primary)
                            .frame(width: 40, height: 39)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(hasActiveSearchOrFilter ? LivriaPalette.primary : LivriaPalette.primarySoft)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LivriaPalette.border, lineWidth: 1)
                            )

                        if hasActiveSearchOrFilter {
                            Circle()
                                .fill(LivriaPalette.coral)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(LivriaPalette.cardPaper, lineWidth: 1.5))
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Afficher la barre de recherche et les catégories")
                .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(LivriaPalette.cardPaper)
        .overlay(alignment: .bottom) {
            if !isFilterDrawerExpanded {
                Rectangle()
                    .fill(LivriaPalette.border.opacity(0.75))
                    .frame(height: 0.8)
            }
        }
    }

    // MARK: - Panneau Rétractable : Barre de Recherche + États + Genres

    private var expandableSearchAndCategoriesContent: some View {
        VStack(spacing: 10) {
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
                    .focused($isSearchFieldFocused)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            store.addRecentSearch(searchText)
                        }
                    }
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
                        Divider()
                        Menu("Budget maximum") {
                            Button(maxPriceCeiling == 0 ? "✓ Sans plafond" : "Sans plafond") { maxPriceCeiling = 0 }
                            Button(maxPriceCeiling == 10 ? "✓ ≤ 10,00 €" : "≤ 10,00 €") { maxPriceCeiling = 10 }
                            Button(maxPriceCeiling == 15 ? "✓ ≤ 15,00 €" : "≤ 15,00 €") { maxPriceCeiling = 15 }
                            Button(maxPriceCeiling == 20 ? "✓ ≤ 20,00 €" : "≤ 20,00 €") { maxPriceCeiling = 20 }
                            Button(maxPriceCeiling == 30 ? "✓ ≤ 30,00 €" : "≤ 30,00 €") { maxPriceCeiling = 30 }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }

            if searchScope == .books && !store.recentSearchQueries.isEmpty && searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                            .foregroundStyle(LivriaPalette.inkMuted)
                        ForEach(store.recentSearchQueries, id: \.self) { query in
                            Button {
                                searchText = query
                            } label: {
                                Text(query)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(LivriaPalette.background))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            store.clearRecentSearches()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if searchScope == .books {
                // Filtre d'état Neuf / Occasion / Favoris / Audio & E-Book avec icônes vectorielles monochromes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ConditionFilter.allCases, id: \.self) { cond in
                            let isSelected = conditionFilter == cond
                            Button {
                                conditionFilter = cond
                                store.trackUserActivity(
                                    eventType: "filter_condition",
                                    category: "Recherches & Filtres",
                                    subCategory: "Filtre d'état",
                                    actionLabel: "Filtre état sélectionné : \(cond.rawValue)",
                                    itemTitle: cond.rawValue,
                                    screen: "ios://livria/boutique/filter-condition"
                                )
                            } label: {
                                HStack(spacing: 5) {
                                    if let iconName = cond.iconName {
                                        Image(systemName: iconName)
                                            .symbolRenderingMode(.monochrome)
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    Text(cond.rawValue)
                                        .lineLimit(1)
                                    if cond == .favoritesOnly && !store.favoriteBookIds.isEmpty {
                                        Text("(\(store.favoriteBookIds.count))")
                                    }
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        isSelected
                                            ? (cond == .usedOnly ? LivriaPalette.usedAmber : (cond == .favoritesOnly ? LivriaPalette.coral : LivriaPalette.primary))
                                            : LivriaPalette.background
                                    )
                                )
                                .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                                .overlay(Capsule().stroke(LivriaPalette.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        if maxPriceCeiling > 0 {
                            Button {
                                maxPriceCeiling = 0
                            } label: {
                                HStack(spacing: 4) {
                                    Text(String(format: "≤ %.0f €", maxPriceCeiling))
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(LivriaPalette.goldSoft))
                                .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
        .padding(.top, 2)
        .padding(.bottom, 10)
        .background(LivriaPalette.cardPaper.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LivriaPalette.border.opacity(0.8))
                .frame(height: 0.8)
        }
        .shadow(
            color: (isScrolledPastTop && isManuallyExpanded) ? Color.black.opacity(0.10) : Color.clear,
            radius: 10,
            x: 0,
            y: 5
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard newHeight > 20 else { return }
            if searchScope == .books {
                measuredBooksDrawerHeight = newHeight
            } else {
                measuredMembersDrawerHeight = newHeight
            }
        }
    }

    private func genreChip(_ genre: String) -> some View {
        let isSelected = selectedGenre == genre
        return Button {
            selectedGenre = genre
            store.trackUserActivity(
                eventType: "filter_genre",
                category: "Recherches & Filtres",
                subCategory: "Filtre de genre",
                actionLabel: "Genre sélectionné : \(genre)",
                genre: genre == "Tous" ? nil : genre,
                itemTitle: genre,
                screen: "ios://livria/boutique/filter-genre"
            )
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

    // MARK: - Carte Livre Boutique (Neuf & Occasion + Favoris ❤️)

    private func boutiqueBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if !searchText.isEmpty {
                    store.addRecentSearch(searchText)
                }
                store.recordBookDetailOpened(book, sourceScreen: "Boutique")
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

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                if book.hasNewStock {
                                    Text("Neuf")
                                        .font(.system(size: 9.5, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(LivriaPalette.mint))
                                }
                                if book.hasUsedStock {
                                    HStack(spacing: 3.5) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .symbolRenderingMode(.monochrome)
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text(book.usedConditionLabel)
                                            .font(.system(size: 9.5, weight: .heavy))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(LivriaPalette.usedAmber))
                                }
                            }
                            Spacer()
                            Button {
                                store.toggleFavoriteBook(book)
                            } label: {
                                Image(systemName: store.isFavoriteBook(book.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(store.isFavoriteBook(book.id) ? LivriaPalette.coral : .white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.black.opacity(0.42)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                    }

                    if !book.displayGenre.isEmpty && book.displayGenre.lowercased() != "inconnu" {
                        Text(book.displayGenre)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(LivriaPalette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(LivriaPalette.primarySoft))
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
                        Button {
                            Task {
                                await store.addToCart(bookId: book.id, format: "Broché", quantity: 1)
                            }
                        } label: {
                            Label("Ajouter Neuf (\(String(format: "%.2f €", book.price)))", systemImage: "tag")
                        }
                        Button {
                            Task {
                                await store.addToCart(bookId: book.id, format: book.cartFormatForUsed, quantity: 1)
                            }
                        } label: {
                            Label("Ajouter \(book.usedConditionLabel) (\(String(format: "%.2f €", book.effectiveUsedPrice)))", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.fill")
                                .symbolRenderingMode(.monochrome)
                            Text("Choisir l'état")
                                .lineLimit(1)
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
                                .lineLimit(1)
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
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: activeDrawerSpacerHeight)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isForceCollapsedBySwipe)

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

                            Button {
                                openMemberInLivriaSocial(member: member)
                            } label: {
                                Label("Profil", systemImage: "person.crop.circle.badge.arrow.forward")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                                    .foregroundStyle(LivriaPalette.primaryDeep)
                            }
                            .buttonStyle(.plain)
                        }
                        .livriaCard(padding: 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openMemberInLivriaSocial(member: member)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .frame(minHeight: scrollViewportHeight + 2, alignment: .top)
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            handleScrollPhaseChange(from: oldPhase, to: newPhase)
        }
        .onScrollGeometryChange(for: BoutiqueScrollMetrics.self) { geo in
            let rawY = geo.contentOffset.y + geo.contentInsets.top
            let maxScroll = max(0, geo.contentSize.height - geo.containerSize.height)
            return BoutiqueScrollMetrics(
                offsetY: (rawY * 2).rounded() / 2,
                maxScrollY: (maxScroll * 2).rounded() / 2,
                viewportHeight: max(320, (geo.containerSize.height * 2).rounded() / 2)
            )
        } action: { _, metrics in
            handleScrollMetricsUpdate(metrics)
        }
        .task {
            if store.searchedMembers.isEmpty {
                await store.searchMembers(query: searchText)
            }
        }
    }

    private func openMemberInLivriaSocial(member: LivriaMemberSummary) {
        store.trackUserActivity(
            eventType: "profile_view",
            category: "Réseau Social & Communauté",
            subCategory: "Consultation profil membre",
            actionLabel: "Ouverture du profil de \(member.displayName)",
            detail: member.favoriteGenres.isEmpty ? "Membre Livria" : "Genres : \(member.favoriteGenres)",
            imageUrl: member.avatarUrl,
            itemId: String(member.id),
            itemTitle: member.displayName,
            screen: "ios://livria/boutique/member/\(member.id)"
        )
        var components = URLComponents(string: "livriasocial://profile/\(member.id)")
        var qItems: [URLQueryItem] = [URLQueryItem(name: "name", value: member.displayName)]
        if store.isAuthenticated, let u = store.currentUser, !u.isGuestAccount {
            qItems.append(URLQueryItem(name: "ssoUid", value: String(u.id)))
            qItems.append(URLQueryItem(name: "ssoEmail", value: u.email))
            qItems.append(URLQueryItem(name: "ssoName", value: u.displayName))
            qItems.append(URLQueryItem(name: "ssoAvatar", value: u.avatarUrl ?? ""))
            qItems.append(URLQueryItem(name: "ssoSource", value: "Livria Store"))
        }
        components?.queryItems = qItems
        guard let appUrl = components?.url else {
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.open(appUrl, options: [:]) { opened in
            if !opened {
                Task { @MainActor in
                    await store.refreshPaymentSettings()
                    if store.paymentSettings.loobySocialAppStoreRedirectEnabled {
                        let rawStoreUrl = store.paymentSettings.loobySocialAppStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        let fallbackStoreUrl = rawStoreUrl.isEmpty ? "https://apps.apple.com/fr/search?term=LoobySocial" : rawStoreUrl
                        if let appStoreUrl = URL(string: fallbackStoreUrl) {
                            UIApplication.shared.open(appStoreUrl, options: [:], completionHandler: nil)
                        }
                    } else {
                        pendingWebMemberProfileUrl = member.socialProfileUrl
                        showingLoobySocialWaitAlert = true
                    }
                }
            }
        }
        #endif
    }
}
