import SwiftUI

// MARK: - Mes Commandes & Suivi UPS / Viple Delivery (OrdersView)

public struct OrdersView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

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
                        Text("Vos commandes passées sur Livria.iOS, Livria Desktop et livria.store apparaissent ici avec leur suivi UPS en direct.")
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

            if let trk = order.trackingNumber, !trk.isEmpty {
                HStack {
                    Image(systemName: "truck.box.badge.clock.fill")
                        .foregroundStyle(LivriaPalette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(order.carrier) • Suivi : \(trk)")
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(LivriaPalette.ink)
                        Text(order.shippingAddress)
                            .font(.system(size: 11))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
            }

            HStack {
                Text(String(format: "Total : %.2f €", order.total))
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)

                Spacer()

                if let url = URL(string: order.deliveryUrl) {
                    Link(destination: url) {
                        Label("Suivi Viple Delivery", systemImage: "location.fill")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }

                if order.status == "Pending" || order.status == "Processing" || order.status == "Paid" {
                    Button(role: .destructive) {
                        Task {
                            await store.cancelOrder(orderId: order.id)
                        }
                    } label: {
                        Text("Annuler")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                            .foregroundStyle(.red)
                    }
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
