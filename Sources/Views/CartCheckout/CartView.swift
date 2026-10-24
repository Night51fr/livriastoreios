import SwiftUI

// MARK: - Panier Livria Store (CartView • Prise en charge Neuf & Occasion)

public struct CartView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.cart.isEmpty {
                    emptyCartContent
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            if store.currentUser?.isLivriaPlus != true && !store.hasLoobyPlusInCart {
                                loobyPlusUpsellBanner
                            }

                            ForEach(store.cart) { item in
                                cartItemRow(item: item)
                            }

                            summaryCard
                        }
                        .padding(16)
                    }

                    bottomCheckoutBar
                }
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Mon Panier (\(store.cartItemsCount))")
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

    private var emptyCartContent: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "cart.circle.fill")
                .font(.system(size: 62))
                .foregroundStyle(LivriaPalette.primary)
            Text("Votre panier Livria Store est vide")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
            Text("Parcourez la Boutique (Neuf & Occasion) ou ajoutez l'abonnement Looby+ (3,50 €/mois) pour commencer.")
                .font(.system(size: 13.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                dismiss()
                store.selectedMainTab = 1
            } label: {
                Text("Aller à la Boutique")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LivriaPalette.primary))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private var loobyPlusUpsellBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(LivriaPalette.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Livraison 0 € immédiate avec Looby+ (3,50 €/mois)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text("Ajoutez Looby+ au panier pour économiser les 3,90 € de port UPS !")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.88))
            }
            Spacer()
            Button {
                Task {
                    await store.addLoobyPlusSubscriptionToCart(openCheckoutImmediately: false)
                }
            } label: {
                Text("+ 3,50 €")
                    .font(.system(size: 12.5, weight: .black))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(LivriaPalette.gold))
                    .foregroundStyle(.black)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LivriaPalette.loobyPlusGradient))
    }

    private func cartItemRow(item: LivriaCartItem) -> some View {
        let isUsed = item.isUsedFormat == true || item.format.lowercased().hasPrefix("occasion")
        return HStack(spacing: 14) {
            LivriaBookCoverView(
                coverUrl: item.coverUrl,
                title: item.title,
                width: 66,
                height: 96,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(LivriaPalette.ink)
                    .lineLimit(2)

                Text(item.author)
                    .font(.system(size: 12))
                    .foregroundStyle(LivriaPalette.inkMuted)

                Text(isUsed ? "♻️ \(item.format)" : "✨ \(item.format)")
                    .font(.system(size: 10.5, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(isUsed ? LivriaPalette.usedAmberSoft : LivriaPalette.primarySoft))
                    .foregroundStyle(isUsed ? LivriaPalette.usedAmber : LivriaPalette.primaryDeep)

                Text(String(format: "%.2f €", item.lineTotal))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(isUsed ? LivriaPalette.usedAmber : LivriaPalette.primary)
            }

            Spacer()

            if item.isLoobyPlusSubscription {
                Button(role: .destructive) {
                    Task {
                        await store.updateCartItem(bookId: item.bookId, format: item.format, quantity: 0)
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await store.updateCartItem(bookId: item.bookId, format: item.format, quantity: item.quantity - 1)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LivriaPalette.primary)
                    }
                    Text("\(item.quantity)")
                        .font(.system(size: 14, weight: .bold))
                    Button {
                        Task {
                            await store.updateCartItem(bookId: item.bookId, format: item.format, quantity: item.quantity + 1)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LivriaPalette.primary)
                    }
                }
            }
        }
        .livriaCard(padding: 12)
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Sous-total")
                    .foregroundStyle(LivriaPalette.inkMuted)
                Spacer()
                Text(String(format: "%.2f €", store.cartSubtotal))
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Livraison UPS / Point Relais")
                    .foregroundStyle(LivriaPalette.inkMuted)
                Spacer()
                Text(store.cartShippingCost == 0 ? "Offerte (0,00 €)" : String(format: "%.2f €", store.cartShippingCost))
                    .fontWeight(.bold)
                    .foregroundStyle(store.cartShippingCost == 0 ? LivriaPalette.mint : LivriaPalette.ink)
            }
            Divider()
            HStack {
                Text("Total TTC")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(String(format: "%.2f €", store.cartTotal))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.primary)
            }
        }
        .font(.system(size: 14))
        .livriaCard()
    }

    private var bottomCheckoutBar: some View {
        VStack(spacing: 6) {
            if store.isGuestSession {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Connexion Viple Live ID requise pour finaliser votre achat")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if store.requireAuthenticationForPurchase(reason: "passer commande sur Livria Store") {
                        store.isShowingCheckoutSheet = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: store.isGuestSession ? "person.crop.circle.badge.checkmark" : "lock.shield.fill")
                    Text(
                        store.isGuestSession
                            ? "Se connecter pour commander (\(String(format: "%.2f €", store.cartTotal)))"
                            : "Passer au Checkout (\(String(format: "%.2f €", store.cartTotal)))"
                    )
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(LivriaPalette.cardPaper)
    }
}
