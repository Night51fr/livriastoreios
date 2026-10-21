import SwiftUI
import MapKit

// MARK: - Points Relais Communautaires & Points Relais UPS (RelayPointsView)

public struct RelayPointsView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum RelayTab: String, CaseIterable {
        case community = "Relais Communautaires"
        case ups = "Points Relais UPS"
    }

    @State private var selectedTab: RelayTab = .community
    @State private var searchQuery: String = ""
    @State private var upsSearchQuery: String = "75001"
    @State private var upsResults: [LivriaUpsPickupPoint] = []
    @State private var showingAddCommunityRelay: Bool = false

    // Formulaire nouveau relais communautaire
    @State private var newRelayName: String = ""
    @State private var newRelayType: String = "Boîte à Livres Citoyenne"
    @State private var newRelayAddress: String = ""
    @State private var newRelayPostalCode: String = ""
    @State private var newRelayCity: String = ""
    @State private var newRelayHours: String = "24h/24 • 7j/7"
    @State private var newRelayDesc: String = ""

    public init() {}

    private var filteredCommunityRelays: [LivriaCommunityRelay] {
        let all = store.relays?.communityPoints ?? []
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.city.localizedCaseInsensitiveContains(q) ||
            $0.postalCode.localizedCaseInsensitiveContains(q) ||
            $0.address.localizedCaseInsensitiveContains(q)
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Sélecteur Communautaire vs UPS
                Picker("Type de Point Relais", selection: $selectedTab) {
                    ForEach(RelayTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                // Cadre officiel Viple Delivery hors points relais communautaires
                externalVipleDeliveryPickupCard

                if selectedTab == .community {
                    communityRelaysSection
                } else {
                    upsRelaysSection
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Points Relais & UPS")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            upsResults = store.relays?.upsPoints ?? []
        }
        .sheet(isPresented: $showingAddCommunityRelay) {
            addCommunityRelaySheet
        }
    }

    // MARK: - Cadre Viple Delivery (Points Relais hors points relais communautaires)

    private var externalVipleDeliveryPickupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LivriaPalette.gold.opacity(0.22))
                        .frame(width: 46, height: 46)
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.title3)
                        .foregroundStyle(LivriaPalette.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("RÉSEAU PARTENAIRE VIPLE DELIVERY & UPS")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(LivriaPalette.gold)
                    Text("Pour consulter les points relais disponibles à la livraison hors points relais communautaires, cliquez sur le bouton ci-dessous.")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if let url = URL(string: LivriaURLResolver.deliveryPickupURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Consulter les points relais Viple Delivery")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "arrow.up.right.square.fill")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.11, blue: 0.31), Color(red: 0.31, green: 0.18, blue: 0.56)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - Onglet 1 : Points Relais Communautaires & Boîtes à Livres

    private var communityRelaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LivriaPalette.primary)
                    TextField("Ville, code postal ou nom du relais...", text: $searchQuery)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.cardPaper))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

                Button {
                    showingAddCommunityRelay = true
                } label: {
                    Label("Proposer", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                }
            }

            if filteredCommunityRelays.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mappin.slash.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Aucun point relais communautaire trouvé pour cette recherche.")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .livriaCard()
            } else {
                ForEach(filteredCommunityRelays) { pt in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(pt.type)
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(LivriaPalette.primarySoft))
                                .foregroundStyle(LivriaPalette.primary)
                            Spacer()
                            Text("\(pt.postalCode) \(pt.city)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }

                        Text(pt.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)

                        Label("\(pt.address), \(pt.postalCode) \(pt.city)", systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12.5))
                            .foregroundStyle(LivriaPalette.inkMuted)

                        Label("Horaires : \(pt.openingHours)", systemImage: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.mint)

                        if !pt.description.isEmpty {
                            Text(pt.description)
                                .font(.system(size: 12.5))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }

                        HStack {
                            Button {
                                store.selectedCommunityRelayId = pt.id
                                store.selectedRelayForCheckout = "\(pt.name) (\(pt.city))"
                                store.showToast("Point relais « \(pt.name) » sélectionné pour vos livraisons !")
                            } label: {
                                Label("Choisir pour mes commandes", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(LivriaPalette.primary))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            if let mapsUrl = URL(string: "http://maps.apple.com/?ll=\(pt.latitude),\(pt.longitude)&q=\(pt.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Relais")") {
                                Link(destination: mapsUrl) {
                                    Label("Plans", systemImage: "location.north.line.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(LivriaPalette.primarySoft))
                                        .foregroundStyle(LivriaPalette.primaryDeep)
                                }
                            }
                        }
                    }
                    .livriaCard()
                }
            }
        }
    }

    // MARK: - Onglet 2 : Points Relais UPS Access Point™

    private var upsRelaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(LivriaPalette.gold)
                    TextField("Code postal ou ville (ex: 75001, Lyon, Marseille...)", text: $upsSearchQuery)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.cardPaper))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

                Button {
                    Task {
                        upsResults = await store.searchUpsRelays(query: upsSearchQuery)
                    }
                } label: {
                    Text("Rechercher UPS")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.gold))
                        .foregroundStyle(.black)
                }
            }

            ForEach(upsResults.isEmpty ? (store.relays?.upsPoints ?? []) : upsResults) { ups in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(ups.carrier)
                            .font(.system(size: 10.5, weight: .black))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LivriaPalette.goldSoft))
                            .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                        Spacer()
                        Text("À \(ups.distance)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LivriaPalette.primary)
                    }

                    Text(ups.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)

                    Label("\(ups.address), \(ups.postalCode) \(ups.city)", systemImage: "mappin.circle.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(LivriaPalette.inkMuted)

                    Label("Ouverture : \(ups.hours)", systemImage: "clock.badge.checkmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LivriaPalette.mint)

                    HStack {
                        Button {
                            store.selectedRelayForCheckout = "\(ups.name) — \(ups.address), \(ups.postalCode) \(ups.city)"
                            store.showToast("Relais UPS « \(ups.name) » sélectionné pour votre Checkout !")
                        } label: {
                            Label("Sélectionner ce relais UPS", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(ups.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
                .livriaCard()
            }
        }
    }

    private var addCommunityRelaySheet: some View {
        NavigationStack {
            Form {
                Section("Informations du Point Relais Communautaire") {
                    TextField("Nom du point relais / boîte à livres", text: $newRelayName)
                    Picker("Catégorie", selection: $newRelayType) {
                        Text("Boîte à Livres Citoyenne").tag("Boîte à Livres Citoyenne")
                        Text("Point Relais Livria / Café-Librairie").tag("Point Relais Livria")
                    }
                    TextField("Adresse", text: $newRelayAddress)
                    TextField("Code postal", text: $newRelayPostalCode)
                    TextField("Ville", text: $newRelayCity)
                    TextField("Horaires d'ouverture", text: $newRelayHours)
                    TextField("Description / instructions d'accès", text: $newRelayDesc)
                }
            }
            .navigationTitle("Proposer un Point Relais")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        showingAddCommunityRelay = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publier") {
                        Task {
                            await store.createCommunityRelay(
                                name: newRelayName,
                                type: newRelayType,
                                address: newRelayAddress,
                                city: newRelayCity,
                                postalCode: newRelayPostalCode,
                                openingHours: newRelayHours,
                                description: newRelayDesc
                            )
                            showingAddCommunityRelay = false
                        }
                    }
                    .disabled(newRelayName.isEmpty || newRelayCity.isEmpty)
                }
            }
        }
    }
}
