import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Vue Dédiée « Les nouvelles sorties du jour » (Livria Store • Anti-Spam Push 1×/jour + Arrivages Temps Réel)

public struct DailyNewReleasesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @ObservedObject private var notifManager = LivriaNotificationManager.shared

    @State private var selectedGenre: String = "Tous"
    @State private var selectedBook: LivriaBook? = nil
    @State private var isHeroAnimating: Bool = false
    @State private var isShowingNotificationControls: Bool = false

    public init() {}

    private var effectiveDateLabelFr: String {
        if let label = store.dailyNewReleases?.dateLabelFr, !label.isEmpty {
            return label
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        df.dateFormat = "EEEE d MMMM yyyy"
        let raw = df.string(from: Date())
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    private var rawTodayBooks: [LivriaBook] {
        if let resp = store.dailyNewReleases {
            return resp.todayBooks
        }
        return store.books.filter(\.isAddedTodayParis)
    }

    private var rawRecentBooks: [LivriaBook] {
        if let resp = store.dailyNewReleases, !resp.recentBooks.isEmpty {
            return resp.recentBooks
        }
        let todayIds = Set(rawTodayBooks.map(\.id))
        return Array(
            store.books
                .filter { !todayIds.contains($0.id) }
                .sorted { $0.id > $1.id }
                .prefix(24)
        )
    }

    private var availableGenres: [String] {
        if let serverGenres = store.dailyNewReleases?.genres, !serverGenres.isEmpty {
            return serverGenres
        }
        let combined = (rawTodayBooks + rawRecentBooks)
            .map(\.displayGenre)
            .filter { !$0.isEmpty && $0.lowercased() != "inconnu" && $0 != "Roman / Livre" }
        return Array(Set(combined)).sorted()
    }

    private var filteredTodayBooks: [LivriaBook] {
        guard selectedGenre != "Tous" else { return rawTodayBooks }
        return rawTodayBooks.filter {
            $0.displayGenre.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame
        }
    }

    private var filteredRecentBooks: [LivriaBook] {
        guard selectedGenre != "Tous" else { return rawRecentBooks }
        return rawRecentBooks.filter {
            $0.displayGenre.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame
        }
    }

    private var activeSpotlightBook: LivriaBook? {
        guard let spot = store.dailyNewReleases?.spotlightBook else { return nil }
        if selectedGenre == "Tous" {
            return spot
        }
        if spot.displayGenre.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame {
            return spot
        }
        return nil
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroHeaderCard

                if isShowingNotificationControls {
                    notificationPreferencesCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !availableGenres.isEmpty {
                    genreFilterStrip
                }

                if let spotlight = activeSpotlightBook {
                    spotlightSelectionCard(book: spotlight)
                }

                todayArrivalsSection

                recentArrivalsGridSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 80)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Nouvelles sorties")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Fermer")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(LivriaPalette.inkMuted)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        store.isShowingCartSheet = true
                    }
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
        .refreshable {
            await store.loadDailyNewReleases()
        }
        .task {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isHeroAnimating = true
            }
            await notifManager.refreshAuthorizationStatus()
            await store.loadDailyNewReleases()
        }
    }

    // MARK: - 1. Hero Header Animé « Les nouvelles sorties du jour »

    private var heroHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(LivriaPalette.gold)
                        .scaleEffect(isHeroAnimating ? 1.16 : 0.92)
                    Text(effectiveDateLabelFr.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.18)))

                Spacer()

                // Bouton Cloche pour activer / vérifier les alertes Nouvelles Sorties
                Button {
                    handleBellButtonTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: (notifManager.isOsAuthorized && notifManager.notificationsEnabled && notifManager.newReleasesEnabled)
                              ? "bell.badge.fill"
                              : "bell.slash.fill")
                            .font(.system(size: 13.5, weight: .bold))
                        Text(notifManager.statusBadgeText)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((notifManager.isOsAuthorized && notifManager.notificationsEnabled && notifManager.newReleasesEnabled)
                                  ? LivriaPalette.gold
                                  : Color.white.opacity(0.22))
                    )
                    .foregroundStyle((notifManager.isOsAuthorized && notifManager.notificationsEnabled && notifManager.newReleasesEnabled)
                                     ? Color.black
                                     : Color.white)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Les nouvelles sorties du jour")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Retrouvez en un seul endroit toutes les parutions ajoutées aujourd'hui dans la librairie Livria Store, sans spam (1 alerte groupée max par jour).")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LivriaPalette.gold)
                    Text(rawTodayBooks.count == 0
                         ? "En attente des arrivages du jour"
                         : (rawTodayBooks.count == 1
                            ? "1 nouveauté ajoutée aujourd'hui"
                            : "\(rawTodayBooks.count) nouveautés ajoutées aujourd'hui"))
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.16)))

                if store.isLoadingDailyReleases {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
            }
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: LivriaPalette.primary.opacity(0.24), radius: 14, x: 0, y: 6)
    }

    private func handleBellButtonTap() {
        store.triggerHaptic()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            isShowingNotificationControls.toggle()
        }
        if notifManager.authorizationStatus == .notDetermined {
            Task {
                let granted = await notifManager.requestPermissionIfNeeded(promptIfNotDetermined: true)
                if granted {
                    notifManager.notificationsEnabled = true
                    notifManager.newReleasesEnabled = true
                    store.showToast("🔔 Alertes des nouvelles sorties activées (1 max/jour) !")
                }
            }
        }
    }

    // MARK: - 1b. Panneau de Réglage Rapide des Alertes Livria Store

    private var notificationPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Vos alertes intelligentes Livria Store", systemImage: "bell.badge.waveform.fill")
                    .font(.system(size: 14.5, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isShowingNotificationControls = false
                    }
                } label: {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                .buttonStyle(.plain)
            }

            if notifManager.authorizationStatus == .denied {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LivriaPalette.usedAmber)
                    Text("Les notifications sont désactivées dans les réglages iOS pour Livria Store.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    Button("Réglages") {
                        notifManager.openSystemNotificationSettings()
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.usedAmberSoft.opacity(0.6)))
            } else if !notifManager.isOsAuthorized {
                Button {
                    Task {
                        let ok = await notifManager.requestPermissionIfNeeded(promptIfNotDetermined: true)
                        store.showToast(ok ? "🔔 Notifications autorisées !" : "Vous pourrez les activer à tout moment dans Réglages.")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                        Text("Autoriser les notifications sur cet iPhone")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: $notifManager.newReleasesEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nouvelles sorties du jour")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Anti-spam garanti : 1 seule alerte groupée par jour même si 30 livres sont ajoutés")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }
            .tint(LivriaPalette.primary)

            Divider()

            Toggle(isOn: $notifManager.dailyRecommendationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggestion personnalisée (1×/jour)")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Un livre sélectionné selon vos genres favoris, vos lectures et vos auteurs suivis")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }
            .tint(LivriaPalette.coral)
        }
        .livriaCard(cornerRadius: 20, padding: 15)
    }

    // MARK: - 2. Filtres Dynamiques par Genre

    private var genreFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                genreChip("Tous")
                ForEach(availableGenres, id: \.self) { genre in
                    genreChip(genre)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func genreChip(_ genre: String) -> some View {
        let isSelected = selectedGenre == genre
        return Button {
            store.triggerHaptic()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedGenre = genre
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

    // MARK: - 3. Carte Coup de Cœur « Sélectionné pour vous »

    private func spotlightSelectionCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .black))
                    Text("SÉLECTIONNÉ POUR VOUS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(LivriaPalette.goldSoft))
                .foregroundStyle(Color(red: 0.58, green: 0.32, blue: 0.02))

                Spacer()

                Text(book.displayGenre)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)
            }

            HStack(alignment: .top, spacing: 15) {
                Button {
                    selectedBook = book
                } label: {
                    LivriaBookCoverView(
                        coverUrl: book.coverUrl,
                        title: book.title,
                        width: 104,
                        height: 152,
                        cornerRadius: 14
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 7) {
                    Text(book.title)
                        .font(.system(size: 17.5, weight: .bold, design: .serif))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(2)

                    Text("de \(book.author)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)

                    Text(book.description)
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        Text(String(format: "%.2f €", book.primaryDisplayPrice))
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.primary)

                        if book.hasBothNewAndUsed {
                            Text(String(format: "Occasion %.2f €", book.effectiveUsedPrice))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(LivriaPalette.usedAmberSoft))
                                .foregroundStyle(LivriaPalette.usedAmber)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            selectedBook = book
                        } label: {
                            Text("Voir la fiche")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
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
                            HStack(spacing: 5) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text("Ajouter")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LivriaPalette.gold.opacity(0.35), lineWidth: 1.2)
        )
    }

    // MARK: - 4. Section « Ajoutés aujourd'hui »

    private var todayArrivalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LivriaPalette.coral)
                    Text("Ajoutés aujourd'hui")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }

                Spacer()

                if !filteredTodayBooks.isEmpty {
                    Text("\(filteredTodayBooks.count) titre\(filteredTodayBooks.count > 1 ? "s" : "")")
                        .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LivriaPalette.coral.opacity(0.14)))
                        .foregroundStyle(LivriaPalette.coral)
                }
            }

            if rawTodayBooks.isEmpty {
                emptyTodayReleasesBanner
            } else if filteredTodayBooks.isEmpty {
                VStack(spacing: 10) {
                    Text("Aucune parution dans le rayon « \(selectedGenre) » depuis minuit.")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .multilineTextAlignment(.center)
                    Button("Afficher tous les genres") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedGenre = "Tous"
                        }
                    }
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.primary)
                }
                .frame(maxWidth: .infinity)
                .livriaCard(cornerRadius: 18, padding: 16)
            } else {
                VStack(spacing: 14) {
                    ForEach(filteredTodayBooks) { book in
                        todayRichBookCard(book: book)
                    }
                }
            }
        }
    }

    private var emptyTodayReleasesBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LivriaPalette.primarySoft)
                    .frame(width: 48, height: 48)
                Image(systemName: "clock.badge.sparkles.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Aucune nouvelle parution enregistrée depuis minuit — découvrez les derniers arrivages de la semaine")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Dès qu'un nouvel ouvrage est mis en rayon sur Livria Store aujourd'hui, il apparaîtra instantanément ici.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if !notifManager.isOsAuthorized || !notifManager.newReleasesEnabled {
                    Button {
                        handleBellButtonTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.fill")
                            Text("M'alerter dès la prochaine sortie")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .livriaCard(cornerRadius: 20, padding: 16)
    }

    private func todayRichBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .black))
                    Text("NOUVEAU AUJOURD'HUI")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())

                Text(book.addedTimeLabelFr)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(LivriaPalette.inkMuted)

                Spacer()

                Button {
                    store.toggleFavoriteBook(book)
                } label: {
                    Image(systemName: store.isFavoriteBook(book.id) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(store.isFavoriteBook(book.id) ? LivriaPalette.coral : LivriaPalette.inkMuted)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 14) {
                Button {
                    selectedBook = book
                } label: {
                    LivriaBookCoverView(
                        coverUrl: book.coverUrl,
                        title: book.title,
                        width: 96,
                        height: 142,
                        cornerRadius: 12
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 16.5, weight: .bold, design: .serif))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(2)

                    Text(book.author)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)

                    // Badges Genre & États (Neuf / Occasion / Numérique / Audio)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            formatTag(book.displayGenre, bg: LivriaPalette.primarySoft, fg: LivriaPalette.primaryDeep)
                            if book.hasNewStock {
                                formatTag("Neuf", bg: LivriaPalette.mint.opacity(0.15), fg: LivriaPalette.mint)
                            }
                            if book.hasUsedStock {
                                formatTag("Occasion", bg: LivriaPalette.usedAmberSoft, fg: LivriaPalette.usedAmber)
                            }
                            if book.hasEpub {
                                formatTag("E-Book", bg: LivriaPalette.primarySoft.opacity(0.8), fg: LivriaPalette.primary)
                            }
                            if book.hasAudio {
                                formatTag("Audio", bg: LivriaPalette.coral.opacity(0.14), fg: LivriaPalette.coral)
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.2f €", book.primaryDisplayPrice))
                            .font(.system(size: 18.5, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.primary)

                        if let orig = book.originalPrice, orig > book.price {
                            Text(String(format: "%.2f €", orig))
                                .font(.system(size: 12, weight: .medium))
                                .strikethrough()
                                .foregroundStyle(LivriaPalette.inkMuted)
                        } else if book.hasBothNewAndUsed {
                            Text(String(format: "Occasion %.2f €", book.effectiveUsedPrice))
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.usedAmber)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            selectedBook = book
                        } label: {
                            Text("Découvrir")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(LivriaPalette.backgroundAlt))
                                .foregroundStyle(LivriaPalette.primaryDeep)
                        }
                        .buttonStyle(.plain)

                        Button {
                            let fmt = book.hasNewStock ? "Broché" : book.cartFormatForUsed
                            Task {
                                await store.addToCart(bookId: book.id, format: fmt, quantity: 1)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text("Panier")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .livriaCard(cornerRadius: 20, padding: 15)
    }

    private func formatTag(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }

    // MARK: - 5. Section « Derniers arrivages récents » (Grille 2 Colonnes)

    private var recentArrivalsGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Derniers arrivages récents")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Les ouvrages fraîchement entrés au catalogue Livria Store")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
                Spacer()
            }

            if filteredRecentBooks.isEmpty {
                Text("Aucun ouvrage récent trouvé pour ce filtre.")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(filteredRecentBooks) { book in
                        recentGridBookCard(book: book)
                    }
                }
            }
        }
    }

    private func recentGridBookCard(book: LivriaBook) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Button {
                    selectedBook = book
                } label: {
                    LivriaBookCoverView(
                        coverUrl: book.coverUrl,
                        title: book.title,
                        width: 132,
                        height: 186,
                        cornerRadius: 14
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button {
                    store.toggleFavoriteBook(book)
                } label: {
                    Image(systemName: store.isFavoriteBook(book.id) ? "heart.fill" : "heart")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(store.isFavoriteBook(book.id) ? LivriaPalette.coral : LivriaPalette.inkMuted)
                        .padding(7)
                        .background(Circle().fill(LivriaPalette.cardPaper.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(4)
            }

            HStack(spacing: 5) {
                Text(book.displayGenre)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(LivriaPalette.primarySoft))
                    .foregroundStyle(LivriaPalette.primaryDeep)

                Spacer(minLength: 0)

                Text(book.isUsedOnly ? "Occasion" : (book.hasBothNewAndUsed ? "Neuf & Occ." : "Neuf"))
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(book.isUsedOnly ? LivriaPalette.usedAmber : LivriaPalette.mint)
                    .lineLimit(1)
            }

            Button {
                selectedBook = book
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(LivriaPalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(book.author)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack {
                Text(String(format: "%.2f €", book.primaryDisplayPrice))
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.primary)

                Spacer()

                Button {
                    let fmt = book.hasNewStock ? "Broché" : book.cartFormatForUsed
                    Task {
                        await store.addToCart(bookId: book.id, format: fmt, quantity: 1)
                    }
                } label: {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(LivriaPalette.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LivriaPalette.cardPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LivriaPalette.border, lineWidth: 1)
        )
        .shadow(color: LivriaPalette.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
