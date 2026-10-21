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

    @State private var orderPendingCancellation: LivriaOrder? = nil
    @State private var showingCancelConfirmation: Bool = false
    @State private var isCancellingOrderId: Int? = nil
    @State private var selectedOrderForLabel: LivriaOrder? = nil

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(LivriaPalette.primary)
                        Text("Aucune commande pour le moment")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Vos commandes apparaissent ici avec leur suivi UPS en direct et leur bordereau d'expédition téléchargeable.")
                            .font(.system(size: 13))
                            .foregroundStyle(LivriaPalette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .livriaCard(padding: 24)
                } else {
                    ForEach(store.orders) { order in
                        orderCard(order: order)
                    }
                }
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Mes Commandes")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refreshBootstrap()
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
                    Text(order.reference)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(LivriaPalette.primary)
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
                            Text("\(order.carrier) • Suivi : \(trk)")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(LivriaPalette.ink)
                        } else {
                            Text("Expédition UPS Standard")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                        }
                        if !order.shippingAddress.isEmpty {
                            Text(order.shippingAddress)
                                .font(.system(size: 11))
                                .foregroundStyle(LivriaPalette.inkMuted)
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
                        Label("Bordereau UPS", systemImage: "doc.viewfinder.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(LivriaPalette.goldSoft))
                            .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.02))
                    }

                    if let url = URL(string: order.deliveryUrl) {
                        Link(destination: url) {
                            Label("Suivi", systemImage: "location.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(LivriaPalette.primary))
                                .foregroundStyle(.white)
                        }
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
