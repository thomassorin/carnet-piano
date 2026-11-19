# Piano Journal (iOS)

Carnet de pratique du piano : catalogue de partitions, recueils découpés en pièces à cocher et à noter, minuteur, métronome, historique, statistiques. Abonnement mensuel via l'App Store.

- SwiftUI + SwiftData, iOS 17 et plus, iPhone et iPad
- Aucune dépendance externe
- Français (langue source) et anglais

## Ouvrir et lancer

1. Ouvrir `ios/PianoJournal.xcodeproj` dans Xcode 16 ou plus récent.
2. Cible `PianoJournal` > Signing & Capabilities : choisir son équipe (Team).
3. Choisir un simulateur ou son iPhone, puis Run.

L'abonnement se teste sans compte App Store grâce à `Products.storekit` (déjà branché sur le schéma).

Pour voir l'app avec des données d'exemple : Product > Scheme > Edit Scheme > Arguments, ajouter `-seedDemo YES`.

## Organisation

| Dossier | Contenu |
| --- | --- |
| `PianoJournal/App` | Point d'entrée, `Config.swift` (prix, limite gratuite, adresses) |
| `PianoJournal/Models` | Données : `Score` (partition, recueil, pièce), `PracticeSession`, statistiques |
| `PianoJournal/Catalog` | Catalogue embarqué, recherche, sources en ligne, IA |
| `PianoJournal/Services` | Minuteur, métronome, abonnement StoreKit 2, rappel |
| `PianoJournal/Views` | Écrans |
| `PianoJournal/Resources` | `catalog.json`, `Localizable.xcstrings` |
| `tools/` | Scripts qui régénèrent le catalogue et les traductions |
| `backend/` | Service de recherche IA (Cloudflare Worker) |
| `docs/` | Politique de confidentialité |

## Le catalogue

Trois niveaux, du plus rapide au plus large :

1. **Catalogue embarqué** (`catalog.json`) : recueils, méthodes et morceaux les plus joués, avec le détail des pièces. Hors ligne, instantané. Pour l'enrichir : modifier `tools/build_catalog.py` puis lancer `python3 tools/build_catalog.py`.
2. **Catalogues en ligne**, sans clé : Open Opus (répertoire classique) et iTunes Search (albums et chansons, un album devenant un recueil avec ses titres).
3. **Recherche IA** (facultative) : retrouve un recueil rare et détaille son contenu. Désactivée tant que `Config.aiEndpoint` est vide.

Tout ce qui reste introuvable peut être créé à la main, avec des pièces saisies ligne par ligne ou une série numérotée.

### Activer la recherche IA

1. Créer un compte Cloudflare, puis un Worker, et y coller `backend/worker.js`.
2. Dans les réglages du Worker, ajouter deux secrets : `ANTHROPIC_API_KEY` (clé créée sur console.anthropic.com) et `APP_KEY` (un mot de passe au choix).
3. Dans `Config.swift`, renseigner `aiEndpoint` (adresse du Worker) et `aiAppKey` (la même valeur que `APP_KEY`).

La recherche IA est réservée aux abonnés et ne part que sur demande ; les réponses sont mises en cache.

## Publier sur l'App Store

1. Adhérer à l'Apple Developer Program (99 € par an).
2. App Store Connect > Apps > Nouvelle app : nom « Piano Journal », identifiant `com.thomassorin.pianojournal` (modifiable dans Xcode avant la première mise en ligne).
3. Abonnements : créer un groupe « Piano Journal Pro » et un abonnement d'un mois dont l'identifiant est exactement `pianojournal.pro.monthly`, au prix voulu, avec une semaine d'essai gratuit en offre de lancement si souhaité.
4. Remplir les contrats, coordonnées bancaires et informations fiscales (section Accords) : sans cela, l'abonnement ne s'affiche pas.
5. Xcode > Product > Archive > Distribute App, puis soumettre la version avec l'abonnement.
6. Fiche de l'app : captures d'écran, description, adresse de la politique de confidentialité (`docs/confidentialite.md`, à héberger sur une page publique).

## Compilation automatique

Chaque envoi sur la branche `ios-app` compile l'app sur macOS (GitHub Actions), la lance dans un simulateur et dépose le journal et des captures d'écran sur la branche `ci-logs`.
