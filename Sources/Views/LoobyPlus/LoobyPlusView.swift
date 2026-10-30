import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Looby+ : Dashboard Abonné & Page de Souscription (3,50 €/mois)

public struct LoobyPlusView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel

    @State private var boxGenres: String = ""
    @State private var boxDisliked: String = ""
    @State private var boxNotes: String = ""
    @State private var boxAddress: String = ""
    @State private var newFamilyMemberName: String = ""
    @State private var newFamilyKidsMode: Bool = false
    @State private var selectedBookToRedeem: Int = 0

    public init() {}

    private var isSubscribed: Bool {
        store.hasLocalStoreKitLoobyPlusEntitlement || store.currentUser?.isLivriaPlus == true || store.loobyPlus?.isSubscribed == true
    }

    private var formattedSubscriptionPrice: String {
        store.loobyPlusStoreKitProduct?.displayPrice ?? "3,50 €"
    }

    /// Uniquement les livres qui disposent effectivement d'un format Audio
    private var audioEligibleBooks: [LivriaBook] {
        store.books.filter { $0.hasAudio }
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if isSubscribed {
                        subscriberDashboardContent
                    } else {
                        subscribeShowcaseContent
                    }

                    if !store.isAuthenticated {
                        optionalMultiDeviceAccountCard
                    }

                    subscriptionLegalDisclosuresCard
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle(isSubscribed ? "Dashboard Looby+" : "Souscrire à Looby+")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if store.loobyPlusStoreKitProduct == nil {
                    await store.preloadLoobyPlusStoreKitProductAndEntitlements()
                }
            }
            .onAppear {
                if let pref = store.loobyPlus?.boxPreferences {
                    boxGenres = pref.preferredGenres
                    boxDisliked = pref.dislikedTropes
                    boxNotes = pref.specialNotes
                    boxAddress = pref.shippingAddress
                }
                if !audioEligibleBooks.contains(where: { $0.id == selectedBookToRedeem }) {
                    selectedBookToRedeem = audioEligibleBooks.first?.id ?? 0
                }
            }
            .onChange(of: store.books) { _, _ in
                if !audioEligibleBooks.contains(where: { $0.id == selectedBookToRedeem }) {
                    selectedBookToRedeem = audioEligibleBooks.first?.id ?? 0
                }
            }
            .alert("Abonnement Looby+", isPresented: $store.isShowingLoobyPlusUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.loobyPlusUnavailableMessage)
            }
        }
    }

    // MARK: - 0. Synchronisation Multi-Appareils Optionnelle (Guideline 5.1.1(v) — L'inscription n'est jamais obligatoire)

    private var optionalMultiDeviceAccountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LivriaPalette.goldSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(red: 0.65, green: 0.35, blue: 0.02))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Synchronisation multi-appareils")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("OPTIONNEL")
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LivriaPalette.primary.opacity(0.12)))
                            .foregroundStyle(LivriaPalette.primary)
                    }
                    Text("Aucun compte n'est requis pour souscrire ou utiliser Looby+ sur cet appareil.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                }
            }

            Text("Vous pouvez acheter et utiliser votre abonnement Looby+ immédiatement sans inscription. Si vous souhaitez ultérieurement étendre l'accès à votre abonnement et à vos livres audio sur d'autres appareils compatibles, vous pouvez créer ou connecter un compte Viple Live ID à tout moment.")
                .font(.system(size: 12.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.isShowingAuthSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                    Text("Se connecter ou créer un compte (Optionnel)")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.primary.opacity(0.10)))
                .foregroundStyle(LivriaPalette.primary)
            }
            .buttonStyle(.plain)
        }
        .livriaCard()
    }

    // MARK: - 0b. Informations Légales Obligatoires sur l'Abonnement Auto-Renouvelable (Guideline 3.1.2(c))

    private var subscriptionLegalDisclosuresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Informations sur l'abonnement auto-renouvelable")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Titre de l'abonnement :")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    Text(store.loobyPlusStoreKitProduct?.displayName ?? "Abonnement Looby+ Mensuel")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                }
                HStack {
                    Text("Durée de l'abonnement :")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    Text("1 mois (renouvellement mensuel)")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                }
                HStack {
                    Text("Prix de l'abonnement :")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LivriaPalette.inkMuted)
                    Spacer()
                    Text("\(formattedSubscriptionPrice) / mois")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.primary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.background))

            Text("• Le paiement de \(formattedSubscriptionPrice) sera débité de votre compte Identifiant Apple lors de la confirmation de l'achat.\n• L'abonnement se renouvelle automatiquement chaque mois au tarif de \(formattedSubscriptionPrice) / mois, sauf si le renouvellement automatique est désactivé au moins 24 heures avant la fin de la période mensuelle en cours.\n• Votre compte sera facturé pour le renouvellement dans les 24 heures précédant la fin de la période en cours.\n• Vous pouvez gérer votre abonnement et désactiver le renouvellement automatique à tout moment après l'achat dans les Réglages de votre compte App Store.")
                .font(.system(size: 11.5))
                .foregroundStyle(LivriaPalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    if let privacyUrl = URL(string: "https://livria.store/privacy") {
                        Link(destination: privacyUrl) {
                            HStack(spacing: 5) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.caption2)
                                Text("Politique de Confidentialité")
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LivriaPalette.background))
                            .foregroundStyle(LivriaPalette.primary)
                        }
                    }

                    if let appleEulaUrl = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        Link(destination: appleEulaUrl) {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.badge.gearshape.fill")
                                    .font(.caption2)
                                Text("Conditions d'Utilisation (EULA)")
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LivriaPalette.background))
                            .foregroundStyle(LivriaPalette.primary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    if let livriaTermsUrl = URL(string: "https://livria.store/eula") {
                        Link(destination: livriaTermsUrl) {
                            HStack(spacing: 5) {
                                Image(systemName: "safari.fill")
                                    .font(.caption2)
                                Text("CGU / CGV Livria Store (Web)")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LivriaPalette.background))
                            .foregroundStyle(LivriaPalette.ink)
                        }
                    }

                    Button {
                        store.isShowingTermsReviewSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .font(.caption2)
                            Text("Lire CGU / Confidentialité")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LivriaPalette.background))
                        .foregroundStyle(LivriaPalette.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .livriaCard()
    }

    // MARK: - 1. Page de Présentation & Souscription Looby+ In-App (3,50 €/mois) pour les Non-Abonnés

    private var subscribeShowcaseContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero Carte 3,50 €/mois (Achat In-App StoreKit 2)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ABONNEMENT LOOBY+", systemImage: "crown.fill")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LivriaPalette.gold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("Achat intégré App Store")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(store.loobyPlusStoreKitProduct?.displayName ?? "Abonnement Looby+ Mensuel")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                Text("Toute la magie de Livria en illimité • Durée : 1 mois (renouvellement automatique mensuel)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedSubscriptionPrice)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.gold)
                    Text("/ mois (1 mois) • Sans engagement")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(spacing: 10) {
                    Button {
                        Task {
                            await store.purchaseLoobyPlusInApp()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isPurchasingLoobyPlus {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "apple.logo")
                            }
                            Text("S'abonner à Looby+ (\(formattedSubscriptionPrice) / mois)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LivriaPalette.gold)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(store.isPurchasingLoobyPlus)

                    Button {
                        Task {
                            await store.restoreLoobyPlusPurchases()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Restaurer mon abonnement App Store")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.16))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .disabled(store.isPurchasingLoobyPlus)

                    HStack(spacing: 16) {
                        if let privacyUrl = URL(string: "https://livria.store/privacy") {
                            Link("Politique de Confidentialité", destination: privacyUrl)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LivriaPalette.goldSoft)
                                .underline()
                        }
                        Text("•")
                            .foregroundStyle(.white.opacity(0.6))
                        if let eulaUrl = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            Link("Conditions d'Utilisation (EULA)", destination: eulaUrl)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LivriaPalette.goldSoft)
                                .underline()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivriaPalette.loobyPlusGradient))
            .shadow(color: LivriaPalette.primary.opacity(0.3), radius: 16, x: 0, y: 8)

            // Liste des privilèges Looby+
            VStack(alignment: .leading, spacing: 14) {
                Text("Vos avantages exclusifs Looby+")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)

                benefitRow(icon: "shippingbox.fill", title: "Livraison UPS & Points Relais 100% Gratuite", desc: "Frais de port offerts dès 0,01 € d'achat sur toute la Boutique Livria.")
                benefitRow(icon: "headphones", title: "1 Crédit Livre Audio Offert / mois", desc: "Débloquez chaque mois le livre audio de votre choix à écouter sur iPhone et iPad.")
                benefitRow(icon: "eurosign.arrow.circlepath", title: "5% de Cashback Automatique", desc: "Chaque commande crédite 5% dans votre cagnotte utilisable dès l'achat suivant.")
                benefitRow(icon: "book.pages.fill", title: "Catalogue Numérique Discover+", desc: "Accès gratuit aux éditions numériques ePub et livres audio sur Livria.")
                benefitRow(icon: "gift.fill", title: "Box Surprise Mensuelle sur-mesure", desc: "Configurez vos genres favoris et vos tropes à éviter pour votre sélection personnalisée.")
                benefitRow(icon: "person.3.sequence.fill", title: "Partage Familial 4 Comptes Viple Live ID", desc: "Faites profiter jusqu'à 4 proches de vos avantages Looby+ sans surcoût.")
            }
            .livriaCard()
        }
    }

    private func benefitRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LivriaPalette.goldSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(Color(red: 0.65, green: 0.35, blue: 0.02))
                    .font(.system(size: 17, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(LivriaPalette.ink)
                Text(desc)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LivriaPalette.inkMuted)
            }
        }
    }

    // MARK: - 2. Dashboard Abonné Looby+ Complet

    private var subscriberDashboardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Carte Membre Looby+ Or
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("MEMBRE LOOBY+ ACTIF", systemImage: "crown.fill")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LivriaPalette.gold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("3,50 € / mois")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivriaPalette.goldSoft)
                }

                Text(store.currentUser?.displayName ?? "Membre Viple Live ID")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    loobyStatPill(title: "Crédits Audio", value: "\(store.currentUser?.audioCredits ?? store.loobyPlus?.audioCredits ?? 0)", icon: "headphones")
                    loobyStatPill(title: "Cashback 5%", value: String(format: "%.2f €", store.currentUser?.cashbackBalance ?? 0), icon: "eurosign.circle.fill")
                    loobyStatPill(title: "Livraison", value: "0,00 €", icon: "shippingbox.fill")
                }

                NavigationLink {
                    LoobyPlusSubscriptionManagementView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("Gérer mon abonnement Looby+")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivriaPalette.loobyPlusGradient))

            // Section Gérer mon abonnement Looby+
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.and.123")
                        .font(.title3)
                        .foregroundStyle(LivriaPalette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mon Abonnement Looby+")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(LivriaPalette.ink)
                        Text("Formule mensuelle sans engagement • 3,50 € / mois")
                            .font(.system(size: 12))
                            .foregroundStyle(LivriaPalette.inkMuted)
                    }
                    Spacer()
                    Text("ACTIF")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(Color.green)
                }

                NavigationLink {
                    LoobyPlusSubscriptionManagementView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Accéder à la page de gestion de l'abonnement")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.primary.opacity(0.1)))
                    .foregroundStyle(LivriaPalette.primary)
                }
                .buttonStyle(.plain)
            }
            .livriaCard()

            // Échange Crédit Audio Looby+ (uniquement les livres disponibles au format Audio)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "headphones.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Utiliser un Crédit Livre Audio Looby+")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }

                if audioEligibleBooks.isEmpty {
                    Text("Aucun livre disposant d'un format Audio n'est actuellement disponible dans le catalogue.")
                        .font(.system(size: 13))
                        .foregroundStyle(LivriaPalette.inkMuted)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                } else {
                    Picker("Ouvrage Audio", selection: $selectedBookToRedeem) {
                        ForEach(audioEligibleBooks) { b in
                            Text("\(b.title) — \(b.author)").tag(b.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))

                    Button {
                        if selectedBookToRedeem > 0 {
                            Task {
                                await store.redeemAudioCredit(bookId: selectedBookToRedeem)
                            }
                        }
                    } label: {
                        Text("Débloquer ce Livre Audio avec 1 crédit")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.primary))
                            .foregroundStyle(.white)
                    }
                }
            }
            .livriaCard()

            // Configuration Box Surprise Mensuelle
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gift.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LivriaPalette.coral)
                    Text("Ma Box Surprise Mensuelle Looby+")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }

                TextField("Genres favoris (ex: Thriller, Science-Fiction, Romance)", text: $boxGenres)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                TextField("Thèmes ou tropes à éviter", text: $boxDisliked)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                TextField("Notes pour votre libraire Livria", text: $boxNotes)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                TextField("Adresse de livraison de la Box", text: $boxAddress)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))

                Button {
                    Task {
                        await store.saveBoxPreferences(genres: boxGenres, dislikedTropes: boxDisliked, notes: boxNotes, address: boxAddress)
                    }
                } label: {
                    Text("Enregistrer mes préférences Box Surprise")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.coral))
                        .foregroundStyle(.white)
                }
            }
            .livriaCard()

            // Partage Familial (jusqu'à 4 proches)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Partage Familial Looby+ (\(store.loobyPlus?.familyMembers.count ?? 0) / 4)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }

                ForEach(store.loobyPlus?.familyMembers ?? []) { member in
                    HStack {
                        Text(member.avatar)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LivriaPalette.ink)
                            Text(member.isKidsMode ? "Profil Jeunesse sécurisé" : "Membre adulte Viple Live ID")
                                .font(.system(size: 11.5))
                                .foregroundStyle(LivriaPalette.inkMuted)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                await store.removeFamilyMember(memberId: member.id)
                            }
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LivriaPalette.background))
                }

                if (store.loobyPlus?.familyMembers.count ?? 0) < 4 {
                    HStack(spacing: 8) {
                        TextField("Prénom ou email Viple Live ID du proche", text: $newFamilyMemberName)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.background))
                        Toggle("Enfant", isOn: $newFamilyKidsMode)
                            .labelsHidden()
                        Button("Ajouter") {
                            guard !newFamilyMemberName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let name = newFamilyMemberName
                            newFamilyMemberName = ""
                            Task {
                                await store.addFamilyMember(name: name, isKidsMode: newFamilyKidsMode)
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LivriaPalette.primary))
                        .foregroundStyle(.white)
                    }
                }
            }
            .livriaCard()
        }
    }

    private func loobyStatPill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(LivriaPalette.gold)
                .font(.caption)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
    }
}

// MARK: - Page Dédiée : Gérer mon abonnement Looby+

public struct LoobyPlusSubscriptionManagementView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCancelConfirmation: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. En-tête de l'abonnement actif
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("ABONNEMENT ACTIF", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(LivriaPalette.gold))
                            .foregroundStyle(.black)
                        Spacer()
                        Text("Sans engagement")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Text("Looby+ Club Privilège")
                        .font(.system(size: 24, weight: .black, design: .serif))
                        .foregroundStyle(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("3,50 €")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(LivriaPalette.gold)
                        Text("/ mois • Renouvellement mensuel")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Divider().overlay(Color.white.opacity(0.2))

                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LivriaPalette.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.currentUser?.displayName ?? "Membre Viple Live ID")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text(store.currentUser?.email ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivriaPalette.loobyPlusGradient))

                // 2. Récapitulatif des avantages actifs sur le compte
                VStack(alignment: .leading, spacing: 14) {
                    Text("État de vos privilèges Looby+")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)

                    managementRow(
                        icon: "shippingbox.fill",
                        title: "Livraison UPS & Points Relais",
                        value: "0,00 € (Illimitée)",
                        tint: .green
                    )
                    managementRow(
                        icon: "headphones",
                        title: "Crédits Livre Audio disponibles",
                        value: "\(store.currentUser?.audioCredits ?? store.loobyPlus?.audioCredits ?? 0) crédit(s)",
                        tint: LivriaPalette.primary
                    )
                    managementRow(
                        icon: "eurosign.arrow.circlepath",
                        title: "Cagnotte Cashback 5%",
                        value: String(format: "%.2f €", store.currentUser?.cashbackBalance ?? 0),
                        tint: .orange
                    )
                    managementRow(
                        icon: "person.3.fill",
                        title: "Partage Familial Viple Live ID",
                        value: "\(store.loobyPlus?.familyMembers.count ?? 0) / 4 proches",
                        tint: LivriaPalette.primary
                    )
                    managementRow(
                        icon: "gift.fill",
                        title: "Box Surprise Mensuelle",
                        value: (store.loobyPlus?.boxPreferences.preferredGenres.isEmpty == false) ? "Personnalisée" : "À configurer",
                        tint: LivriaPalette.coral
                    )
                }
                .livriaCard()

                // 3. Gestion App Store & Synchronisation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gestion App Store & Facturation")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)

                    Text("Vous pouvez consulter vos échéances App Store ou synchroniser vos droits d'abonnement à tout moment.")
                        .font(.system(size: 13))
                        .foregroundStyle(LivriaPalette.inkMuted)

                    Button {
                        Task {
                            await openAppStoreSubscriptionSettings()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                            Text("Gérer dans les abonnements App Store")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.background))
                        .foregroundStyle(LivriaPalette.ink)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await store.restoreLoobyPlusPurchases()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Synchroniser / Restaurer mon abonnement")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LivriaPalette.background))
                        .foregroundStyle(LivriaPalette.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPurchasingLoobyPlus)
                }
                .livriaCard()

                // 4. Résiliation de l'abonnement Looby+
                VStack(alignment: .leading, spacing: 12) {
                    Text("Résiliation")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)

                    Text("Votre abonnement Looby+ est sans engagement. En résiliant, la livraison offerte, le cashback 5% et le partage familial seront désactivés sur votre compte.")
                        .font(.system(size: 13))
                        .foregroundStyle(LivriaPalette.inkMuted)

                    Button(role: .destructive) {
                        isShowingCancelConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            if store.isPurchasingLoobyPlus {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text("Résilier mon abonnement Looby+")
                                .font(.system(size: 14.5, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red.opacity(0.35), lineWidth: 1))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPurchasingLoobyPlus)
                }
                .livriaCard()
            }
            .padding(16)
        }
        .livriaThemedBackground(store.currentThemeId)
        .navigationTitle("Gérer mon abonnement")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Résilier Looby+ ?", isPresented: $isShowingCancelConfirmation) {
            Button("Conserver mon abonnement", role: .cancel) {}
            Button("Confirmer la résiliation", role: .destructive) {
                Task {
                    let ok = await store.cancelLoobyPlusSubscription()
                    if ok {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Souhaitez-vous vraiment résilier votre abonnement Looby+ ? Vos crédits livres audio déjà acquis resteront sur votre compte, mais vos avantages membres (livraison 0 €, cashback 5% et partage familial) prendront fin immédiatement.")
        }
    }

    private func managementRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(LivriaPalette.ink)
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(LivriaPalette.ink)
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func openAppStoreSubscriptionSettings() async {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                store.showToast("Impossible d'ouvrir la gestion des abonnements App Store.")
            }
        }
        #endif
    }
}
