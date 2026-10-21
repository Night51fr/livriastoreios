import SwiftUI

// MARK: - Espace Troc de Livres Livria Store (Apple App ID: 6825159743 • Onglet Principal Troc + Scan ISBN)

public struct TradeView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum TradeSection: String, CaseIterable {
        case market = "Offres Ouvertes"
        case myOffers = "Mes Offres"
        case myRequests = "Mes Demandes"
    }

    @State private var selectedSection: TradeSection = .market
    @State private var searchQuery: String = ""
    @State private var showingNewOfferSheet: Bool = false
    @State private var showingISBNScannerForNewOffer: Bool = false
    @State private var offerToPropose: LivriaTradeOffer? = nil

    // Formulaire nouvelle offre
    @State private var newISBN: String = ""
    @State private var newTitle: String = ""
    @State private var newAuthor: String = ""
    @State private var newCondition: String = "Très bon état"
    @State private var newWants: String = ""
    @State private var newDescription: String = ""
    @State private var isLookingUpISBN: Bool = false

    // Formulaire proposition d'échange
    @State private var proposedBookTitle: String = ""
    @State private var proposedMessage: String = ""

    public init() {}

    private var filteredOpenOffers: [LivriaTradeOffer] {
        let all = store.trades?.openOffers ?? []
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.author.localizedCaseInsensitiveContains(q) ||
            $0.wants.localizedCaseInsensitiveContains(q) ||
            $0.ownerName.localizedCaseInsensitiveContains(q)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    tradeHeaderBanner

                    HStack {
                        Picker("Section Troc", selection: $selectedSection) {
                            ForEach(TradeSection.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button {
                            showingNewOfferSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                    }

                    if selectedSection == .market {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(LivriaPalette.primary)
                            TextField("Chercher un livre proposé au troc, auteur, souhait...", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.cardPaper))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))
                    }

                    switch selectedSection {
                    case .market:
                        openOffersList
                    case .myOffers:
                        myOffersList
                    case .myRequests:
                        myRequestsList
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Troc de Livres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewOfferSheet = true
                    } label: {
                        Label("Publier", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }
            .refreshable {
                await store.refreshBootstrap()
            }
            .sheet(isPresented: $showingNewOfferSheet) {
                createOfferSheet
            }
            .sheet(item: $offerToPropose) { offer in
                proposeTradeSheet(offer: offer)
            }
        }
    }

    private var tradeHeaderBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Bourse d'Échange & Troc Livria Store")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Proposez vos livres par ISBN (+15 XP) et échangez en main propre ou en Point Relais (+30 XP)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LivriaPalette.heroGradient))
    }

    private var openOffersList: some View {
        let offers = filteredOpenOffers
        return VStack(spacing: 14) {
            if offers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Aucune offre de troc ouverte pour le moment")
                        .font(.system(size: 16, weight: .bold))
                    Text("Soyez le premier à proposer un livre à échanger avec la communauté (+15 XP) !")
                        .font(.system(size: 13))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .livriaCard(padding: 24)
            } else {
                ForEach(offers) { offer in
                    HStack(alignment: .top, spacing: 14) {
                        LivriaBookCoverView(
                            coverUrl: offer.coverUrl,
                            title: offer.title,
                            width: 72,
                            height: 106,
                            cornerRadius: 10
                        )
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(offer.condition)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                                    .foregroundStyle(LivriaPalette.primary)
                                Spacer()
                                Text("Par \(offer.ownerName)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                            }
                            Text(offer.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                            Text(offer.author)
                                .font(.system(size: 12.5))
                                .foregroundStyle(LivriaPalette.inkMuted)
                            Text("Recherche : \(offer.wants)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(LivriaPalette.coral)

                            if offer.ownerId != store.currentUser?.id {
                                Button {
                                    offerToPropose = offer
                                } label: {
                                    Label("Proposer un échange", systemImage: "arrow.left.arrow.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(LivriaPalette.primary))
                                        .foregroundStyle(.white)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .livriaCard()
                }
            }
        }
    }

    private var myOffersList: some View {
        let mine = store.trades?.myOffers ?? []
        return VStack(spacing: 14) {
            if mine.isEmpty {
                Text("Vous n'avez publié aucune offre de troc.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .livriaCard()
            } else {
                ForEach(mine) { offer in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.title)
                                    .font(.system(size: 15.5, weight: .bold))
                                Text("\(offer.author) • \(offer.condition)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task {
                                    await store.removeTradeOffer(offerId: offer.id)
                                }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.red)
                            }
                        }

                        if !offer.requests.isEmpty {
                            Divider()
                            Text("Propositions reçues (\(offer.requests.count)) :")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.primary)
                            ForEach(offer.requests) { req in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(req.requesterName) propose « \(req.proposedBook) »")
                                        .font(.system(size: 13, weight: .bold))
                                    if !req.message.isEmpty {
                                        Text(req.message)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LivriaPalette.inkMuted)
                                    }
                                    if req.status == "Pending" {
                                        HStack(spacing: 10) {
                                            Button("Accepter (+30 XP)") {
                                                Task { await store.respondToTrade(requestId: req.id, accept: true) }
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(LivriaPalette.mint))
                                            .foregroundStyle(.white)

                                            Button("Décliner") {
                                                Task { await store.respondToTrade(requestId: req.id, accept: false) }
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.red.opacity(0.15)))
                                            .foregroundStyle(.red)
                                        }
                                    } else {
                                        Text("Statut : \(req.status)")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundStyle(LivriaPalette.primary)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                            }
                        }
                    }
                    .livriaCard()
                }
            }
        }
    }

    private var myRequestsList: some View {
        let reqs = store.trades?.myRequests ?? []
        return VStack(spacing: 12) {
            if reqs.isEmpty {
                Text("Vous n'avez envoyé aucune proposition d'échange.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .livriaCard()
            } else {
                ForEach(reqs) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Pour « \(r.offerTitle) » de \(r.ownerName)")
                                .font(.system(size: 14.5, weight: .bold))
                            Spacer()
                            Text(r.status)
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(LivriaPalette.primarySoft))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                        Text("Livre proposé : \(r.proposedBook)")
                            .font(.system(size: 13))
                            .foregroundStyle(LivriaPalette.coral)
                        if !r.message.isEmpty {
                            Text(r.message)
                                .font(.system(size: 12))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                    }
                    .livriaCard()
                }
            }
        }
    }

    private var createOfferSheet: some View {
        NavigationStack {
            Form {
                Section("Pré-remplissage rapide par Scan ISBN") {
                    HStack {
                        TextField("Code ISBN (ex: 9782070368228)", text: $newISBN)
                            .keyboardType(.numbersAndPunctuation)
                        Button {
                            lookupISBNForOffer()
                        } label: {
                            if isLookingUpISBN {
                                ProgressView()
                            } else {
                                Label("Rechercher", systemImage: "magnifyingglass")
                                    .font(.system(size: 12.5, weight: .bold))
                            }
                        }
                        .disabled(newISBN.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUpISBN)
                    }

                    Button {
                        showingISBNScannerForNewOffer = true
                    } label: {
                        Label("Scanner le code-barres avec l'appareil photo", systemImage: "camera.viewfinder")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }

                Section("Livre proposé au troc") {
                    TextField("Titre du livre", text: $newTitle)
                    TextField("Auteur", text: $newAuthor)
                    Picker("État de l'ouvrage", selection: $newCondition) {
                        Text("Comme neuf").tag("Comme neuf")
                        Text("Très bon état").tag("Très bon état")
                        Text("Bon état").tag("Bon état")
                        Text("État correct").tag("État correct")
                    }
                    TextField("Ce que vous recherchez en échange", text: $newWants)
                    TextField("Précisions (édition, remise en main propre ou Point Relais)", text: $newDescription)
                }
            }
            .navigationTitle("Publier une offre de troc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { showingNewOfferSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publier") {
                        Task {
                            await store.createTradeOffer(
                                title: newTitle,
                                author: newAuthor,
                                condition: newCondition,
                                wants: newWants,
                                description: newDescription
                            )
                            newISBN = ""
                            newTitle = ""
                            newAuthor = ""
                            newWants = ""
                            newDescription = ""
                            showingNewOfferSheet = false
                        }
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingISBNScannerForNewOffer) {
                LivriaISBNScannerSheet(
                    onSelectCatalogBook: { foundBook in
                        newISBN = foundBook.isbn
                        newTitle = foundBook.title
                        newAuthor = foundBook.author
                    },
                    onSelectISBNResult: { res in
                        if let i = res.isbn, !i.isEmpty { newISBN = i }
                        if let t = res.title, !t.isEmpty { newTitle = t }
                        if let a = res.author, !a.isEmpty { newAuthor = a }
                    }
                )
                .environmentObject(store)
            }
        }
    }

    private func lookupISBNForOffer() {
        isLookingUpISBN = true
        Task {
            if let res = await store.lookupBookByISBN(isbn: newISBN), res.ok {
                if let t = res.title, !t.isEmpty { newTitle = t }
                if let a = res.author, !a.isEmpty { newAuthor = a }
            }
            isLookingUpISBN = false
        }
    }

    private func proposeTradeSheet(offer: LivriaTradeOffer) -> some View {
        NavigationStack {
            Form {
                Section("Échange pour « \(offer.title) »") {
                    TextField("Titre et auteur du livre que vous proposez", text: $proposedBookTitle)
                    TextField("Votre message pour \(offer.ownerName)", text: $proposedMessage, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Proposer un Troc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { offerToPropose = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Envoyer") {
                        let oid = offer.id
                        let b = proposedBookTitle
                        let m = proposedMessage
                        offerToPropose = nil
                        Task {
                            await store.proposeTrade(offerId: oid, proposedBook: b, message: m)
                            proposedBookTitle = ""
                            proposedMessage = ""
                        }
                    }
                    .disabled(proposedBookTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
