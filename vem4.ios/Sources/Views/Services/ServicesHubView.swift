import SwiftUI

// MARK: - Tab 2: Mes Services & Boutique Officielle Viple (ServicesHubView)

public struct ServicesHubView: View {
    @Bindable var store: VemStoreViewModel
    @State private var searchQuery: String = ""

    private let boutiqueCategories: [String] = [
        "all",
        "cloud-vps",
        "box-5g",
        "decodeur-tv",
        "forfait-mobile",
        "hebergement-web",
        "telephonie-sip",
        "ecosysteme-looby"
    ]

    public init(store: VemStoreViewModel) {
        self.store = store
    }

    private var searchedSubscriptions: [VemSubscription] {
        let base = store.filteredSubscriptions
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { sub in
            sub.displayTitle.lowercased().contains(q)
                || sub.title.lowercased().contains(q)
                || sub.technicalIdentifier.lowercased().contains(q)
                || sub.assignedMemberName.lowercased().contains(q)
                || sub.runtimeStatusLabel.lowercased().contains(q)
        }
    }

    private var searchedBoutiqueProducts: [VemBoutiqueProduct] {
        let base = store.filteredBoutiqueProducts
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { prod in
            prod.title.lowercased().contains(q)
                || prod.subtitle.lowercased().contains(q)
                || prod.description.lowercased().contains(q)
                || prod.badgeText.lowercased().contains(q)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Custom Tactile Segmented Switcher
                HStack(spacing: 8) {
                    HubSegmentButton(
                        title: "Mes Services (\(store.workspace?.subscriptions.count ?? 0))",
                        icon: "bolt.horizontal.circle.fill",
                        isSelected: store.servicesSegment == 0
                    ) {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            store.servicesSegment = 0
                        }
                    }

                    HubSegmentButton(
                        title: "Boutique Officielle",
                        icon: "bag.badge.plus",
                        isSelected: store.servicesSegment == 1
                    ) {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            store.servicesSegment = 1
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VemTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(VemTheme.subtleBorder, lineWidth: 1)
                        )
                )

                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        store.servicesSegment == 0
                            ? "Rechercher un service, IP, numéro, membre…"
                            : "Rechercher une offre (VPS, Box 5G, Looby+…)",
                        text: $searchQuery
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(VemTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(VemTheme.subtleBorder, lineWidth: 1)
                        )
                )

                if store.servicesSegment == 0 {
                    activeServicesContent
                } else {
                    officialBoutiqueContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(VemTheme.pageBackground.ignoresSafeArea())
        .navigationTitle(store.servicesSegment == 0 ? "Mes Services" : "Boutique Viple")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refreshAll(silent: false)
        }
    }

    // MARK: - Segment 0: Active Household Subscriptions

    @ViewBuilder
    private var activeServicesContent: some View {
        VemMemberFilterStrip(store: store)

        if searchedSubscriptions.contains(where: { !$0.isCommercialized }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.seal.text.page.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(VemTheme.solarAmber)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Garantie Tarifaire Viple Maintenue")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Text("Certaines offres historiques ne sont plus commercialisées pour les nouveaux clients, mais restent pleinement actives à votre tarif d'origine tant que vous les conservez.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VemTheme.solarAmber.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(VemTheme.solarAmber.opacity(0.30), lineWidth: 1)
                    )
            )
        }

        if searchedSubscriptions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Aucun service trouvé pour ce filtre.")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Button {
                    withAnimation(VemTheme.snappySpring) {
                        store.memberFilter = "all"
                        searchQuery = ""
                    }
                } label: {
                    Text("Réinitialiser les filtres")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VemTheme.electricIndigo)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .vemCard()
        } else {
            LazyVStack(spacing: 14) {
                ForEach(searchedSubscriptions) { sub in
                    VemSubscriptionCardView(subscription: sub) {
                        VemHaptics.impact(.light)
                        store.activeServiceDetailID = sub.id
                    }
                }
            }
        }

        // Upsell Banner to Boutique
        Button {
            VemHaptics.selection()
            withAnimation(VemTheme.snappySpring) {
                store.servicesSegment = 1
            }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Souscrire un nouveau service pour vous ou un proche")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text("Cloud VPS, Box 5G Zéro Fibre, Forfaits 5G, Pass Looby+ & Livria+ activés en quelques secondes.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(VemTheme.vibrantActionGradient)
            )
        }
        .buttonStyle(VemPressableButtonStyle())
    }

    // MARK: - Segment 1: Official Boutique Viple

    @ViewBuilder
    private var officialBoutiqueContent: some View {
        VemAuroraBackgroundCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(VemTheme.vipleMint)
                    Text("CATALOGUE OFFICIEL COMMERCIALISÉ")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(Color.white.opacity(0.84))
                }
                Text("Équipez tout votre foyer en 1 geste")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Commandez pour vous-même ou attribuez directement l'offre à un membre de votre famille (ex. Hugo) avec son propre accès Viple Live.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(2)
            }
            .padding(20)
        }

        // Category Filter Strip
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(boutiqueCategories, id: \.self) { cat in
                    let isSelected = store.boutiqueCategory == cat
                    Button {
                        VemHaptics.selection()
                        withAnimation(VemTheme.snappySpring) {
                            store.boutiqueCategory = cat
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if cat != "all" {
                                Image(systemName: VemFormat.sfSymbol(for: nil, category: cat))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(VemFormat.categoryDisplayTitle(cat))
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
            .padding(.vertical, 2)
        }

        if store.workspace?.rights.canOrderNewServices == false {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(VemTheme.warmCoral)
                Text("La souscription de nouveaux abonnements est réservée au titulaire principal du foyer.")
                    .font(.system(size: 13, weight: .semibold))
            }
            .vemCard()
        }

        LazyVStack(spacing: 16) {
            ForEach(searchedBoutiqueProducts) { prod in
                BoutiqueProductCard(
                    product: prod,
                    canOrder: store.workspace?.rights.canOrderNewServices ?? true
                ) {
                    VemHaptics.impact(.medium)
                    store.orderingProduct = prod
                }
            }
        }
    }
}

private struct HubSegmentButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .bold))
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10.5)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(VemTheme.vibrantActionGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(VemPressableButtonStyle())
    }
}

private struct BoutiqueProductCard: View {
    let product: VemBoutiqueProduct
    let canOrder: Bool
    let onOrderTap: () -> Void

    private var palette: VemAccentPalette {
        VemAccentPalette.resolve(product.accentTheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(palette.softFill)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: VemFormat.sfSymbol(for: product.iconName, category: product.category))
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(palette.primary)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if !product.badgeText.isEmpty {
                        VemStatusPill(product.badgeText, tone: .indigo, icon: "sparkles")
                    }
                    VemStatusPill(product.commitmentLabel, tone: .emerald)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text(product.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.primary)
                Text(product.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }

            // Spec Pills
            HStack(spacing: 8) {
                if !product.specPrimaryLabel.isEmpty {
                    Label(
                        "\(product.specPrimaryLabel) : \(VemFormat.decimal(product.specPrimaryMax)) \(product.specPrimaryUnit)",
                        systemImage: "gauge.with.dots.needle.67percent"
                    )
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VemTheme.elevatedSurface))
                }
                if !product.specSecondaryDefault.isEmpty {
                    Text(product.specSecondaryDefault)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(VemFormat.euros(product.priceMonthlyTtc))
                            .font(.system(size: 21, weight: .black, design: .rounded))
                        Text("TTC / mois")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(
                        product.setupFeeTtc > 0
                            ? "Mise en service : \(VemFormat.euros(product.setupFeeTtc))"
                            : "Activation immédiate offerte (0,00 €)"
                    )
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(product.setupFeeTtc > 0 ? Color.secondary : VemTheme.vipleEmerald)
                }

                Spacer()

                Button(action: onOrderTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("Commander")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(palette.gradient)
                    )
                }
                .buttonStyle(VemPressableButtonStyle())
                .disabled(!canOrder)
                .opacity(canOrder ? 1.0 : 0.45)
            }
        }
        .vemCard(cornerRadius: 24, padding: 18)
    }
}
