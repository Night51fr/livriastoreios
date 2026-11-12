import SwiftUI
import UIKit

// MARK: - Commandes Livria Store & Colis Viple Delivery Hub

public struct OrdersAndDeliveryView: View {
    @Bindable var store: VemStoreViewModel
    public let isPresentedModally: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    public init(store: VemStoreViewModel, isPresentedModally: Bool = false) {
        self.store = store
        self.isPresentedModally = isPresentedModally
    }

    private var orders: [VemOrderShipment] {
        store.ordersPayload?.orders ?? []
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Header
                VemAuroraBackgroundCard(cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.and.arrow.backward.fill")
                                .foregroundStyle(VemTheme.vipleMint)
                            Text("LIVRIA STORE & VIPLE DELIVERY")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(0.9)
                                .foregroundStyle(Color.white.opacity(0.84))
                        }

                        Text("Suivi en direct de vos livres & expéditions")
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Retrouvez automatiquement toutes les commandes associées à votre compte Viple Live, vos codes-barres Viple Delivery et vos points relais Viple Taker.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.88))

                        HStack(spacing: 10) {
                            Button {
                                let raw = store.ordersPayload?.livriaStoreUrl ?? "https://livria.store"
                                if let u = URL(string: raw) { openURL(u) }
                            } label: {
                                Label("Livria Store", systemImage: "books.vertical.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.vipleEmerald)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9.5)
                                    .background(Capsule().fill(Color.white))
                            }
                            .buttonStyle(VemPressableButtonStyle())

                            Button {
                                let raw = store.ordersPayload?.vipleDeliveryUrl ?? "https://delivery.viplenetwork.com"
                                if let u = URL(string: raw) { openURL(u) }
                            } label: {
                                Label("Portail Delivery", systemImage: "truck.box.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9.5)
                                    .background(Capsule().fill(Color.white.opacity(0.18)))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                        }
                    }
                    .padding(20)
                }

                if store.isLoadingOrders && orders.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Synchronisation de vos colis Livria & Viple Delivery…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .vemCard()
                } else if orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Aucune commande récente trouvée")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("Vos prochains achats sur Livria Store et vos envois Viple Delivery s'afficheront ici automatiquement.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .vemCard()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(orders) { order in
                            OrderShipmentCard(store: store, order: order)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Colis & Commandes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
        .task {
            if store.ordersPayload == nil {
                await store.loadOrders(silent: false)
            }
        }
        .refreshable {
            await store.loadOrders(silent: false)
        }
    }
}

private struct OrderShipmentCard: View {
    @Bindable var store: VemStoreViewModel
    let order: VemOrderShipment
    @Environment(\.openURL) private var openURL
    @State private var showTimeline: Bool = true

    private let stepLabels = ["Confirmée", "Préparation", "En transit", "Livrée"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        VemStatusPill(order.source, tone: .coral, icon: "bag.fill")
                        if order.isRelay {
                            VemStatusPill("Point Viple Taker", tone: .indigo, icon: "mappin.and.ellipse")
                        }
                    }
                    Text("Commande \(order.orderRef)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    if !order.createdAtDisplay.isEmpty {
                        Text("Passée le \(order.createdAtDisplay)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    VemStatusPill(order.status, tone: order.stepIndex >= 4 ? .emerald : .sky, icon: "truck.box.fill")
                    if order.totalTtc > 0 {
                        Text(VemFormat.euros(order.totalTtc))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                }
            }

            // 4-Step Visual Progress Stepper
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= order.stepIndex ? VemTheme.vipleMint : Color.secondary.opacity(0.18))
                            .frame(height: 6)
                    }
                }
                HStack {
                    ForEach(0..<4, id: \.self) { i in
                        Text(stepLabels[i])
                            .font(.system(size: 10.5, weight: (i + 1) <= order.stepIndex ? .bold : .medium, design: .rounded))
                            .foregroundStyle((i + 1) <= order.stepIndex ? VemTheme.vipleEmerald : .secondary)
                        if i < 3 { Spacer() }
                    }
                }
            }

            // Destination & Tracking Code Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: order.isRelay ? "storefront.fill" : "house.fill")
                        .foregroundStyle(VemTheme.electricIndigo)
                    Text("\(order.carrier) · \(order.destination)")
                        .font(.system(size: 13, weight: .bold))
                }

                if !order.trackingNumber.isEmpty {
                    Button {
                        UIPasteboard.general.string = order.trackingNumber
                        store.showToast("Numéro de suivi copié : \(order.trackingNumber)")
                    } label: {
                        HStack {
                            Text("Suivi : \(order.trackingNumber)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(VemTheme.electricIndigo)
                    }
                }

                if !order.vipleDeliveryBarcode.isEmpty {
                    Text("Code-barres colis : \(order.vipleDeliveryBarcode)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VemTheme.elevatedSurface))

            // Books / Items List
            if !order.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ARTICLES DE LA COMMANDE (\(order.items.count))")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)

                    ForEach(order.items) { item in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: item.coverUrl)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    ZStack {
                                        VemTheme.warmCoral.opacity(0.14)
                                        Image(systemName: "book.closed.fill")
                                            .foregroundStyle(VemTheme.warmCoral)
                                    }
                                }
                            }
                            .frame(width: 42, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .lineLimit(2)
                                if !item.author.isEmpty {
                                    Text(item.author)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(item.format) · Qté \(item.quantity)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.unitPrice > 0 {
                                Text(VemFormat.euros(item.unitPrice))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }
            }

            // Delivery Events Timeline
            if !order.events.isEmpty {
                DisclosureGroup(
                    isExpanded: $showTimeline,
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(order.events.enumerated()), id: \.element.id) { index, ev in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(index == 0 ? VemTheme.vipleMint : Color.secondary.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ev.description)
                                            .font(.system(size: 12.5, weight: index == 0 ? .bold : .medium))
                                        Text("\(ev.when)\(ev.location.isEmpty ? "" : " · \(ev.location)")")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    },
                    label: {
                        Text("Historique d'acheminement (\(order.events.count))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                )
            }

            if let u = URL(string: order.trackingUrl) {
                Button {
                    openURL(u)
                } label: {
                    Label("Ouvrir le suivi détaillé Viple Delivery", systemImage: "safari.fill")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(VemTheme.vipleEmerald)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(VemTheme.vipleMint.opacity(0.14))
                        )
                }
                .buttonStyle(VemPressableButtonStyle())
            }
        }
        .vemCard(cornerRadius: 22, padding: 18)
    }
}
