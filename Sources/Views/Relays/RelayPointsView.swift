import SwiftUI
import MapKit
@preconcurrency import CoreLocation

// MARK: - Gestionnaire de Géolocalisation GPS (comme sur delivery.viplenetwork.com)

@MainActor
public final class LivriaLocationHelper: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published public var currentCoordinate: CLLocationCoordinate2D? = nil
    @Published public var isLocating: Bool = false
    @Published public var locationError: String? = nil

    private let manager = CLLocationManager()
    private var onLocationResolved: ((CLLocationCoordinate2D) -> Void)?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func requestUserLocation(completion: @escaping (CLLocationCoordinate2D) -> Void) {
        self.locationError = nil
        self.isLocating = true
        self.onLocationResolved = completion

        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            self.isLocating = false
            self.locationError = "Autorisez la localisation dans les Réglages iOS pour trouver les points relais autour de vous."
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if isLocating {
                manager.requestLocation()
            }
        } else if status == .denied || status == .restricted {
            isLocating = false
            locationError = "La localisation GPS est désactivée. Vous pouvez rechercher par code postal ou ville."
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            isLocating = false
            return
        }
        isLocating = false
        let coord = loc.coordinate
        currentCoordinate = coord
        onLocationResolved?(coord)
        onLocationResolved = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        locationError = "Impossible d'obtenir votre position GPS actuelle. Saisissez un code postal ci-dessus."
    }
}

// MARK: - Points Relais UPS & Boîtes à Livres avec Carte Interactive & Géolocalisation Directe

public struct RelayPointsView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @StateObject private var locationHelper = LivriaLocationHelper()

    public enum RelayTab: String, CaseIterable {
        case ups = "Points Relais UPS"
        case community = "Boîtes à Livres & Relais"
    }

    @State private var selectedTab: RelayTab = .ups
    @State private var upsSearchQuery: String = ""
    @State private var upsResults: [LivriaUpsPickupPoint] = []
    @State private var isSearchingUps: Bool = false
    @State private var resolvedAreaLabel: String = ""
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    @State private var selectedPointOnMap: LivriaUpsPickupPoint? = nil

    // Relais communautaires
    @State private var searchQuery: String = ""
    @State private var showingAddCommunityRelay: Bool = false
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
            VStack(alignment: .leading, spacing: 16) {
                Picker("Type de Point Relais", selection: $selectedTab) {
                    ForEach(RelayTab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .ups {
                    upsRelaysSection
                } else {
                    communityRelaysSection
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Points Relais & Carte")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await initialLoadRelays()
        }
        .sheet(isPresented: $showingAddCommunityRelay) {
            addCommunityRelaySheet
        }
    }

    // MARK: - Chargement Initial : Localisation GPS Automatique ou Code Postal du Profil

    private func initialLoadRelays() async {
        if let userCp = store.currentUser?.postalCode, !userCp.trimmingCharacters(in: .whitespaces).isEmpty {
            upsSearchQuery = userCp
        }
        if !upsResults.isEmpty { return }

        if let initialUps = store.relays?.upsPoints, !initialUps.isEmpty {
            upsResults = initialUps
            updateMapRegion(points: initialUps, centerLat: nil, centerLon: nil)
        }

        // Déclenche automatiquement la géolocalisation comme sur delivery.viplenetwork.com
        locateMeAndFetchRelays(silentIfDenied: true)
    }

    private func locateMeAndFetchRelays(silentIfDenied: Bool = false) {
        locationHelper.requestUserLocation { coord in
            Task {
                await performUpsSearchByCoordinates(lat: coord.latitude, lon: coord.longitude)
            }
        }
        if silentIfDenied, upsResults.isEmpty {
            let fallbackQuery = upsSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty ? "75001" : upsSearchQuery
            Task {
                await performUpsSearchByQuery(fallbackQuery)
            }
        }
    }

    private func performUpsSearchByQuery(_ rawQuery: String) async {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearchingUps = true
        let response = await store.searchUpsRelaysDetailed(query: q)
        isSearchingUps = false
        if let response {
            upsResults = response.points
            let cityLabel = [response.resolvedPostalCode, response.resolvedCity]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            resolvedAreaLabel = cityLabel.isEmpty ? q : cityLabel
            updateMapRegion(
                points: response.points,
                centerLat: response.searchCenterLat,
                centerLon: response.searchCenterLon
            )
        }
    }

    private func performUpsSearchByCoordinates(lat: Double, lon: Double) async {
        isSearchingUps = true
        let response = await store.searchUpsRelaysDetailed(query: "", lat: lat, lon: lon)
        isSearchingUps = false
        if let response {
            upsResults = response.points
            let cityLabel = [response.resolvedPostalCode, response.resolvedCity]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !cityLabel.isEmpty {
                upsSearchQuery = response.resolvedPostalCode ?? cityLabel
                resolvedAreaLabel = "Autour de vous (\(cityLabel))"
            } else {
                resolvedAreaLabel = "Autour de votre position GPS"
            }
            updateMapRegion(
                points: response.points,
                centerLat: response.searchCenterLat ?? lat,
                centerLon: response.searchCenterLon ?? lon
            )
        }
    }

    private func updateMapRegion(points: [LivriaUpsPickupPoint], centerLat: Double?, centerLon: Double?) {
        if let lat = centerLat, let lon = centerLon, lat != 0, lon != 0 {
            withAnimation(.easeInOut(duration: 0.45)) {
                mapCameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
                    )
                )
            }
        } else if let first = points.first, let lat = first.latitude, let lon = first.longitude {
            withAnimation(.easeInOut(duration: 0.45)) {
                mapCameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
                    )
                )
            }
        }
    }

    // MARK: - Onglet 1 : Points Relais UPS Access Point™ (Recherche Code Postal + GPS + Carte Interactive)

    private var upsRelaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Barre de recherche par Code Postal / Ville + Bouton "Me localiser"
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(LivriaPalette.primary)
                        TextField("Code postal ou ville (ex: 08000, 75001, Lyon...)", text: $upsSearchQuery)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task {
                                    await performUpsSearchByQuery(upsSearchQuery)
                                }
                            }
                        if !upsSearchQuery.isEmpty {
                            Button {
                                upsSearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(LivriaPalette.inkMuted)
                            }
                        }
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

                    Button {
                        Task {
                            await performUpsSearchByQuery(upsSearchQuery)
                        }
                    } label: {
                        if isSearchingUps {
                            ProgressView()
                                .tint(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                        } else {
                            Text("Chercher")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
                    .disabled(upsSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearchingUps)
                }

                // Bouton Géolocalisation Directe (comme sur delivery.viplenetwork.com)
                HStack(spacing: 10) {
                    Button {
                        locateMeAndFetchRelays(silentIfDenied: false)
                    } label: {
                        HStack(spacing: 7) {
                            if locationHelper.isLocating {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(locationHelper.isLocating ? "Localisation GPS en cours..." : "Me localiser autour de moi")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [LivriaPalette.primary, LivriaPalette.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(locationHelper.isLocating)

                    if let selected = store.selectedRelayForCheckout, !selected.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(LivriaPalette.mint)
                            Text("Relais actif")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.mint)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.mint.opacity(0.14)))
                    }
                }

                if let locErr = locationHelper.locationError {
                    Text(locErr)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .livriaCard(padding: 14)

            // Carte Interactive des Points Relais UPS
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        resolvedAreaLabel.isEmpty
                            ? "\(upsResults.count) Points Relais UPS disponibles"
                            : "\(upsResults.count) Points Relais UPS • \(resolvedAreaLabel)",
                        systemImage: "map.fill"
                    )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                    Spacer()
                }

                Map(position: $mapCameraPosition) {
                    if let userCoord = locationHelper.currentCoordinate {
                        Annotation("Ma position", coordinate: userCoord) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.25))
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                        }
                    }

                    ForEach(upsResults) { pt in
                        if let lat = pt.latitude, let lon = pt.longitude {
                            Annotation(pt.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                Button {
                                    selectedPointOnMap = pt
                                } label: {
                                    VStack(spacing: 2) {
                                        ZStack {
                                            Circle()
                                                .fill(LivriaPalette.gold)
                                                .frame(width: 32, height: 32)
                                                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                                            Image(systemName: "shippingbox.fill")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.black)
                                        }
                                        Text(pt.distance)
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(LivriaPalette.cardPaper))
                                            .foregroundStyle(LivriaPalette.ink)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: 225)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LivriaPalette.border, lineWidth: 1)
                )

                if let sel = selectedPointOnMap {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sel.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                            Text("\(sel.address), \(sel.postalCode) \(sel.city) • \(sel.distance)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        Spacer()
                        Button {
                            selectUpsRelay(sel)
                        } label: {
                            Text("Choisir")
                                .font(.system(size: 12.5, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primarySoft.opacity(0.6)))
                }
            }
            .livriaCard(padding: 12)

            // Liste des Points Relais UPS trouvés
            if upsResults.isEmpty && !isSearchingUps {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(LivriaPalette.gold)
                    Text("Entrez un code postal ou cliquez sur « Me localiser » pour afficher les points relais UPS.")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .livriaCard()
            } else {
                ForEach(upsResults) { ups in
                    let isCurrentlyChosen = store.selectedRelayForCheckout?.contains(ups.name) == true
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.caption)
                                Text(ups.carrier)
                                    .font(.system(size: 10.5, weight: .black))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(LivriaPalette.goldSoft))
                            .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))

                            Spacer()

                            Text("À \(ups.distance)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(LivriaPalette.primarySoft))
                                .foregroundStyle(LivriaPalette.primaryDeep)
                        }

                        Text(ups.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)

                        Label("\(ups.address), \(ups.postalCode) \(ups.city)", systemImage: "mappin.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(LivriaPalette.inkMuted)

                        Label("Horaires : \(ups.hours)", systemImage: "clock.badge.checkmark.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.mint)

                        HStack(spacing: 10) {
                            Button {
                                selectUpsRelay(ups)
                            } label: {
                                Label(
                                    isCurrentlyChosen ? "Point Relais sélectionné" : "Choisir ce Point Relais",
                                    systemImage: isCurrentlyChosen ? "checkmark.seal.fill" : "mappin.and.ellipse"
                                )
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isCurrentlyChosen ? LivriaPalette.mint : LivriaPalette.primary)
                                )
                                .foregroundStyle(.white)
                            }

                            Spacer()

                            if let lat = ups.latitude, let lon = ups.longitude,
                               let mapsUrl = URL(string: "http://maps.apple.com/?ll=\(lat),\(lon)&q=\(ups.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "UPS")") {
                                Link(destination: mapsUrl) {
                                    Label("Itinéraire", systemImage: "location.north.line.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
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

    private func selectUpsRelay(_ ups: LivriaUpsPickupPoint) {
        store.selectedRelayForCheckout = "\(ups.name) — \(ups.address), \(ups.postalCode) \(ups.city)"
        store.showToast("Point Relais « \(ups.name) » sélectionné pour votre livraison !")
    }

    // MARK: - Onglet 2 : Points Relais Communautaires & Boîtes à Livres

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
                    Text("Aucune boîte à livres ou relais communautaire trouvé pour cette recherche.")
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

    private var addCommunityRelaySheet: some View {
        NavigationStack {
            Form {
                Section("Informations de la Boîte à Livres / Point Relais") {
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
