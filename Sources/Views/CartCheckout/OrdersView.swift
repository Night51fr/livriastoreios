import SwiftUI
import WebKit

// MARK: - Visionneuse du Bordereau d'Expédition Officiel UPS (LivriaUPSLabelViewerSheet)

public struct LivriaUPSLabelViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let labelUrlString: String
    public let reference: String
    public let trackingNumber: String?

    public init(labelUrlString: String, reference: String, trackingNumber: String?) {
        self.labelUrlString = labelUrlString
        self.reference = reference
        self.trackingNumber = trackingNumber
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(LivriaPalette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bordereau d'expédition UPS • \(reference)")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        if let trk = trackingNumber, !trk.isEmpty {
                            Text("N° de suivi : \(trk)")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                    }
                    Spacer()
                    if let url = URL(string: labelUrlString) {
                        ShareLink(item: url) {
                            Label("Partager / Imprimer", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(14)
                .background(LivriaPalette.cardPaper)

                Divider()

                if let url = URL(string: labelUrlString) {
                    LivriaSimpleWebView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Spacer()
                    Text("Bordereau UPS indisponible pour cette commande.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                }
            }
            .navigationTitle("Bordereau UPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

public struct LivriaSimpleWebView: UIViewRepresentable {
    public let url: URL

    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Mes Commandes & Suivi UPS (OrdersView avec Confirmation d'Annulation & Bordereau UPS)

public struct OrdersView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    public enum OrderFilter: String, CaseIterable {
        case all = "Toutes"
        case active = "En cours"
        case shipped = "Expédiées"
        case delivered = "Livrées"
        case cancelled = "Annulées"
    }

    @State private var orderPendingCancellation: LivriaOrder? = nil
    @State private var showingCancelConfirmation: Bool = false
    @State private var isCancellingOrderId: Int? = nil
    @State private var selectedOrderForLabel: LivriaOrder? = nil
    @State private var trackingLookupCode: String = ""
    @State private var selectedFilter: OrderFilter = .all
    @State private var orderSearchQuery: String = ""

    public init() {}

    private var filteredOrders: [LivriaOrder] {
        var list = store.orders
        switch selectedFilter {
        case .all:
            break
        case .active:
            list = list.filter { $0.status == "Pending" || $0.status == "Processing" || $0.status == "Paid" }
        case .shipped:
            list = list.filter { $0.status == "Shipped" }
        case .delivered:
            list = list.filter { $0.status == "Delivered" }
        case .cancelled:
            list = list.filter { $0.status == "Cancelled" }
        }
        let q = orderSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter { order in
                order.reference.localizedCaseInsensitiveContains(q) ||
                (order.trackingNumber ?? "").localizedCaseInsensitiveContains(q) ||
                order.items.contains(where: { $0.title.localizedCaseInsensitiveContains(q) || $0.author.localizedCaseInsensitiveContains(q) })
            }
        }
        return list
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                vipleDeliveryLookupCard

                if !store.orders.isEmpty {
                    ordersFilterHeader
                }

                if filteredOrders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(LivriaPalette.primary)
                        Text(store.orders.isEmpty ? "Aucune commande pour le moment" : "Aucune commande pour ce filtre")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Vos commandes apparaissent ici avec leur suivi Viple Delivery en direct intégré dans l'application (sans ouvrir le navigateur) et leur bordereau téléchargeable.")
                            .font(.system(size: 13))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .livriaCard(padding: 24)
                } else {
                    ForEach(filteredOrders) { order in
                        orderCard(order: order)
                    }
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Mes Commandes & Suivi")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refreshBootstrap()
            await store.refreshUserShipments()
        }
        .alert(
            "Voulez-vous vraiment annuler cette commande ?",
            isPresented: $showingCancelConfirmation,
            presenting: orderPendingCancellation
        ) { order in
            Button("Oui, annuler la commande", role: .destructive) {
                confirmOrderCancellation(order: order)
            }
            Button("Non, conserver ma commande", role: .cancel) {
                orderPendingCancellation = nil
            }
        } message: { order in
            Text("La commande \(order.reference) (\(String(format: "%.2f €", order.total))) sera immédiatement annulée.")
        }
        .sheet(item: $selectedOrderForLabel) { order in
            LivriaUPSLabelViewerSheet(
                labelUrlString: order.effectiveLabelUrl,
                reference: order.reference,
                trackingNumber: order.trackingNumber
            )
        }
        .sheet(isPresented: $store.isShowingVipleDeliverySheet) {
            if let tracking = store.activeTrackingResult {
                LivriaVipleDeliveryTrackingSheet(tracking: tracking)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Barre de Suivi Direct Viple Delivery Intégré (Sans ouvrir Safari)

    private var vipleDeliveryLookupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LivriaPalette.primarySoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suivi Viple Delivery en direct")
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                    Text("Suivez n'importe quel colis Livria ou Viple Delivery sans quitter l'application")
                        .font(.system(size: 11))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "barcode")
                        .foregroundStyle(LivriaPalette.primary)
                    TextField("N° commande (#LIV-...) ou suivi (1Z..., VD-...)", text: $trackingLookupCode)
                        .font(.system(size: 12.5, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if !trackingLookupCode.isEmpty {
                        Button {
                            trackingLookupCode = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

                Button {
                    Task {
                        await store.trackParcelByCodeInApp(trackingLookupCode)
                    }
                } label: {
                    if store.isTrackingLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                    } else {
                        Label("Suivre", systemImage: "location.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(store.isTrackingLoading || trackingLookupCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .livriaCard(padding: 14)
    }

    private var ordersFilterHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LivriaPalette.inkMuted)
                TextField("Filtrer mes commandes (titre, référence, suivi)...", text: $orderSearchQuery)
                    .font(.system(size: 12.5))
                if !orderSearchQuery.isEmpty {
                    Button {
                        orderSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.cardPaper))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LivriaPalette.border, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OrderFilter.allCases, id: \.self) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(isSelected ? LivriaPalette.primary : LivriaPalette.cardPaper))
                                .foregroundStyle(isSelected ? .white : LivriaPalette.ink)
                                .overlay(Capsule().stroke(LivriaPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func confirmOrderCancellation(order: LivriaOrder) {
        isCancellingOrderId = order.id
        orderPendingCancellation = nil
        Task {
            await store.cancelOrder(orderId: order.id)
            isCancellingOrderId = nil
        }
    }

    private func orderCard(order: LivriaOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(order.reference)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(LivriaPalette.primary)
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = order.reference
                            #endif
                            store.showToast("Référence \(order.reference) copiée.")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Passée le \(order.createdAt)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
                Spacer()
                Text(statusBadgeLabel(order.status))
                    .font(.system(size: 11.5, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(statusColor(order.status).opacity(0.16)))
                    .foregroundStyle(statusColor(order.status))
            }

            // Barre de progression rapide en 4 étapes
            if order.status != "Cancelled" {
                let currentIdx = order.currentStepIndex ?? (order.status == "Delivered" ? 3 : (order.status == "Shipped" ? 2 : 1))
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(step <= currentIdx ? LivriaPalette.primary : LivriaPalette.border)
                            .frame(height: 5)
                    }
                }
            }

            Divider()

            ForEach(order.items) { item in
                HStack(spacing: 12) {
                    LivriaBookCoverView(
                        coverUrl: item.coverUrl,
                        title: item.title,
                        width: 48,
                        height: 70,
                        cornerRadius: 8
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                            .lineLimit(1)
                        Text("\(item.quantity) × \(item.format) • \(String(format: "%.2f €", item.unitPrice))")
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                }
            }

            if order.status != "Cancelled" {
                HStack(spacing: 10) {
                    Image(systemName: "truck.box.badge.clock.fill")
                        .foregroundStyle(LivriaPalette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        if let trk = order.trackingNumber, !trk.isEmpty {
                            HStack(spacing: 6) {
                                Text("\(order.carrier) • Suivi : \(trk)")
                                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LivriaPalette.ink)
                                Button {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = trk
                                    #endif
                                    store.showToast("N° de suivi \(trk) copié.")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                        .foregroundStyle(LivriaPalette.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("Expédition Viple Delivery / UPS Standard")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                        }
                        if !order.shippingAddress.isEmpty {
                            Text(order.shippingAddress)
                                .font(.system(size: 11))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        if let est = order.estimatedDelivery, !est.isEmpty {
                            Text("Estimation : \(est)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(LivriaPalette.primary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
            }

            HStack(spacing: 8) {
                Text(String(format: "Total : %.2f €", order.total))
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)

                Spacer()

                if order.status != "Cancelled" {
                    Button {
                        selectedOrderForLabel = order
                    } label: {
                        Label("Bordereau", systemImage: "doc.viewfinder.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(LivriaPalette.goldSoft))
                            .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                    }

                    // Suivi Viple Delivery directement dans l'application (sans ouvrir Safari)
                    Button {
                        Task {
                            await store.trackOrderInApp(order: order)
                        }
                    } label: {
                        Label("Suivi en direct", systemImage: "location.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }

                if order.status == "Pending" || order.status == "Processing" || order.status == "Paid" || order.status == "Shipped" {
                    Button(role: .destructive) {
                        orderPendingCancellation = order
                        showingCancelConfirmation = true
                    } label: {
                        if isCancellingOrderId == order.id {
                            ProgressView()
                                .tint(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        } else {
                            Text("Annuler")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.red.opacity(0.12)))
                                .foregroundStyle(.red)
                        }
                    }
                    .disabled(isCancellingOrderId == order.id)
                }
            }
        }
        .livriaCard()
    }

    private func statusBadgeLabel(_ status: String) -> String {
        switch status {
        case "Paid": return "Payée • Préparation UPS"
        case "Shipped": return "Expédiée UPS"
        case "Delivered": return "Livrée"
        case "Cancelled": return "Annulée"
        default: return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Paid", "Shipped": return LivriaPalette.primary
        case "Delivered": return LivriaPalette.mint
        case "Cancelled": return .red
        default: return LivriaPalette.gold
        }
    }
}

// MARK: - Feuille de Suivi Natif Viple Delivery Intégré (Sans ouvrir Safari)

public struct LivriaVipleDeliveryTrackingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel
    @State public var tracking: LivriaVipleDeliveryTrackResponse
    @State private var isRefreshing: Bool = false
    @State private var showingLabelSheet: Bool = false

    public init(tracking: LivriaVipleDeliveryTrackResponse) {
        _tracking = State(initialValue: tracking)
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerStatusCard
                    visualProgressStepsCard
                    vipleBarcodePassCard
                    scanEventsTimelineCard
                    if !tracking.items.isEmpty {
                        parcelItemsSummaryCard
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Suivi Viple Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshLiveTracking()
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Label("Actualiser", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLabelSheet) {
                LivriaUPSLabelViewerSheet(
                    labelUrlString: tracking.labelUrl,
                    reference: tracking.reference,
                    trackingNumber: tracking.trackingNumber
                )
            }
        }
    }

    private var headerStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .foregroundStyle(.white)
                    Text("VIPLE DELIVERY • EN DIRECT")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.2)))

                Spacer()

                Text(tracking.reference)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(LivriaPalette.goldSoft)
            }

            Text(tracking.statusLabel)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Label(tracking.carrier, systemImage: "truck.box.fill")
                Label(tracking.estimatedDelivery, systemImage: "calendar.badge.clock")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))

            if !tracking.shippingAddress.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(LivriaPalette.gold)
                    Text("\(tracking.relayBadge) : \(tracking.shippingAddress)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LivriaPalette.heroGradient)
        )
    }

    private var visualProgressStepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progression de l'acheminement")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            ForEach(tracking.steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(step.isCompleted ? LivriaPalette.primary : LivriaPalette.background)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(step.isCompleted ? LivriaPalette.primary : LivriaPalette.border, lineWidth: 1.5)
                            )
                        Image(systemName: step.isCompleted ? "checkmark" : "\(step.index + 1).circle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(step.isCompleted ? .white : LivriaPalette.inkMuted)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(step.label)
                                .font(.system(size: 14, weight: step.isCurrent ? .black : .bold, design: .rounded))
                                .foregroundStyle(step.isCompleted ? LivriaPalette.ink : LivriaPalette.inkMuted)
                            if step.isCurrent {
                                Text("Étape actuelle")
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(LivriaPalette.primarySoft))
                                    .foregroundStyle(LivriaPalette.primary)
                            }
                        }
                        Text(step.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                }
            }
        }
        .livriaCard()
    }

    private var vipleBarcodePassCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Code Retrait & Suivi Viple Taker", systemImage: "barcode.viewfinder")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = tracking.vipleDeliveryBarcode
                    #endif
                    store.showToast("Code Viple Delivery copié : \(tracking.vipleDeliveryBarcode)")
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.system(size: 11.5, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }

            // Représentation visuelle de code-barres 1D pour scan Looby Taker / Point Relais
            VStack(spacing: 6) {
                HStack(spacing: 2.5) {
                    ForEach(0..<34, id: \.self) { idx in
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: (idx % 3 == 0) ? 3.5 : ((idx % 2 == 0) ? 1.5 : 2.5), height: 46)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

                Text(tracking.vipleDeliveryBarcode)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)

                if !tracking.trackingNumber.isEmpty && tracking.trackingNumber != tracking.vipleDeliveryBarcode {
                    Text("Suivi transporteur : \(tracking.trackingNumber)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LivriaPalette.border, lineWidth: 1))

            if !tracking.labelUrl.isEmpty {
                Button {
                    showingLabelSheet = true
                } label: {
                    HStack {
                        Image(systemName: "doc.richtext.fill")
                        Text("Afficher le bordereau officiel d'expédition")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.goldSoft))
                    .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                }
                .buttonStyle(.plain)
            }
        }
        .livriaCard()
    }

    private var scanEventsTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Historique des scans Viple Delivery & UPS")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
            }

            ForEach(tracking.events) { ev in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ev.statusLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ev.isHighlight ? LivriaPalette.primary : LivriaPalette.ink)
                        Spacer()
                        Text(ev.timestamp)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    if !ev.location.isEmpty {
                        Label(ev.location, systemImage: "location.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    if !ev.description.isEmpty {
                        Text(ev.description)
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
            }
        }
        .livriaCard()
    }

    private var parcelItemsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contenu du colis (\(tracking.items.count))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            ForEach(tracking.items) { item in
                HStack(spacing: 10) {
                    LivriaBookCoverView(
                        coverUrl: item.coverUrl,
                        title: item.title,
                        width: 40,
                        height: 58,
                        cornerRadius: 6
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("\(item.quantity) × \(item.format) • \(String(format: "%.2f €", item.unitPrice))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                }
            }
        }
        .livriaCard()
    }

    private func refreshLiveTracking() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let updated = try? await LivriaAPIClient.shared.trackVipleDelivery(
            trackingNumber: tracking.trackingNumber,
            orderId: tracking.orderId > 0 ? tracking.orderId : nil,
            reference: tracking.reference
        ), updated.found {
            self.tracking = updated
            store.showToast("Suivi Viple Delivery actualisé en direct.")
        }
    }
}
