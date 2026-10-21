import SwiftUI

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
        store.currentUser?.isLivriaPlus == true || store.loobyPlus?.isSubscribed == true
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
                }
                .padding(16)
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle(isSubscribed ? "Dashboard Looby+" : "Souscrire à Looby+")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let pref = store.loobyPlus?.boxPreferences {
                    boxGenres = pref.preferredGenres
                    boxDisliked = pref.dislikedTropes
                    boxNotes = pref.specialNotes
                    boxAddress = pref.shippingAddress
                }
                if selectedBookToRedeem == 0, let first = store.books.first {
                    selectedBookToRedeem = first.id
                }
            }
        }
    }

    // MARK: - 1. Page de Présentation & Souscription Looby+ (3,50 €/mois) pour les Non-Abonnés

    private var subscribeShowcaseContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero Carte 3,50 €/mois
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ABONNEMENT LOOBY+", systemImage: "crown.fill")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LivriaPalette.gold))
                        .foregroundStyle(.black)
                    Spacer()
                    Text("Sans engagement")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text("Toute la magie de Livria en illimité pour seulement 3,50 € / mois")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundStyle(.white)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("3,50 €")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(LivriaPalette.gold)
                    Text("/ mois • Activation immédiate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(spacing: 10) {
                    Button {
                        Task {
                            await store.addLoobyPlusSubscriptionToCart(openCheckoutImmediately: true)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                            Text("Souscrire maintenant (3,50 €)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LivriaPalette.gold)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        Task {
                            await store.addLoobyPlusSubscriptionToCart(openCheckoutImmediately: false)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text("Ajouter Looby+ à mon panier (3,50 €)")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.16))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
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
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivriaPalette.loobyPlusGradient))

            // Échange Crédit Audio Looby+
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "headphones.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LivriaPalette.primary)
                    Text("Utiliser un Crédit Livre Audio Looby+")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LivriaPalette.ink)
                }

                Picker("Ouvrage Audio", selection: $selectedBookToRedeem) {
                    ForEach(store.books) { b in
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
