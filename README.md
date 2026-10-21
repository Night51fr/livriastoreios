# Livria Store — Application iOS 100% Native (Apple App ID : `6825159743` • SwiftUI • iOS 18.0+ / iOS 26.0+)

Application mobile officielle **Livria Store** (`CFBundleDisplayName = "Livria Store"`, Apple App Store ID : **`6825159743`**) pour iPhone et iPad, codée intégralement en **Swift 6 / SwiftUI natif**, compatible à partir d'**iOS 18.0** (`IPHONEOS_DEPLOYMENT_TARGET = 18.0`) avec prise en charge native du design **iOS 26 Liquid Glass** (`#available(iOS 26.0, *)`) et des dégradés dynamiques **`MeshGradient`**.

## Découpage de l'Écosystème iOS Viple

1. **Livria Store (cette application — App Store ID `6825159743`)** : Dédiée à l'**achat de livres (Neuf & Occasion)**, au **Troc de livres**, à **Looby+**, au **suivi de commandes UPS / Viple Delivery**, aux **Points Relais** et à l'**Assistance Viple**.
2. **Livria Social (2e application dédiée)** : Dédiée au réseau social `LivriaSocial` (`livriasocial.viplenetwork.com`), au fil d'actualité, aux profils personnalisables, aux listes de livres rémunérées et à la messagerie instantanée.
3. **Viple & Moi (3e application dédiée)** : Regroupera tous les espaces clients Viple, dont l'espace **« Ma Bibliothèque »** de Livria (`my.livria.store`). *Aucune vue « Ma Bibliothèque » n'est présente dans Livria Store ni dans Livria Social.*

## Architecture & Connexion Temps Réel

- **API Mobile Livria Store** : `https://livria.store/api/mobile/v1/*` (`Livria/Services/LivriaMobileApiEndpoints.cs`)
- **Mode Invité (Checkout sans compte) + Création de compte en 1 clic après commande** :
  - L'application s'ouvre directement sur la boutique en session invité ou authentifiée.
  - L'acheteur peut commander sans compte, puis sur l'écran de confirmation, créer son compte ou se connecter en 1 clic (E-mail et Nom pré-remplis depuis le checkout, seul le mot de passe est demandé).
- **Authentification Native Viple Live ID** : `https://identity-v2.viple.digital/api/mobile/auth` & `/api/mobile/register`
  - Connexion directe par compte **Viple Live ID**
  - Inscription native avec les **deux modalités officielles** (`@viplemail.fr` ou adresse e-mail externe).
- **Apple Pay / Google Pay / PayPal via l'API PayPal** :
  - Endpoint dédié `POST /api/mobile/v1/checkout/paypal-create` (`apple_pay`, `google_pay`, `paypal`).

## Fonctionnalités Incluses dans Livria Store (`6825159743`)

1. **Accueil (`HomeView.swift`)** : En-tête `MeshGradient` iOS 18+, accès rapide Boutique / Troc / Scanner ISBN / Looby+, carrousels Coups de cœur, **Livres d'Occasion Certifiés** (`♻️ Occasion`), Nouveautés et Petits Prix.
2. **Boutique Neuf & Occasion (`BoutiqueView.swift` & `BookDetailView.swift`)** :
   - **Recherche double** : `📚 Livres` (titre, auteur, ISBN, genre) et `👥 Membres` (profils publics).
   - **Filtre d'état** : `Tous états`, `✨ Neuf`, `♻️ Occasion`.
   - **Sélecteur d'état sur la fiche livre** : Permet de choisir entre l'exemplaire **✨ Neuf** et l'exemplaire **♻️ Occasion** (`Occasion - Comme neuf`, `Occasion - Très bon état`, `Occasion - Bon état`, `Occasion - État correct`) au prix indiqué de chacun, synchronisé avec Viple Wingman.
   - **Bande-son d'ambiance interactive** (`LivriaAmbientSoundPlayer`) et **Résumé IA garanti sans spoiler**.
3. **Troc de Livres (`TradeView.swift`)** : Onglet principal dédié au troc (Offres ouvertes, Mes offres, Mes demandes) avec **auto-remplissage par ISBN en 1 clic** (Google Books + OpenLibrary + Catalogue Livria).
4. **Looby+ (`LoobyPlusView.swift`)** : Souscription à **3,50 €/mois** et Dashboard Abonné (Livraison 0 €, Crédits Audio, Cashback 5%, Box Surprise, Partage Familial 4 comptes).
5. **Panier (`CartView.swift`), Checkout (`CheckoutView.swift`) & Commandes (`OrdersView.swift`)** : Distinction claire Neuf / Occasion, paiement express **Apple Pay / Google Pay via API PayPal**, Checkout sans compte + création de compte 1-clic post-commande, bordereaux **UPS (`1Z...`)** et suivi **Viple Delivery**.
6. **Points Relais Communautaires & UPS Access Point™ (`RelayPointsView.swift`)**, **Jeux Littéraires XP (`GamesHubView.swift`)**, **Assistance VipleAPI (`SupportAssistanceView.swift`)** et **Mon Profil Viple Live ID (`ProfileView.swift`)**.
