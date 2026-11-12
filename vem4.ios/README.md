# Viple & Moi (`vem4.ios`) — Application Native iOS de l'Espace Client Viple v4

**Viple & Moi** (`com.viplenetwork.vem4`) est l'application iOS native compagnon du nouvel **Espace Client Viple v4** (`https://espace-client-v4.viplenetwork.com`), conçue en **Swift 6.0 / SwiftUI (iOS 18+)** avec un design animé Aurora, des jauges circulaires dynamiques, des retours haptiques et 100 % des fonctionnalités de l'espace web.

## Fonctionnalités Clés

1. **Authentification Viple Live & SSO Mobile (`vipleetmoi://auth`)**
   - Connexion directe avec identifiant Viple Live / `@viplemail.fr` (`/api/mobile/v1/auth/login`) ou flux SSO Web (`ASWebAuthenticationSession`).
   - Détection automatique du compte partagé via les App Groups `group.com.viplenetwork.shared` et `group.store.livria.shared`.

2. **Cockpit Services & Distinction Stricte Serveur vs Hors-Serveur**
   - **Serveurs Cloud & Gaming VPS (`isServerService == true`)** : console `[VIPLE-CLOUD]`, état `Serveur démarré` / `Serveur arrêté`, copie IP/hostname, actions `Démarrer le serveur`, `Arrêter le serveur` et `Redémarrer`.
   - **Équipements Domestiques (`box-5g`, `decodeur-tv`)** : état `Connexion active` / `Décodeur actif` et bouton dédié `Relancer le boîtier à distance` (sans aucun bouton d'arrêt serveur).
   - **Forfaits Mobiles 5G, Pass Looby+ & Livria+, Hébergement Web, Téléphonie SIP** : statuts métier continus (`Ligne 5G active`, `Avantages actifs`, `Hébergement actif`, `Ligne fixe active`) sans jamais afficher de contrôle ni de libellé serveur.
   - **Messagerie Souveraine Viple Mail (`@viplemail.fr`)** : incluse gratuitement à vie (0,00 €), jauge 5 Go Stalwart, accès Webmail et gestion complète jusqu'à 5 alias `@viplemail.fr` (ajout, remplacement, suppression).

3. **Boutique Officielle Viple & Garantie Tarifaire**
   - Souscription en 1 geste des offres commercialisées (Cloud VPS, Box 5G Zéro Fibre, StreamBox TV 4K, Forfaits 5G, Looby+ & Livria+) pour soi-même ou pour un proche du foyer.
   - Protection explicite des offres historiques retirées du catalogue.

4. **Ma Famille, Délégation Viple Live & Contrôle des Options**
   - Création et gestion des profils du foyer (ex. *Hugo · Fils*), liaison d'e-mail Viple Live pour accès autonome sur le téléphone du proche.
   - Interrupteur instantané autorisant ou bloquant l'achat autonome d'options, avec système complet de demande d'approbation parentale et validation en 1 geste.

5. **Suivi Commandes Livria Store & Colis Viple Delivery**
   - Synchronisation automatique (`/api/client/orders-delivery`), barre de progression en 4 étapes, couvertures des ouvrages commandés, relais **Point Viple Taker**, code-barres Viple Delivery et chronologie d'acheminement.

6. **Facturation SEPA (5 / 10 / 15), PayPal & Factures Certifiées 2D-DOC (`VP01`)**
   - Carte 3D interactive du foyer, signature de mandat SEPA avec choix du jour de prélèvement (**le 5, le 10 ou le 15 du mois**), paiement PayPal (`vipleetmoi://paypal`).
   - Visionneuse native des factures certifiées avec génération du cachet cryptographique **ANTS DC04 · VP01 / V26A (ECDSA NIST P-256)** et vérification directe sur `2d-doc.prod.cenelis.com`.

7. **Mon Compte Viple Live & Cours Client Interactif de A à Z**
   - Éditeur de profil unifié Viple Live, outil de recadrage photo carré 260×260, galerie d'avatars officiels et changement de mot de passe unifié (SSO + IMAP/SMTP).
   - Lecteur natif intégré du cours `guide-espace-client-v4` (Cenelis Academy) avec bulles de vulgarisation sans jargon, fiches *« Expliquer plus simplement »* et quiz final noté avec confettis.

## Ouverture dans Xcode

Ouvrez `VipleEtMoi.xcodeproj` dans **Xcode 16+** (`objectVersion = 77`, synchronisation automatique du dossier `Sources/`), sélectionnez une cible iPhone sous **iOS 18.0+** et lancez **Run (`⌘R`)**.
