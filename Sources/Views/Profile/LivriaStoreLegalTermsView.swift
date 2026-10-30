import SwiftUI

// MARK: - Conditions Générales d'Utilisation et de Vente Complètes (Livria Store & Viple Live ID)

public struct LivriaStoreLegalTermsView: View {
    @EnvironmentObject private var store: LivriaStoreViewModel
    @Environment(\.dismiss) private var dismiss

    public let isFirstLaunchGate: Bool
    @State private var hasCheckedConsent: Bool = false

    public init(isFirstLaunchGate: Bool = true) {
        self.isFirstLaunchGate = isFirstLaunchGate
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard

                        externalLinksCard

                        ForEach(Self.legalArticles) { article in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: article.icon)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(LivriaPalette.primary)
                                    Text(article.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(LivriaPalette.ink)
                                }

                                Text(article.body)
                                    .font(.system(size: 13))
                                    .foregroundStyle(LivriaPalette.inkMuted)
                                    .lineSpacing(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .livriaCard(padding: 16)
                        }
                    }
                    .padding(16)
                }

                bottomActionCard
            }
            .livriaThemedBackground(store.currentThemeId)
            .navigationTitle("Conditions Générales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstLaunchGate {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isFirstLaunchGate)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LivriaPalette.gold)
                    Text("Livria Store × Viple Live ID")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("Édition 2026")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LivriaPalette.gold))
            }

            Text("Conditions Générales d'Utilisation et de Vente (CGU / CGV)")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Veuillez prendre connaissance des présentes Conditions Générales régissant vos achats en librairie (neuf, occasion, numérique et audio), l'espace troc, l'abonnement Club Looby+ ainsi que votre compte unifié Viple Live ID.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .background(
            LivriaMeshHeroBackground()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
    }

    private var externalLinksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(LivriaPalette.primary)
                Text("Documents légaux officiels & Abonnement App Store")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LivriaPalette.ink)
            }

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
        }
        .livriaCard(padding: 14)
    }

    private var bottomActionCard: some View {
        VStack(spacing: 12) {
            if isFirstLaunchGate {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        hasCheckedConsent.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: hasCheckedConsent ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(hasCheckedConsent ? LivriaPalette.primary : LivriaPalette.inkMuted)

                        Text("Je certifie avoir lu et j'accepte sans réserve les Conditions Générales d'Utilisation et de Vente de Livria Store et du compte Viple Live ID.")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(LivriaPalette.ink)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    store.acceptTermsOfUse()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Accepter et accéder à Livria Store")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                hasCheckedConsent
                                    ? AnyShapeStyle(LinearGradient(colors: [LivriaPalette.primary, LivriaPalette.coral], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.gray.opacity(0.35))
                            )
                    )
                }
                .disabled(!hasCheckedConsent)
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(LivriaPalette.mint)
                    Text("Conditions Générales acceptées sur cet appareil.")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LivriaPalette.ink)
                    Spacer()
                    Button("Fermer") {
                        dismiss()
                    }
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(LivriaPalette.primary)
                }
            }
        }
        .padding(16)
        .background(
            LivriaPalette.cardPaper
                .overlay(Rectangle().fill(LivriaPalette.border).frame(height: 1), alignment: .top)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -3)
        )
    }

    public struct LegalArticle: Identifiable, Sendable {
        public let id: Int
        public let icon: String
        public let title: String
        public let body: String
    }

    public static let legalArticles: [LegalArticle] = [
        LegalArticle(
            id: 1,
            icon: "doc.text.fill",
            title: "1. Objet et éditeur du service",
            body: "Les présentes Conditions Générales d'Utilisation et de Vente (CGU/CGV) régissent l'utilisation de l'application « Livria Store », la commande d'ouvrages neufs, d'occasion, numériques (ePub) et livres audio, ainsi que l'utilisation du compte d'authentification unifié « Viple Live ID » édités par Viple."
        ),
        LegalArticle(
            id: 2,
            icon: "person.badge.key.fill",
            title: "2. Compte Viple Live ID et commande en mode Invité",
            body: "Livria Store permet de parcourir le catalogue et de passer commande en mode Invité ou via un compte personnel Viple Live ID. À l'issue d'une commande en mode Invité, le client peut activer son compte Viple Live ID en un clic afin de retrouver l'historique de ses achats, ses bordereaux UPS, sa bibliothèque numérique et sa cagnotte de fidélité sur l'ensemble des applications Viple."
        ),
        LegalArticle(
            id: 3,
            icon: "bag.fill",
            title: "3. Prix des livres, formats et disponibilité",
            body: "Les prix des livres neufs sont fixés dans le strict respect de la loi n° 81-766 du 10 août 1981 relative au prix unique du livre (Loi Lang). Les ouvrages d'occasion vérifiés, les éditions numériques et les livres audio sont proposés aux tarifs indiqués en euros toutes taxes comprises (TTC) sur chaque fiche produit."
        ),
        LegalArticle(
            id: 4,
            icon: "creditcard.fill",
            title: "4. Modalités de paiement sécurisé",
            body: "Le règlement des commandes s'effectue via les moyens de paiement actifs lors de la validation du panier (PayPal, Apple Pay, Google Pay, points de fidélité et cagnotte Looby+). Certains modes de paiement peuvent être momentanément désactivés pour maintenance et apparaissent alors comme indisponibles. Toute commande payée est confirmée dès validation de la transaction."
        ),
        LegalArticle(
            id: 5,
            icon: "shippingbox.fill",
            title: "5. Expédition UPS et Points Relais",
            body: "Les ouvrages physiques sont expédiés à domicile ou dans le Point Relais UPS / relais communautaire sélectionné par le client. Lorsqu'un point relais est choisi dans la section « Points Relais » de l'application, celui-ci est automatiquement pré-sélectionné par défaut lors du passage en caisse, tout en laissant la possibilité d'en changer avant validation."
        ),
        LegalArticle(
            id: 6,
            icon: "arrow.uturn.backward.circle.fill",
            title: "6. Annulation de commande et droit de rétractation",
            body: "Conformément à l'article L.221-18 du Code de la consommation, le client dispose d'un délai de 14 jours à compter de la réception des ouvrages physiques pour exercer son droit de rétractation. Toute commande non encore expédiée peut être annulée directement depuis la rubrique « Mes Commandes » après confirmation."
        ),
        LegalArticle(
            id: 7,
            icon: "crown.fill",
            title: "7. Abonnement Auto-Renouvelable Club Looby+ (3,49 € / mois)",
            body: "Titre de l'abonnement : Abonnement Looby+ Mensuel (identifiant App Store : store.livria.loobyplus.monthly). Durée : 1 mois (renouvellement automatique mensuel). Prix : 3,49 € / mois TTC sans engagement. L'abonnement peut être souscrit et utilisé avec ou sans création de compte préalable. Le paiement est débité du compte Identifiant Apple à la confirmation de l'achat et se renouvelle automatiquement sauf résiliation au moins 24 heures avant la fin de la période en cours depuis les Réglages du compte App Store. Le contrat de licence standard d'Apple (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) ainsi que nos CGU/CGV (https://livria.store/eula) s'appliquent."
        ),
        LegalArticle(
            id: 8,
            icon: "lock.shield.fill",
            title: "8. Politique de Confidentialité et Protection des Données (RGPD)",
            body: "Conformément au Règlement Général sur la Protection des Données (RGPD), aucune création de compte personnelle n'est imposée pour souscrire à un achat intégré ou naviguer dans l'application. Notre Politique de Confidentialité complète est consultable à tout moment sur https://livria.store/privacy. Vous pouvez exercer vos droits d'accès, de modification et de suppression en 1 clic depuis votre profil ou auprès du service client."
        )
    ]
}
