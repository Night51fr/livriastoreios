# Cenelis Academy — Application Native iOS (`com.cenelis.academy_iOS`)

Application mobile officielle **100 % native SwiftUI (Swift 6.0 · iOS 18+)** du portail de formation et d'excellence opérationnelle **Cenelis Academy** (`https://academy.prod.cenelis.com`).

> **« À tous, pour tous, par tous. »** — Groupe Cenelis (Cenelis SA · Charleville-Mézières)

---

## Points Clés

- **Synchronisation en direct & Mode Hors-Ligne Intégral** :
  - Récupère automatiquement tous les cours, chapitres, pages, quiz, questions de rattrapage, bulles vulgarisées, approfondissements 5 paliers et les 7 onglets encyclopédiques depuis `https://academy.prod.cenelis.com/api/mobile/v1/bootstrap?includeHidden=1`.
  - Tout nouveau cours ajouté sur le site web apparaît automatiquement en rendu **100 % natif SwiftUI** (aucune WebView).
  - Double cache local (`bootstrap_v1.json` + captures `@2x` sur disque) pour un démarrage en moins de 50 ms et un apprentissage fluide hors connexion.
- **Identité Visuelle Institutionnelle & Motion Design 60 fps** :
  - Palette **Pin Minéral (`#145346`)** & **Cuivre Ambré (`#B85D19`)**, modes *Automatique*, *Clair Ivoire* et *Sombre Minéral*.
  - Constellation orbitale animée (`TimelineView` + `Canvas`), passeport holographique 3D inclinable au doigt, pluie de confettis physique, bulles flottantes `+XP` et **les 17 scènes interactives & simulateurs métiers** rendus nativement.
- **Encore plus intuitif que le site web** :
  - Double mode de lecture (**Lecture Fluide** éditoriale ou **Cartes Focus** glissables bloc par bloc).
  - Bulles inline `{{clé|libellé}}` cliquables directement dans le texte + puces rapides sous chaque paragraphe.
  - Bascule instantanée **Captures Mobile `@2x` / Ordinateur `@2x`** avec repères numérotés interactifs et Lightbox plein écran zoomable.
  - **Capsules Vidéo Explicatives Motion Design (`AVKit` natif)** intégrées directement dans les chapitres et pages clés (26 capsules parlées en français avec sous-titres synchronisés temps réel, vitesses `0.75x` à `2x`, plein écran, transcription écrite complète et récompense `+30 XP` synchronisée sur le compte).
  - **Catalogue complet incluant le Cours 05 Viple SysGRC** (CRM, Devis CPQ, Facturation PDF, Support SLA P1–P4, Portail `/admin` & Master Control) et déconnexion globale SSO Viple Live ID (`logout.srf`).
  - Évaluation finale à 4 volets : seuil officiel **80 % « Apte à rejoindre Cenelis »** puis rattrapage personnalisé lacune par lacune jusqu'à **100 %**.
- **Progression, Points XP, Série Quotidienne, 12 Trophées & 5 Mini-Jeux Natifs** :
  1. *Swipe Éclair : Vrai ou Piège ?*
  2. *Duel des Connexions 3D*
  3. *Urgence au Poste !*
  4. *Œil d'Expert Interface `@2x`*
  5. *Séquences Maîtrisées*

---

## Ouverture & Compilation Xcode

1. Ouvrir `CenelisAcademy.xcodeproj` dans **Xcode 16+** (aucune dépendance SPM tierce requise).
2. Sélectionner votre équipe de signature Apple sur la cible `CenelisAcademy` (`com.cenelis.academy`).
3. Compiler et lancer sur simulateur ou iPhone / iPad sous **iOS 18.0+**.
