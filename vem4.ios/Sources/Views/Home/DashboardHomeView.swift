import SwiftUI

// MARK: - Tab 1: Animated Dashboard & Household Overview (Viple & Moi)

public struct DashboardHomeView: View {
    @Bindable var store: VemStoreViewModel
    @Environment(\.openURL) private var openURL

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    private var viewerFirstName: String {
        store.workspace?.viewer.firstName ?? "Client"
    }

    private var billingStatusSummary: String {
        guard let bill = store.workspace?.billing.profile else {
            return "Viple Mail inclus à 0,00 € · Sans engagement"
        }
        if bill.sepaActive {
            return "Prélèvement SEPA actif · Le \(bill.sepaDebitDay) du mois"
        }
        if bill.payPalActive {
            return "Compte PayPal associé (\(bill.payPalEmail ?? "actif"))"
        }
        return "Viple Mail inclus à 0,00 € · Sans engagement"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Living Aurora Hero & Consolidated Monthly Spotlight
                VemAuroraBackgroundCard(cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 10) {
                            HStack(spacing: 7) {
                                VemPulseDot(color: VemTheme.vipleMint)
                                Text(" Services opérationnels")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.15)))

                            Spacer()

                            if store.workspace?.rights.vipPriority == true {
                                Label("Priorité VIP", systemImage: "crown.fill")
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.solarAmber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.black.opacity(0.28)))
                            }
                        }

                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bonjour \(viewerFirstName) !")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Pilotez vos services, votre messagerie @viplemail.fr, votre famille et vos livraisons Livria en un geste.")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.86))
                                    .lineSpacing(2)
                            }
                            Spacer(minLength: 0)
                        }

                        // Consolidated Monthly Spotlight Box
                        Button {
                            VemHaptics.selection()
                            store.selectedTab = .billing
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("MENSUALITÉ CONSOLIDÉE DU FOYER")
                                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                                        .tracking(0.8)
                                        .foregroundStyle(Color.white.opacity(0.75))

                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(VemFormat.euros(store.workspace?.summary.monthlyTotalTtc ?? 0))
                                            .font(.system(size: 28, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("/ mois")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.8))
                                    }

                                    Text(billingStatusSummary)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.68, green: 0.96, blue: 0.85))
                                }
                                Spacer()
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.13))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(VemPressableButtonStyle())

                        // 4 Quick Action Tiles
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            HeroQuickActionButton(
                                icon: "envelope.fill",
                                label: "Webmail Viple",
                                prominent: true
                            ) {
                                let raw = store.workspace?.vipleMail.webmailUrl ?? "https://mail.viplemail.fr/sso-login"
                                if let u = URL(string: raw) { openURL(u) }
                            }

                            HeroQuickActionButton(
                                icon: "plus.circle.fill",
                                label: "Ajouter un service",
                                prominent: false
                            ) {
                                store.servicesSegment = 1
                                store.selectedTab = .services
                            }

                            HeroQuickActionButton(
                                icon: "shippingbox.fill",
                                label: "Colis & Livria",
                                prominent: false
                            ) {
                                store.showOrdersSheet = true
                            }

                            HeroQuickActionButton(
                                icon: "book.pages.fill",
                                label: "Cours A–Z Client",
                                prominent: false
                            ) {
                                store.showGuideSheet = true
                            }
                        }
                    }
                    .padding(20)
                }

                // 2. Pending Family Option Requests Banner (e.g. Hugo asking for backup option)
                if let reqs = store.workspace?.optionRequests, !reqs.isEmpty {
                    VemOptionRequestsBannerView(store: store, requests: reqs)
                }

                // 3. Household Member Filter Chips + Active Services
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Services & Équipements du Foyer")
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                            Text("Touchez un service pour le piloter en détail.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.servicesSegment = 0
                            store.selectedTab = .services
                        } label: {
                            Text("Tout voir")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(VemTheme.electricIndigo)
                        }
                    }

                    VemMemberFilterStrip(store: store)

                    if store.isInitialLoading && store.workspace == nil {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Synchronisation de votre Espace Client v4…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .vemCard()
                    } else if store.filteredSubscriptions.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text("Aucun service rattaché à ce membre pour le moment.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .vemCard()
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(store.filteredSubscriptions) { sub in
                                VemSubscriptionCardView(subscription: sub) {
                                    VemHaptics.impact(.light)
                                    store.activeServiceDetailID = sub.id
                                }
                            }
                        }
                    }
                }

                // 4. Live Livria & Viple Delivery Parcel Preview Widget
                if let orders = store.ordersPayload?.orders, let latest = orders.first {
                    Button {
                        VemHaptics.selection()
                        store.showOrdersSheet = true
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VemTheme.warmCoral.opacity(0.15))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(VemTheme.warmCoral)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("DERNIÈRE COMMANDE LIVRIA")
                                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                                        .foregroundStyle(VemTheme.warmCoral)
                                    VemStatusPill(latest.status, tone: .emerald)
                                }
                                Text("Commande \(latest.orderRef) · \(VemFormat.euros(latest.totalTtc))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("\(latest.carrier) · \(latest.destination)")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .vemCard(cornerRadius: 20, padding: 16)
                    }
                    .buttonStyle(VemPressableButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Viple & Moi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.selectedTab = .more
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(VemTheme.vipleEmerald)
                    }
                }
            }
        }
        .refreshable {
            await store.refreshAll(silent: false)
            await store.loadOrders(silent: true)
        }
    }
}

private struct HeroQuickActionButton: View {
    let icon: String
    let label: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button {
            VemHaptics.selection()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(prominent ? VemTheme.vipleEmerald : .white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Color.white : Color.white.opacity(0.15))
            )
        }
        .buttonStyle(VemPressableButtonStyle())
    }
}

// MARK: - Reusable Member Filter Strip

public struct VemMemberFilterStrip: View {
    @Bindable var store: VemStoreViewModel

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    public var body: some View {
        let subsCount = store.workspace?.subscriptions.count ?? 0
        let members = store.workspace?.familyMembers ?? []
        let hasDelegated = (store.workspace?.subscriptions ?? []).contains(where: { $0.isDelegatedToMe })

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipButton(
                    title: "Tout le foyer (\(subsCount))",
                    dotHex: nil,
                    isSelected: store.memberFilter == "all"
                ) {
                    VemHaptics.selection()
                    withAnimation(VemTheme.snappySpring) {
                        store.memberFilter = "all"
                    }
                }

                ForEach(members) { m in
                    let label = m.isPrimaryOwner ? "\(m.firstName) (Moi)" : "\(m.firstName) · \(m.relationship)"
                    FilterChipButton(
                        title: label,
                        dotHex: m.avatarColor,
                        isSelected: store.memberFilter == "\(m.id)"
                    ) {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            store.memberFilter = "\(m.id)"
                        }
                    }
                }

                if hasDelegated {
                    FilterChipButton(
                        title: "Partagés avec moi",
                        dotHex: "#6366F1",
                        isSelected: store.memberFilter == "delegated"
                    ) {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            store.memberFilter = "delegated"
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct FilterChipButton: View {
    let title: String
    let dotHex: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dotHex {
                    Circle()
                        .fill(Color(vemHex: dotHex))
                        .frame(width: 9, height: 9)
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8.5)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(VemTheme.vibrantActionGradient) : AnyShapeStyle(VemTheme.cardSurface))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : VemTheme.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(VemPressableButtonStyle())
    }
}

// MARK: - Reusable Family Option Requests Banner

public struct VemOptionRequestsBannerView: View {
    @Bindable var store: VemStoreViewModel
    public let requests: [VemOptionRequest]

    public init(store: VemStoreViewModel, requests: [VemOptionRequest]) {
        self.store = store
        self.requests = requests
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(VemTheme.electricIndigo)
                Text("Demande(s) d'options dans votre foyer (\(requests.count))")
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
            }

            ForEach(requests) { r in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(r.requesterName) souhaite activer « \(r.optionTitle) » (+\(VemFormat.euros(r.priceMonthlyTtc))/mois) sur \(r.serviceNickname)")
                            .font(.system(size: 13.5, weight: .semibold))
                        if !r.message.isEmpty {
                            Text("« \(r.message) »")
                                .font(.system(size: 12.5))
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }

                    if r.canResolve {
                        HStack(spacing: 10) {
                            Button {
                                Task { await store.resolveOptionRequest(requestId: r.id, approve: true) }
                            } label: {
                                Label("Approuver & Activer", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(VemTheme.vipleEmerald))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                            .disabled(store.isMutating)

                            Button {
                                Task { await store.resolveOptionRequest(requestId: r.id, approve: false) }
                            } label: {
                                Text("Refuser")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(VemTheme.warmCoral)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(VemTheme.warmCoral.opacity(0.12)))
                            }
                            .buttonStyle(VemPressableButtonStyle())
                            .disabled(store.isMutating)
                        }
                    } else {
                        VemStatusPill("En attente de validation du titulaire", tone: .amber, icon: "clock.fill")
                    }
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(VemTheme.elevatedSurface)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VemTheme.electricIndigo.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(VemTheme.electricIndigo.opacity(0.28), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Reusable Subscription Card (Strict Server vs Non-Server Status Pill!)

public struct VemSubscriptionCardView: View {
    public let subscription: VemSubscription
    public let onTap: () -> Void

    public init(subscription: VemSubscription, onTap: @escaping () -> Void) {
        self.subscription = subscription
        self.onTap = onTap
    }

    private var palette: VemAccentPalette {
        VemAccentPalette.resolve(subscription.accentTheme)
    }

    private var statusTone: VemStatusPill.Tone {
        subscription.isServerStopped ? .amber : .emerald
    }

    private var statusIcon: String {
        if subscription.isServerService {
            return subscription.isServerStopped ? "pause.circle.fill" : "power.circle.fill"
        }
        return "checkmark.circle.fill"
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Row: Icon + Member & Contextual Status Pills
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(palette.softFill)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: VemFormat.sfSymbol(for: subscription.iconName, category: subscription.category))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(palette.primary)
                        )

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 6) {
                            if subscription.isDelegatedToMe {
                                VemStatusPill("Partagé", tone: .indigo, icon: "person.2.fill")
                            } else {
                                VemStatusPill(subscription.assignedMemberName, tone: .sky, icon: "person.fill")
                            }
                            VemStatusPill(subscription.runtimeStatusLabel, tone: statusTone, icon: statusIcon)
                        }

                        if !subscription.isCommercialized {
                            VemStatusPill("Plus commercialisé", tone: .amber, icon: "archivebox.fill")
                        }
                    }
                }

                // Title & Technical Identifier
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.displayTitle)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subscription.displaySubtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(subscription.technicalIdentifier)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.softFill.opacity(0.75))
                    )

                // Animated Usage Gauge Row
                HStack(spacing: 14) {
                    VemAnimatedRingGauge(
                        used: subscription.metric1Used,
                        maximum: subscription.metric1Max,
                        palette: palette,
                        size: 52,
                        lineWidth: 5.5
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(subscription.metric1Label) : \(VemFormat.decimal(subscription.metric1Used)) / \(VemFormat.decimal(subscription.metric1Max)) \(subscription.metric1Unit)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        let optsCount = subscription.options.count
                        let suffix = optsCount > 0 ? " · \(optsCount) option(s)" : ""
                        Text("\(subscription.metric2Value.isEmpty ? subscription.commitmentLabel : subscription.metric2Value)\(suffix)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                // Footer Price + Detail CTA
                Divider()
                HStack {
                    if subscription.totalMonthlyTtc == 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("0,00 €")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(VemTheme.vipleEmerald)
                            Text("Inclus à vie")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(VemFormat.euros(subscription.totalMonthlyTtc))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("/ mois")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Gérer en détail")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(palette.softFill))
                }
            }
            .vemCard(cornerRadius: 22, padding: 17)
        }
        .buttonStyle(VemPressableButtonStyle())
    }
}
