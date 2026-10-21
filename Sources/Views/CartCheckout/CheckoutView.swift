import SwiftUI

// MARK: - Checkout Complet Livria Store (Checkout sans compte + Apple Pay / Google Pay / PayPal via API PayPal + Création de compte 1-clic post-commande)

public struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var guestEmail: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var postalCode: String = ""
    @State private var city: String = ""

    @State private var selectedPaymentMethod: String = "ApplePay_PayPal"
    @State private var isClickAndCollect: Bool = false
    @State private var selectedRelayId: Int? = nil
    @State private var selectedUpsPointId: String = ""
    @State private var isGiftWrapped: Bool = false
    @State private var giftMessage: String = ""
    @State private var isZeroWaste: Bool = true
    @State private var useLoyaltyPoints: Bool = false
    @State private var useCashback: Bool = false

    @State private var isSubmitting: Bool = false
    @State private var completedOrder: LivriaCheckoutResponse? = nil

    // Création de compte / Connexion en 1 clic après commande (Email & Nom déjà pré-remplis)
    @State private var postOrderPassword: String = ""
    @State private var isFinalizingAccount: Bool = false
    @State private var accountFinalizedSuccess: Bool = false
    @State private var accountFinalizedError: String? = nil

    public init() {}

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
                        confirmOrderButton
                    }
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Validation & Checkout")
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
                }
            }
        }
    }

    // MARK: - Paiement Express Apple Pay / Google Pay / PayPal via l'API PayPal

    private var expressWalletsViaPayPalCard: some View {
        let giftFee = isGiftWrapped ? 2.50 : 0.0
        let finalTotal = max(0.0, store.cartTotal + giftFee)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Paiement Express via API PayPal")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                Text("Sécurisé")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LivriaPalette.mint.opacity(0.16)))
                    .foregroundStyle(LivriaPalette.mint)
            }

            HStack(spacing: 10) {
                // Bouton Apple Pay via PayPal API
                Button {
                    selectedPaymentMethod = "ApplePay_PayPal"
                    triggerExpressPayPalWallet(walletSource: "apple_pay", amount: finalTotal)
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

                // Bouton Google Pay via PayPal API
                Button {
                    selectedPaymentMethod = "GooglePay_PayPal"
                    triggerExpressPayPalWallet(walletSource: "google_pay", amount: finalTotal)
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

                // Bouton PayPal Express
                Button {
                    selectedPaymentMethod = "PayPal"
                    triggerExpressPayPalWallet(walletSource: "paypal", amount: finalTotal)
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
            }

            Text("Propulsé par l'API PayPal Commerce Platform (Apple Pay, Google Pay & PayPal)")
                .font(.system(size: 11))
                .foregroundStyle(LivriaPalette.inkMuted)
        }
        .livriaCard()
    }

    // MARK: - Mode de Livraison

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
                        Text("Domicile UPS")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Suivi 1Z • Viple Delivery")
                            .font(.system(size: 10.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(!isClickAndCollect ? LivriaPalette.primary : LivriaPalette.background))
                    .foregroundStyle(!isClickAndCollect ? .white : LivriaPalette.ink)
                }

                Button {
                    isClickAndCollect = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title2)
                        Text("Point Relais")
                            .font(.system(size: 13.5, weight: .bold))
                        Text("Communautaire ou UPS")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sélectionner un Point Relais Communautaire ou UPS Access Point™ :")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)

                    ForEach(store.relays?.communityPoints ?? []) { pt in
                        Button {
                            selectedRelayId = pt.id
                            address = "\(pt.name) — \(pt.address)"
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

                    ForEach(store.relays?.upsPoints ?? []) { ups in
                        Button {
                            selectedUpsPointId = ups.id
                            selectedRelayId = nil
                            address = "\(ups.name) — \(ups.address)"
                            postalCode = ups.postalCode
                            city = ups.city
                        } label: {
                            HStack {
                                Image(systemName: selectedUpsPointId == ups.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(LivriaPalette.gold)
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
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .livriaCard()
    }

    // MARK: - Coordonnées du Destinataire (Support Checkout sans compte)

    private var recipientAddressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Coordonnées du destinataire")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
                Spacer()
                if store.isGuestSession {
                    Text("Sans compte")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LivriaPalette.primarySoft))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }

            TextField("Adresse e-mail (confirmation & suivi UPS)", text: $guestEmail)
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

            TextField("Téléphone mobile (notifications SMS UPS)", text: $phone)
                .keyboardType(.phonePad)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

            TextField("Adresse de livraison", text: $address)
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
            Text("Options éco-responsables & Fidélité")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)

            Toggle("🌱 Colis Zéro Déchet réutilisable (Gratuit)", isOn: $isZeroWaste)
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
                Toggle(String(format: "💶 Utiliser ma cagnotte Cashback Looby+ (%.2f €)", store.currentUser?.cashbackBalance ?? 0), isOn: $useCashback)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tint(LivriaPalette.gold)
            }
        }
        .livriaCard()
    }

    private var orderRecapCard: some View {
        let giftFee = isGiftWrapped ? 2.50 : 0.0
        let finalTotal = max(0.0, store.cartTotal + giftFee)
        return VStack(spacing: 8) {
            HStack {
                Text("Articles (\(store.cartItemsCount))")
                Spacer()
                Text(String(format: "%.2f €", store.cartSubtotal))
            }
            HStack {
                Text("Expédition UPS / Relais")
                Spacer()
                Text(store.cartShippingCost == 0 ? "0,00 €" : String(format: "%.2f €", store.cartShippingCost))
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
                Text(String(format: "%.2f €", finalTotal))
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(LivriaPalette.primary)
            }
        }
        .font(.system(size: 14))
        .livriaCard()
    }

    private var confirmOrderButton: some View {
        Button {
            submitOrder()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                }
                Text("Confirmer et régler ma commande")
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

    // MARK: - Confirmation de Commande + Création de Compte / Connexion en 1 Clic (Email & Nom pré-remplis)

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

                Text(done.message ?? "Votre commande a été enregistrée avec succès.")
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

                if let urlStr = done.deliveryUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Suivre mon colis sur Viple Delivery", systemImage: "safari.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }
            }
            .livriaCard(padding: 22)

            // Bloc Création de Compte / Connexion en 1 Clic après Checkout sans compte
            if (done.canCreateAccount == true || store.isGuestSession) && !accountFinalizedSuccess {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title2)
                            .foregroundStyle(LivriaPalette.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Créer mon compte ou me connecter en 1 clic")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(LivriaPalette.ink)
                            Text("Vos informations de commande sont déjà pré-remplies : choisissez simplement votre mot de passe !")
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
                    Text("Votre compte Viple Live ID est maintenant actif et votre commande y est rattachée !")
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

    private func triggerExpressPayPalWallet(walletSource: String, amount: Double) {
        Task {
            _ = await store.createPayPalExpressSession(walletSource: walletSource, amount: amount)
            submitOrder()
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

    private func submitOrder() {
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
                relayId: selectedRelayId
            )
            isSubmitting = false
            if let res, res.ok {
                completedOrder = res
            }
        }
    }
}
