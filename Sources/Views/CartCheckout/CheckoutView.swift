import SwiftUI
import WebKit
import CoreLocation

// MARK: - Feuille Web d'Approbation PayPal Sécurisée (WKWebView)

public struct PayPalApprovalSessionItem: Identifiable {
    public let id: String
    public let approveURL: URL
    public let amount: Double
}

public struct PayPalApprovalWebSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let session: PayPalApprovalSessionItem
    public let onApproved: (String) -> Void
    public let onCancelled: () -> Void

    @State private var isLoadingPage: Bool = true

    public var body: some View {
        NavigationStack {
            ZStack {
                PayPalWebViewRepresentable(
                    approveURL: session.approveURL,
                    fallbackOrderId: session.id,
                    isLoading: $isLoadingPage,
                    onApproved: { token in
                        dismiss()
                        onApproved(token)
                    },
                    onCancelled: {
                        dismiss()
                        onCancelled()
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoadingPage {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(LivriaPalette.primary)
                        Text("Connexion sécurisée à PayPal...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle(String(format: "Règlement PayPal (%.2f €)", session.amount))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                        onCancelled()
                    }
                }
            }
        }
    }
}

private struct PayPalWebViewRepresentable: UIViewRepresentable {
    let approveURL: URL
    let fallbackOrderId: String
    @Binding var isLoading: Bool
    let onApproved: (String) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            fallbackOrderId: fallbackOrderId,
            isLoading: $isLoading,
            onApproved: onApproved,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: approveURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let fallbackOrderId: String
        @Binding var isLoading: Bool
        let onApproved: (String) -> Void
        let onCancelled: () -> Void
        private var hasCompleted = false

        init(
            fallbackOrderId: String,
            isLoading: Binding<Bool>,
            onApproved: @escaping (String) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.fallbackOrderId = fallbackOrderId
            self._isLoading = isLoading
            self.onApproved = onApproved
            self.onCancelled = onCancelled
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let urlString = url.absoluteString.lowercased()

            if urlString.contains("/checkout/paypal-return") || (urlString.contains("payerid=") && urlString.contains("token=")) {
                decisionHandler(.cancel)
                guard !hasCompleted else { return }
                hasCompleted = true

                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let token = comps?.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value ?? fallbackOrderId
                DispatchQueue.main.async {
                    self.onApproved(token)
                }
                return
            }

            if urlString.contains("/checkout/paypal-cancel") {
                decisionHandler(.cancel)
                guard !hasCompleted else { return }
                hasCompleted = true
                DispatchQueue.main.async {
                    self.onCancelled()
                }
                return
            }

            decisionHandler(.allow)
        }
    }
}

// MARK: - Checkout Complet Livria Store (Vérification Stricte PayPal hors BuyGod + Relais GPS/Code Postal + Bordereau UPS)

public struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @StateObject private var locationHelper = LivriaLocationHelper()

    @State private var guestEmail: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var postalCode: String = ""
    @State private var city: String = ""

    @State private var selectedPaymentMethod: String = "PayPal"
    @State private var isClickAndCollect: Bool = false
    @State private var selectedRelayId: Int? = nil
    @State private var selectedUpsPointId: String = ""
    @State private var relaySearchQuery: String = ""
    @State private var upsRelayResults: [LivriaUpsPickupPoint] = []
    @State private var isSearchingRelays: Bool = false

    @State private var isGiftWrapped: Bool = false
    @State private var giftMessage: String = ""
    @State private var isZeroWaste: Bool = true
    @State private var useLoyaltyPoints: Bool = false
    @State private var useCashback: Bool = false

    @State private var isSubmitting: Bool = false
    @State private var paymentErrorMessage: String? = nil
    @State private var activePayPalSession: PayPalApprovalSessionItem? = nil
    @State private var completedOrder: LivriaCheckoutResponse? = nil
    @State private var showingLabelSheet: Bool = false

    // Création de compte en 1 clic après commande
    @State private var postOrderPassword: String = ""
    @State private var isFinalizingAccount: Bool = false
    @State private var accountFinalizedSuccess: Bool = false
    @State private var accountFinalizedError: String? = nil

    public init() {}

    private var netPayableAmount: Double {
        let giftFee = isGiftWrapped ? 2.50 : 0.0
        var total = store.cartTotal + giftFee
        if useLoyaltyPoints {
            let pts = store.currentUser?.loyaltyPoints ?? 0
            let chunks = pts / 100
            let maxDiscount = min(Double(chunks) * 5.0, store.cartSubtotal)
            total -= maxDiscount
        }
        if useCashback {
            let cb = store.currentUser?.cashbackBalance ?? 0
            total -= min(cb, max(0, total))
        }
        return max(0.0, (total * 100).rounded() / 100)
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let done = completedOrder, done.ok {
                        orderSuccessCard(done: done)
                    } else {
                        expressWalletsViaPayPalCard
                        deliveryModeSelector
                        recipientAddressCard
                        optionsAndRewardsCard
                        orderRecapCard
                        if let err = paymentErrorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(err)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.10)))
                        }
                        confirmOrderButton
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Validation de commande")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let u = store.currentUser {
                    if !store.isGuestSession {
                        guestEmail = u.email
                        firstName = u.firstName.isEmpty ? u.displayName : u.firstName
                        lastName = u.lastName
                    }
                    phone = u.phone
                    address = u.address
                    postalCode = u.postalCode
                    city = u.city
                    relaySearchQuery = u.postalCode
                }
                upsRelayResults = store.relays?.upsPoints ?? []
            }
            .sheet(item: $activePayPalSession) { sessionItem in
                PayPalApprovalWebSheet(
                    session: sessionItem,
                    onApproved: { approvedOrderId in
                        finalizeOrderAfterVerifiedPayment(payPalOrderId: approvedOrderId)
                    },
                    onCancelled: {
                        isSubmitting = false
                        paymentErrorMessage = "Le paiement PayPal a été annulé. Votre commande n'a pas été validée."
                    }
                )
            }
            .sheet(isPresented: $showingLabelSheet) {
                if let done = completedOrder {
                    let labelUrl = done.labelUrl ?? "\(LivriaURLResolver.baseWebURL)/api/mobile/v1/orders/\(done.orderId ?? 0)/label"
                    LivriaUPSLabelViewerSheet(
                        labelUrlString: labelUrl,
                        reference: done.reference ?? "Commande",
                        trackingNumber: done.trackingNumber
                    )
                }
            }
        }
    }

    // MARK: - Paiement Sécurisé PayPal / Apple Pay / Google Pay

    private var expressWalletsViaPayPalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Mode de règlement sécurisé")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                if store.isBuyGodUser {
                    Text("Privilège BuyGod actif")
                        .font(.system(size: 10.5, weight: .heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(LivriaPalette.goldSoft))
                        .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                } else {
                    Text("100% Sécurisé")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LivriaPalette.mint.opacity(0.16)))
                        .foregroundStyle(LivriaPalette.mint)
                }
            }

            HStack(spacing: 10) {
                // PayPal
                Button {
                    selectedPaymentMethod = "PayPal"
                    startCheckoutFlow(walletSource: "paypal")
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "p.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("PayPal")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.0, green: 0.44, blue: 0.73)))
                    .foregroundStyle(.white)
                }

                // Apple Pay
                Button {
                    selectedPaymentMethod = "ApplePay_PayPal"
                    startCheckoutFlow(walletSource: "apple_pay")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .bold))
                        Text("Pay")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black))
                    .foregroundStyle(.white)
                }

                // Google Pay
                Button {
                    selectedPaymentMethod = "GooglePay_PayPal"
                    startCheckoutFlow(walletSource: "google_pay")
                } label: {
                    HStack(spacing: 5) {
                        Text("G")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                        Text("Pay")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.18), lineWidth: 1))
                }
            }

            Text("Votre commande est validée et expédiée par UPS dès confirmation de votre paiement.")
                .font(.system(size: 11.5))
                .foregroundStyle(LivriaPalette.inkMuted)
        }
        .livriaCard()
    }

    // MARK: - Mode de Livraison + Recherche Points Relais par Code Postal ou GPS

    private var deliveryModeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode de livraison")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            HStack(spacing: 10) {
                Button {
                    isClickAndCollect = false
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "truck.box.fill")
                            .font(.title2)
                        Text("Livraison à domicile")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Colis UPS suivi")
                            .font(.system(size: 10.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(!isClickAndCollect ? LivriaPalette.primary : LivriaPalette.background))
                    .foregroundStyle(!isClickAndCollect ? .white : LivriaPalette.ink)
                }

                Button {
                    isClickAndCollect = true
                    if upsRelayResults.isEmpty {
                        let initialCp = postalCode.isEmpty ? "75001" : postalCode
                        relaySearchQuery = initialCp
                        Task {
                            await searchRelaysForCheckout(query: initialCp)
                        }
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title2)
                        Text("Point Relais UPS")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Retrait près de chez vous")
                            .font(.system(size: 10.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(isClickAndCollect ? LivriaPalette.primary : LivriaPalette.background))
                    .foregroundStyle(isClickAndCollect ? .white : LivriaPalette.ink)
                }
            }
            .buttonStyle(.plain)

            if isClickAndCollect {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Rechercher un Point Relais par code postal ou GPS :")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)

                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(LivriaPalette.primary)
                            TextField("Code postal ou ville (ex: 08000, 75001...)", text: $relaySearchQuery)
                                .submitLabel(.search)
                                .onSubmit {
                                    Task {
                                        await searchRelaysForCheckout(query: relaySearchQuery)
                                    }
                                }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                        Button {
                            Task {
                                await searchRelaysForCheckout(query: relaySearchQuery)
                            }
                        } label: {
                            if isSearchingRelays {
                                ProgressView()
                                    .tint(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            } else {
                                Text("Chercher")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.gold))
                        .foregroundStyle(.black)

                        Button {
                            locationHelper.requestUserLocation { coord in
                                Task {
                                    isSearchingRelays = true
                                    if let res = await store.searchUpsRelaysDetailed(query: "", lat: coord.latitude, lon: coord.longitude) {
                                        upsRelayResults = res.points
                                        if let cp = res.resolvedPostalCode, !cp.isEmpty {
                                            relaySearchQuery = cp
                                        }
                                    }
                                    isSearchingRelays = false
                                }
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .bold))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                    }

                    ForEach(upsRelayResults.prefix(8)) { ups in
                        Button {
                            selectedUpsPointId = ups.id
                            selectedRelayId = nil
                            address = "\(ups.name) - \(ups.address)"
                            postalCode = ups.postalCode
                            city = ups.city
                        } label: {
                            HStack {
                                Image(systemName: selectedUpsPointId == ups.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedUpsPointId == ups.id ? LivriaPalette.mint : LivriaPalette.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ups.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LivriaPalette.ink)
                                    Text("\(ups.address), \(ups.postalCode) \(ups.city) • \(ups.distance)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(LivriaPalette.inkMuted)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedUpsPointId == ups.id ? LivriaPalette.primarySoft.opacity(0.6) : LivriaPalette.background)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(store.relays?.communityPoints ?? []) { pt in
                        Button {
                            selectedRelayId = pt.id
                            selectedUpsPointId = ""
                            address = "\(pt.name) - \(pt.address)"
                            postalCode = pt.postalCode
                            city = pt.city
                        } label: {
                            HStack {
                                Image(systemName: selectedRelayId == pt.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(LivriaPalette.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pt.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LivriaPalette.ink)
                                    Text("\(pt.address), \(pt.postalCode) \(pt.city)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(LivriaPalette.inkMuted)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .livriaCard()
    }

    private func searchRelaysForCheckout(query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearchingRelays = true
        if let res = await store.searchUpsRelaysDetailed(query: q) {
            upsRelayResults = res.points
        }
        isSearchingRelays = false
    }

    // MARK: - Coordonnées du Destinataire

    private var recipientAddressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Coordonnées de livraison")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                if store.isGuestSession {
                    Text("Achat rapide")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }

            TextField("Adresse e-mail (confirmation & suivi de colis)", text: $guestEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            HStack(spacing: 10) {
                TextField("Prénom", text: $firstName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                TextField("Nom", text: $lastName)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            TextField("Téléphone mobile (notifications SMS du livreur)", text: $phone)
                .keyboardType(.phonePad)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            TextField("Adresse postale ou Point Relais", text: $address)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            HStack(spacing: 10) {
                TextField("Code postal", text: $postalCode)
                    .frame(width: 115)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                TextField("Ville", text: $city)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }
        }
        .livriaCard()
    }

    private var optionsAndRewardsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options & Fidélité")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            Toggle("🌱 Emballage Zéro Déchet réutilisable (Gratuit)", isOn: $isZeroWaste)
                .font(.system(size: 13.5, weight: .semibold))
                .tint(LivriaPalette.mint)

            Toggle("🎁 Papier cadeau artisanal Livria (+2,50 €)", isOn: $isGiftWrapped)
                .font(.system(size: 13.5, weight: .semibold))
                .tint(LivriaPalette.coral)

            if isGiftWrapped {
                TextField("Votre mot doux joint au colis...", text: $giftMessage)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
            }

            if (store.currentUser?.loyaltyPoints ?? 0) >= 100 {
                Toggle("⭐ Utiliser mes points de fidélité (\(store.currentUser?.loyaltyPoints ?? 0) pts disponibles)", isOn: $useLoyaltyPoints)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tint(LivriaPalette.primary)
            }

            if (store.currentUser?.cashbackBalance ?? 0) > 0 {
                Toggle(String(format: "💶 Utiliser ma cagnotte Looby+ (%.2f €)", store.currentUser?.cashbackBalance ?? 0), isOn: $useCashback)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tint(LivriaPalette.gold)
            }
        }
        .livriaCard()
    }

    private var orderRecapCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Articles (\(store.cartItemsCount))")
                Spacer()
                Text(String(format: "%.2f €", store.cartSubtotal))
            }
            HStack {
                Text("Expédition UPS / Point Relais")
                Spacer()
                Text(store.cartShippingCost == 0 ? "Offerte (0,00 €)" : String(format: "%.2f €", store.cartShippingCost))
            }
            if isGiftWrapped {
                HStack {
                    Text("Emballage Cadeau")
                    Spacer()
                    Text("2,50 €")
                }
            }
            Divider()
            HStack {
                Text("Total à régler")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(String(format: "%.2f €", netPayableAmount))
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.primary)
            }
        }
        .font(.system(size: 14))
        .livriaCard()
    }

    private var confirmOrderButton: some View {
        Button {
            startCheckoutFlow(walletSource: "paypal")
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "lock.fill")
                }
                Text(
                    store.isBuyGodUser || netPayableAmount <= 0
                        ? "Valider ma commande (\(String(format: "%.2f €", netPayableAmount)))"
                        : "Payer avec PayPal et valider (\(String(format: "%.2f €", netPayableAmount)))"
                )
                .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isSubmitting || store.cart.isEmpty)
    }

    // MARK: - Confirmation de Commande + Bordereau UPS + Création de Compte 1-Clic

    private func orderSuccessCard(done: LivriaCheckoutResponse) -> some View {
        let prefilledEmail = (done.checkoutEmail?.isEmpty == false) ? done.checkoutEmail! : guestEmail
        let prefilledFirst = (done.checkoutFirstName?.isEmpty == false) ? done.checkoutFirstName! : firstName
        let prefilledLast = (done.checkoutLastName?.isEmpty == false) ? done.checkoutLastName! : lastName
        let fullName = "\(prefilledFirst) \(prefilledLast)".trimmingCharacters(in: .whitespaces)

        return VStack(spacing: 18) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(LivriaPalette.mint)

                Text("Commande confirmée !")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)

                Text(done.message ?? "Votre commande a été enregistrée et votre bordereau UPS est prêt.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivriaPalette.inkMuted)
                    .multilineTextAlignment(.center)

                if let ref = done.reference {
                    Text("Référence : \(ref)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(LivriaPalette.primary)
                }

                if let trk = done.trackingNumber, !trk.isEmpty {
                    VStack(spacing: 6) {
                        Text("Bordereau UPS généré • N° de suivi :")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LivriaPalette.inkMuted)
                        Text(trk)
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.goldSoft))
                    }
                }

                Button {
                    showingLabelSheet = true
                } label: {
                    Label("Afficher / Télécharger mon Bordereau UPS", systemImage: "doc.viewfinder.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.gold))
                        .foregroundStyle(.black)
                }

                if let urlStr = done.deliveryUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Suivre mon colis en direct", systemImage: "location.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }
            }
            .livriaCard(padding: 22)

            if (done.canCreateAccount == true || store.isGuestSession) && !accountFinalizedSuccess {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                            .foregroundStyle(LivriaPalette.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Créer mon compte en 1 clic")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.ink)
                            Text("Vos informations sont déjà pré-remplies : choisissez simplement un mot de passe !")
                                .font(.system(size: 12))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(LivriaPalette.primary)
                            Text(prefilledEmail.isEmpty ? "Invité Livria" : prefilledEmail)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                            Spacer()
                            Text("Pré-rempli ✓")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LivriaPalette.mint)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                        if !fullName.isEmpty {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(LivriaPalette.primary)
                                Text(fullName)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(LivriaPalette.ink)
                                Spacer()
                                Text("Pré-rempli ✓")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LivriaPalette.mint)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        }
                    }

                    SecureField("Choisissez votre mot de passe (6 caractères min.)", text: $postOrderPassword)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LivriaPalette.border, lineWidth: 1))

                    if let err = accountFinalizedError {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        finalizeGuestAccount(
                            email: prefilledEmail,
                            first: prefilledFirst,
                            last: prefilledLast,
                            orderRef: done.reference ?? ""
                        )
                    } label: {
                        HStack {
                            if isFinalizingAccount {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("Activer mon compte & rattacher ma commande")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(postOrderPassword.count < 6 || isFinalizingAccount)
                }
                .livriaCard(padding: 18)
            } else if accountFinalizedSuccess {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(LivriaPalette.mint)
                    Text("Votre compte est maintenant actif et votre commande y est rattachée !")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                }
                .livriaCard()
            }

            Button("Fermer") {
                dismiss()
            }
            .font(.system(size: 14, weight: .bold))
            .padding(.top, 4)
        }
    }

    // MARK: - Flux de Paiement PayPal & Vérification Rôle BuyGod

    private func startCheckoutFlow(walletSource: String) {
        paymentErrorMessage = nil

        if address.trimmingCharacters(in: .whitespaces).isEmpty ||
            postalCode.trimmingCharacters(in: .whitespaces).isEmpty ||
            city.trimmingCharacters(in: .whitespaces).isEmpty {
            paymentErrorMessage = "Veuillez renseigner votre adresse complète (ou sélectionner un Point Relais) avant de régler."
            return
        }

        let amountToPay = netPayableAmount

        // Si l'utilisateur possède le rôle buygod ou si le net à payer est de 0 € (points/cagnotte), validation directe autorisée
        if store.isBuyGodUser || amountToPay <= 0.0 {
            finalizeOrderAfterVerifiedPayment(payPalOrderId: nil)
            return
        }

        // Sinon (hors buygod), le paiement PayPal DOIT obligatoirement être créé, redirigé et approuvé avant toute validation
        isSubmitting = true
        Task {
            guard let session = await store.createPayPalExpressSession(walletSource: walletSource, amount: amountToPay),
                  session.ok,
                  let approveStr = session.approveUrl,
                  let approveURL = URL(string: approveStr),
                  let orderId = session.payPalOrderId,
                  !orderId.isEmpty else {
                isSubmitting = false
                paymentErrorMessage = "Impossible d'initialiser la redirection vers PayPal. Votre commande n'a pas été validée."
                return
            }

            // Ouvre la feuille web PayPal pour que l'utilisateur valide réellement son paiement
            activePayPalSession = PayPalApprovalSessionItem(
                id: orderId,
                approveURL: approveURL,
                amount: amountToPay
            )
        }
    }

    private func finalizeOrderAfterVerifiedPayment(payPalOrderId: String?) {
        paymentErrorMessage = nil
        isSubmitting = true
        let pts = useLoyaltyPoints ? (store.currentUser?.loyaltyPoints ?? 0) : 0
        let cb = useCashback ? (store.currentUser?.cashbackBalance ?? 0) : 0
        Task {
            let res = await store.placeOrder(
                email: guestEmail,
                firstName: firstName,
                lastName: lastName,
                phone: phone,
                address: address,
                postalCode: postalCode,
                city: city,
                paymentMethod: selectedPaymentMethod,
                pointsToSpend: pts,
                cashbackToSpend: cb,
                isGiftWrapped: isGiftWrapped,
                giftMessage: giftMessage,
                isZeroWaste: isZeroWaste,
                isClickAndCollect: isClickAndCollect,
                relayId: selectedRelayId,
                payPalOrderId: payPalOrderId
            )
            isSubmitting = false
            if let res, res.ok {
                completedOrder = res
            } else {
                paymentErrorMessage = res?.message ?? "Le paiement n'a pas pu être confirmé auprès de PayPal. La commande n'a pas été traitée."
            }
        }
    }

    private func finalizeGuestAccount(email: String, first: String, last: String, orderRef: String) {
        accountFinalizedError = nil
        isFinalizingAccount = true
        Task {
            let ok = await store.finalizePostCheckoutAccount(
                email: email,
                password: postOrderPassword,
                firstName: first,
                lastName: last,
                phone: phone,
                address: address,
                postalCode: postalCode,
                city: city,
                orderReference: orderRef
            )
            isFinalizingAccount = false
            if ok {
                accountFinalizedSuccess = true
            } else {
                accountFinalizedError = store.authErrorMessage ?? "Impossible de finaliser le compte."
            }
        }
    }
}
