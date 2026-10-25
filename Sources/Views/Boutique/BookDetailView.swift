import SwiftUI

// MARK: - Fiche Livre Détaillée Livria Store (Sélecteur Neuf / Occasion, Bande-son d'ambiance, Avis & Troc)

public struct BookDetailView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @StateObject private var ambientPlayer = LivriaAmbientSoundPlayer()
    public let book: LivriaBook

    @State private var detailedBook: LivriaBook?
    @State private var selectedFormat: String = "Broché"
    @State private var selectedConditionIsUsed: Bool = false
    @State private var reviews: [LivriaBookReview] = []
    @State private var similarBooks: [LivriaBook] = []
    @State private var averageRating: Double = 5.0
    @State private var newReviewRating: Int = 5
    @State private var newReviewComment: String = ""
    @State private var personalNoteText: String = ""
    @State private var selectedSimilarBook: LivriaBook? = nil
    @State private var activeDigitalReaderEntry: LivriaShelfEntry? = nil
    @State private var activeAudioPlayerEntry: LivriaShelfEntry? = nil

    public init(book: LivriaBook) {
        self.book = book
        _selectedFormat = State(initialValue: book.availableFormats.first ?? "Broché")
        _selectedConditionIsUsed = State(initialValue: !book.hasNewStock && book.hasUsedStock)
    }

    private var currentBook: LivriaBook {
        detailedBook ?? book
    }

    private var activeCartFormat: String {
        if selectedFormat == "Broché" {
            return selectedConditionIsUsed ? book.cartFormatForUsed : "Broché"
        }
        return selectedFormat
    }

    private var displayedPrice: Double {
        if store.currentUser?.isLivriaPlus == true && (selectedFormat == "Numérique" || selectedFormat == "Audio") {
            return 0.0
        }
        if selectedFormat == "Broché" && selectedConditionIsUsed {
            return book.effectiveUsedPrice
        }
        return book.price
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerBookCard
                if currentBook.hasLongerDelivery12Days {
                    longerDeliveryNoticeCard
                }
                formatAndConditionSelectorCard
                actionButtonsCard
                ambientAndMetadataCard
                synopsisCard
                personalReadingJournalCard
                if !similarBooks.isEmpty {
                    similarBooksCard
                }
                reviewsSectionCard
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.toggleFavoriteBook(currentBook)
                } label: {
                    Image(systemName: store.isFavoriteBook(book.id) ? "heart.fill" : "heart")
                        .foregroundStyle(store.isFavoriteBook(book.id) ? LivriaPalette.coral : LivriaPalette.primary)
                }
                if let shareUrl = URL(string: "https://livria.store/boutique?book=\(book.id)") {
                    ShareLink(
                        item: shareUrl,
                        subject: Text(book.title),
                        message: Text("Découvre « \(book.title) » de \(book.author) sur Livria Store !")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedSimilarBook) { sim in
            BookDetailView(book: sim)
        }
        .sheet(item: $activeDigitalReaderEntry) { entry in
            LivriaDigitalReaderSheet(entry: entry)
                .environmentObject(store)
        }
        .sheet(item: $activeAudioPlayerEntry) { entry in
            LivriaAudioPlayerSheet(entry: entry)
                .environmentObject(store)
        }
        .task {
            store.recordBookViewed(book.id)
            personalNoteText = store.readingNote(for: book.id)
            await loadBookDetails()
        }
        .onDisappear {
            ambientPlayer.stop()
        }
    }

    // MARK: - En-tête Fiche Livre

    private var headerBookCard: some View {
        HStack(alignment: .top, spacing: 16) {
            LivriaBookCoverView(
                coverUrl: book.coverUrl,
                title: book.title,
                width: 126,
                height: 184,
                cornerRadius: 16
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(book.displayGenre)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LivriaPalette.primarySoft))

                    if let origin = book.countryOfOrigin, !origin.isEmpty {
                        Text("🌍 \(origin)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }

                Text(book.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(LivriaPalette.ink)

                Text("par \(book.author)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LivriaPalette.inkMuted)

                if !book.isbn.isEmpty {
                    HStack(spacing: 6) {
                        Text("ISBN : \(book.isbn)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LivriaPalette.inkMuted)
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = book.isbn
                            #endif
                            store.showToast("ISBN \(book.isbn) copié dans le presse-papiers.")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(LivriaPalette.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= averageRating ? "star.fill" : "star")
                            .foregroundStyle(LivriaPalette.gold)
                            .font(.caption)
                    }
                    Text(String(format: "%.1f (%d avis)", averageRating, reviews.count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }

                // Prix selon l'état sélectionné
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayedPrice == 0 ? "Inclus Looby+ (0,00 €)" : String(format: "%.2f €", displayedPrice))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            displayedPrice == 0
                                ? LivriaPalette.mint
                                : (selectedFormat == "Broché" && selectedConditionIsUsed ? LivriaPalette.usedAmber : LivriaPalette.primary)
                        )

                    if selectedFormat == "Broché" {
                        Text(selectedConditionIsUsed ? "♻️ Exemplaire \(book.usedConditionLabel)" : "✨ Exemplaire Neuf éditeur")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(selectedConditionIsUsed ? LivriaPalette.usedAmber : LivriaPalette.mint)
                    }

                    if currentBook.hasLongerDelivery12Days {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(currentBook.longerDeliveryLabel ?? "Réception plus longue : sous 12j")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.16)))
                        .foregroundStyle(Color(red: 0.76, green: 0.25, blue: 0.05))
                        .padding(.top, 3)
                    }
                }
            }
            Spacer()
        }
        .livriaCard()
    }

    // MARK: - Bandeau « Réception plus longue : sous 12j » (En commande fournisseur, hors stock immédiat)

    private var longerDeliveryNoticeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.76, green: 0.25, blue: 0.05))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(currentBook.longerDeliveryLabel ?? "Réception plus longue : sous 12j")
                    .font(.system(size: 14.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.60, green: 0.20, blue: 0.04))
                Text(currentBook.longerDeliveryNotice ?? "Cet ouvrage n'est pas encore dans notre stock immédiat mais est actuellement en commande. Votre exemplaire vous sera expédié dès réception (sous 12 jours).")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.70, green: 0.26, blue: 0.06))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 1.0, green: 0.97, blue: 0.93)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.45), lineWidth: 1.5))
    }

    // MARK: - Sélecteur de Format & d'État (Neuf vs Occasion au prix indiqué de chacun)

    private var formatAndConditionSelectorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(currentBook.availableFormats.count > 1 ? "1. Choisir le format" : "Format disponible")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            HStack(spacing: 10) {
                if currentBook.isPaperbackAvailable {
                    formatButton(format: "Broché", icon: "book.closed.fill", subtitle: "Livraison UPS / Relais")
                }
                if currentBook.hasEpub {
                    formatButton(format: "Numérique", icon: "ipad", subtitle: "Édition numérique")
                }
                if currentBook.hasAudio {
                    formatButton(format: "Audio", icon: "headphones", subtitle: "Livre audio narré")
                }
            }

            if selectedFormat == "Broché" && currentBook.isPaperbackAvailable {
                Divider()

                Text("2. Choisir l'état de l'ouvrage papier")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)

                HStack(spacing: 10) {
                    if currentBook.hasNewStock {
                        conditionChoiceCard(
                            isUsed: false,
                            badge: "✨ Neuf",
                            subtitle: "Exemplaire neuf (\(max(currentBook.stock, 1)) en stock)",
                            price: currentBook.price,
                            accent: LivriaPalette.primary
                        )
                    }

                    if currentBook.hasUsedStock {
                        conditionChoiceCard(
                            isUsed: true,
                            badge: "♻️ \(currentBook.usedConditionLabel)",
                            subtitle: "Exemplaire contrôlé et garanti (\(currentBook.usedStock ?? 1) en stock)",
                            price: currentBook.effectiveUsedPrice,
                            accent: LivriaPalette.usedAmber
                        )
                    }
                }
            }
        }
        .livriaCard()
    }

    private func conditionChoiceCard(isUsed: Bool, badge: String, subtitle: String, price: Double, accent: Color) -> some View {
        let isSelected = selectedConditionIsUsed == isUsed
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedConditionIsUsed = isUsed
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(badge)
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? .white : accent)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .white : accent)
                }
                Text(String(format: "%.2f €", price))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : LivriaPalette.inkMuted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? accent : LivriaPalette.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? accent : LivriaPalette.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatButton(format: String, icon: String, subtitle: String) -> some View {
        let isSelected = selectedFormat == format
        return Button {
            selectedFormat = format
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(format)
                    .font(.system(size: 13, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? LivriaPalette.primary : LivriaPalette.background)
            )
            .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Boutons d'Action Boutique & Troc

    private var actionButtonsCard: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await store.addToCart(bookId: book.id, format: activeCartFormat, quantity: 1)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .symbolRenderingMode(.monochrome)
                    Text("Ajouter au panier • \(activeCartFormat) (\(String(format: "%.2f €", displayedPrice)))")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: selectedFormat == "Broché" && selectedConditionIsUsed
                            ? [LivriaPalette.usedAmber, LivriaPalette.coral]
                            : [LivriaPalette.primary, LivriaPalette.coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    guard store.requireAuthenticationForPurchase(reason: "acheter sur Livria Store") else { return }
                    Task {
                        await store.addToCart(bookId: book.id, format: activeCartFormat, quantity: 1)
                        store.isShowingCheckoutSheet = true
                    }
                } label: {
                    Label("Achat Express ( Pay / G Pay)", systemImage: "bolt.shield.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primaryDeep)
                }

                Button {
                    if store.isAuthenticated {
                        store.selectedMainTab = 2
                    } else {
                        store.isShowingAuthSheet = true
                    }
                } label: {
                    Label("Chercher / Proposer en Troc", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.goldSoft))
                        .foregroundStyle(Color(red: 0.55, green: 0.32, blue: 0.02))
                }
            }

            if let entry = store.shelfEntry(for: book.id), (entry.canOpenDigitalReader || entry.canOpenAudioPlayer) {
                HStack(spacing: 10) {
                    if entry.canOpenDigitalReader {
                        Button {
                            activeDigitalReaderEntry = entry
                        } label: {
                            Label("Lire mon édition Numérique", systemImage: "book.pages.fill")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    if entry.canOpenAudioPlayer {
                        Button {
                            activeAudioPlayerEntry = entry
                        } label: {
                            Label("Écouter mon Livre Audio", systemImage: "headphones")
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.coral))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if store.isAuthenticated && store.shelfEntry(for: book.id) == nil {
                Button {
                    Task {
                        await store.updateShelf(bookId: book.id, status: "WantToRead", format: "Broché")
                        store.showToast("« \(book.title) » ajouté à Ma bibliothèque (À lire).")
                    }
                } label: {
                    Label("Ajouter à Ma bibliothèque (À lire)", systemImage: "books.vertical.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                        .foregroundStyle(LivriaPalette.primary)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .livriaCard()
    }

    // MARK: - Bande-Son d'Ambiance Interactive & Mood Tags

    private var ambientAndMetadataCard: some View {
        let preset = (book.ambientSoundtrack?.isEmpty == false) ? book.ambientSoundtrack! : "Pluie douce & librairie"
        let isPlaying = ambientPlayer.activePreset == preset
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Ambiance sonore de l'ouvrage", systemImage: "waveform.and.mic")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text(preset)
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Button {
                    ambientPlayer.toggle(preset: preset)
                } label: {
                    Label(isPlaying ? "Arrêter" : "Écouter l'ambiance", systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isPlaying ? LivriaPalette.coral : LivriaPalette.primary))
                        .foregroundStyle(.white)
                }
            }

            if let moods = book.moodTags, !moods.isEmpty {
                Text("Atmosphère : \(moods)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.primary)
            }
        }
        .livriaCard(padding: 14)
    }

    // MARK: - Synopsis & Résumé IA Garanti Sans Spoiler

    private var synopsisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Résumé de l'ouvrage")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text(book.description)
                .font(.system(size: 14))
                .foregroundStyle(LivriaPalette.inkMuted)
                .lineSpacing(4)

            if let noSpoil = book.aiSummaryNoSpoil, !noSpoil.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(LivriaPalette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Note du Libraire IA (Garanti 0% Spoiler)")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                        Text(noSpoil)
                            .font(.system(size: 12.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft.opacity(0.5)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .livriaCard()
    }

    // MARK: - Carnet de Notes de Lecture Personnel & Journal de Session (0 donnée démo)

    private var personalReadingJournalCard: some View {
        let loggedMins = store.readingMinutesByBook[book.id] ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mon carnet de lecture privé", systemImage: "notebook")
                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                if loggedMins > 0 {
                    Text("⏱️ \(loggedMins) min lues")
                        .font(.system(size: 11.5, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primaryDeep)
                }
            }

            HStack(spacing: 8) {
                Text("Session de lecture :")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivriaPalette.inkMuted)
                ForEach([15, 30, 45], id: \.self) { mins in
                    Button {
                        store.addReadingMinutes(bookId: book.id, minutes: mins)
                    } label: {
                        Text("+\(mins) min")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(LivriaPalette.background))
                            .foregroundStyle(LivriaPalette.primary)
                            .overlay(Capsule().stroke(LivriaPalette.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            TextField("Notez vos citations favorites, votre page actuelle ou vos impressions personnelles...", text: $personalNoteText, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 13))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))

            HStack {
                Text("Conservé sur votre appareil en toute confidentialité")
                    .font(.system(size: 10.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
                Spacer()
                Button {
                    store.saveReadingNote(bookId: book.id, note: personalNoteText)
                } label: {
                    Label("Enregistrer ma note", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .livriaCard()
    }

    // MARK: - Ouvrages Similaires Recommandés

    private var similarBooksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dans le même univers littéraire")
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(similarBooks) { sim in
                        Button {
                            selectedSimilarBook = sim
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                LivriaBookCoverView(
                                    coverUrl: sim.coverUrl,
                                    title: sim.title,
                                    width: 96,
                                    height: 140,
                                    cornerRadius: 10
                                )
                                Text(sim.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                    .lineLimit(1)
                                    .frame(width: 96, alignment: .leading)
                                Text(String(format: "%.2f €", sim.price))
                                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .livriaCard()
    }

    // MARK: - Avis des Lecteurs

    private var reviewsSectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Avis des acheteurs Livria Store (\(reviews.count))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Votre note :")
                        .font(.system(size: 13, weight: .semibold))
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            newReviewRating = star
                        } label: {
                            Image(systemName: star <= newReviewRating ? "star.fill" : "star")
                                .foregroundStyle(LivriaPalette.gold)
                        }
                    }
                }
                TextField("Partagez votre avis sur cet ouvrage (+10 XP)...", text: $newReviewComment, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                Button {
                    Task {
                        let ok = await store.submitBookReview(bookId: book.id, rating: newReviewRating, comment: newReviewComment)
                        if ok {
                            newReviewComment = ""
                            await loadBookDetails()
                        }
                    }
                } label: {
                    Text("Publier mon avis")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                }
                .disabled(newReviewComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivriaPalette.backgroundAlt.opacity(0.6)))

            ForEach(reviews) { rev in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(rev.userName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { s in
                                Image(systemName: s <= rev.rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(LivriaPalette.gold)
                            }
                        }
                        Text(rev.createdAt)
                            .font(.system(size: 11))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Text(rev.comment)
                        .font(.system(size: 13))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
            }
        }
        .livriaCard()
    }

    private func loadBookDetails() async {
        do {
            let detail = try await LivriaAPIClient.shared.fetchBookDetails(bookId: book.id)
            self.detailedBook = detail.book
            if !detail.book.availableFormats.contains(self.selectedFormat) {
                self.selectedFormat = detail.book.availableFormats.first ?? "Broché"
            }
            self.reviews = detail.reviews
            self.similarBooks = detail.similar
            self.averageRating = detail.averageRating ?? 5.0
        } catch {
            // Garde les infos de base si hors-ligne
        }
    }
}
