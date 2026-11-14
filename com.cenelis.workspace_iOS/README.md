# Cenelis Workspace / Admin Hub (`com.cenelis.workspace_iOS`)

Application iOS native (**Swift 6 / SwiftUI + WKWebView**, iOS 18+) servant de hub d'administration unifié (« Super-App Wrapper ») pour l'ensemble des 24 consoles `/admin` de l'écosystème **Groupe Cenelis / Viple SA** (`*.cenelis.com`, `grc.ext-sysprod.cenelis.com`, `control.ext-sysprod.cenelis.com`, `*.viple.digital`, `*.viplenetwork.com`, `*.livria.store`, `*.viplemail.fr`), avec routage inter-applications et contournement cryptographique du code PIN vers **Cenelis Academy**.

---

## Architecture & Capacités Clés

### 1. Moteur Web Encapsulé & Session SSO Unifiée (`WKWebView`)
- **Pool & Stockage partagés** (`Sources/Services/WorkspaceKeychainAndSessionPool.swift`) : `WKProcessPool` unique et `WKWebsiteDataStore.default()` partagés entre toutes les consoles, complétés par une sauvegarde/restauration automatique des cookies maîtres (`viple.id.v2`, `.Cenelis.Connect.Auth`) dans le Trousseau iOS (`Keychain`) et une amorce silencieuse du pont SSO `sso.prod.cenelis.com`.
- **Ergonomie 100 % native** (`Sources/WebEngine/CenelisPanelWebView.swift`) :
  - Absence totale de barre d'URL et de contrôles Safari classiques.
  - `UIRefreshControl` natif rattaché au `scrollView` de la `WKWebView` (*Pull-to-Refresh*).
  - Geste natif *Swipe-Back* (`allowsBackForwardNavigationGestures = true`) et respect strict des *Safe Areas* iOS.
  - Injection `WKUserScript` (`atDocumentStart` et `atDocumentEnd` + `MutationObserver`) masquant le dock web redondant (`div.vua-dock`, `#vua-dock-burger`, `aside.vua-panel`, `div.vua-backdrop`) tout en préservant l'intégralité de la logique interne `viple-admin.js` (onglets métiers et barres latérales responsives).

### 2. Hub de Démarrage & Recherche Native à 3 Onglets (`Sources/Views/Hub/WorkspaceHubView.swift`)
- **Grille / Liste synchronisée RBAC** : synchronisée dynamiquement avec `GET https://api.viple.digital/api/public/admin-directory` et filtrée selon les permissions effectives `GET /api/public/rbac/effective` de l'opérateur connecté.
- **3 Scopes de recherche native** :
  1. **Panels** : filtre instantané des consoles `/admin` et ouverture directe dans la `WKWebView`.
  2. **Fonctions** : recherche d'actions et sous-modules profonds (*« Habiliter »*, *« Matrice RBAC »*, *« Registre »*, *« Devis CPQ »*, *« Bristol »*…) avec ouverture de la route exacte et sélection automatique de l'onglet cible.
  3. **Aide · Academy** : interrogation en direct de `GET https://academy.prod.cenelis.com/api/mobile/v1/search` et ouverture directe de la **section exacte du cours** dans l'application native **Cenelis Academy** (`cenelisacademy://handoff?...`).

### 3. Menu Flottant `/admin` 100 % Natif (`Sources/Views/Shell/NativeAdminFloatingMenu.swift`)
- **Pastille ronde sombre superposée (`ZStack`)** en bas à droite affichant **uniquement** l'icône hamburger (`line.3.horizontal`).
- **Tap** : ouvre une `sheet` native listant toutes les consoles `/admin` habilitées avec sondes de disponibilité temps réel (statut + latence en ms), contrôles de navigation et retour instantané au Hub.
- **Balayage vers la droite (*Swipe-Right to Hide*)** : `DragGesture` horizontal vers la droite animant la sortie du bouton hors de l'écran (`isFloatingBurgerHidden = true`).
- **Appui long de 2 secondes (*2s Long-Press to Reveal*)** : zone tactile invisible (`Color.white.opacity(0.001)` + `.contentShape(Rectangle())`) maintenue en bas à droite ; un `onLongPressGesture(minimumDuration: 2.0)` déclenche un retour haptique (`UIImpactFeedbackGenerator`) et réanime le bouton à l'écran.

### 4. Sécurité « Cenelis Connect PIN » & Changement de Compte (`Sources/Views/Auth/WorkspaceAuthAndPinViews.swift`)
- **Session Viple Live ID persistante** sans reconnexion répétée.
- **Verrouillage natif systématique** au lancement à froid **et** à chaque retour au premier plan (`scenePhase == .active` après passage en `.background`), doublé d'un voile de confidentialité dans le sélecteur multitâche iOS.
- **Neutralisation de la redemande web toutes les 1h** : boucle `keepalive` active toutes les 12 minutes (`POST /api/workspace/pin/keepalive` + `POST /api/governance/pin/keepalive`) avec User-Agent unifié (`mob:ios:safari`) et interception transparente d'une éventuelle redirection `/pin`.
- **Déconnexion globale (« Se déconnecter »)** positionnée **tout en haut de l'en-tête de la modale native du menu `/admin`** : révocation serveur, purge intégrale du `WKWebsiteDataStore` et du `Keychain`, réinitialisation du PIN et retour à l'écran Viple Live ID.

### 5. Routage Inter-Applications & Bypass PIN vers « Cenelis Academy »
- Tout clic sur **Cenelis Academy** (depuis le Hub, la modale `/admin`, l'onglet *Aide*, ou un lien interne intercepté dans une `WKWebView`) n'ouvre jamais le site web dans la WebView mais déclenche `UIApplication.shared.open` vers `cenelisacademy://handoff`.
- Émission d'un jeton cryptographique signé HMAC-SHA256 à usage unique (`capb_v1.*`, validité courte + `jti` 128 bits consommé atomiquement par `POST /api/mobile/v1/auth/redeem-pin-bypass`) permettant à **Cenelis Academy** de déverrouiller automatiquement sa garde PIN et d'ouvrir directement le cours et la section demandés.

---

## Structure du Projet

- `CenelisWorkspace.xcodeproj/project.pbxproj` — Projet Xcode 16+ (`PBXFileSystemSynchronizedRootGroup`, Bundle ID `com.cenelis.workspace`, iOS 18.0).
- `Package.swift` — Manifeste Swift Package Manager (Swift 6.0).
- `Info.plist` & `CenelisWorkspace.entitlements` — Schémas URL (`cenelisworkspace://`, requête `cenelisacademy://`) et App Groups partagés.
- `Assets.xcassets` — Icône officielle `AppIcon.png` (1024×1024 opaque 24-bit) et `AccentColor`.
- `Sources/App/CenelisWorkspaceApp.swift` — Cycle de vie `ScenePhase`, routage d'états de sécurité et voile multitâche.
- `Sources/Models/WorkspaceModels.swift` — Modèles typés, miroir RBAC, référentiel des 24 panels et catalogue des fonctions métiers.
- `Sources/Services/WorkspaceKeychainAndSessionPool.swift` — Pool WebKit partagé, `WKUserScript` CSS/DOM, Keychain et purge globale.
- `Sources/Services/WorkspaceAPIClient.swift` — Client réseau async/await (`sso.prod.cenelis.com`, `api.viple.digital`, `academy.prod.cenelis.com`).
- `Sources/Services/WorkspaceStoreViewModel.swift` — Orchestration d'état `@MainActor`, keepalive PIN, sondes de santé et handoff Academy.
- `Sources/WebEngine/CenelisPanelWebView.swift` — `UIViewRepresentable` `WKWebView` avec `UIRefreshControl`, *Swipe-Back* et interceptions.
- `Sources/Views/Auth/WorkspaceAuthAndPinViews.swift` — Connexion Viple Live ID et pavé numérique natif Cenelis Connect PIN.
- `Sources/Views/Hub/WorkspaceHubView.swift` — Hub de démarrage et recherche native multi-onglets (*Panels*, *Fonctions*, *Aide*).
- `Sources/Views/Shell/NativeAdminFloatingMenu.swift` — Coque WebView, pastille hamburger gestuelle et modale `/admin` native.
