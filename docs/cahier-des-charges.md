# WeatherWindow — Cahier des charges de développement (FIT3178 P9)

Oct 2, 2026 · @Clement

## 1. Vue d'ensemble

WeatherWindow choisit **l'ordre** et **l'heure de départ** de 3 ou 4 courses à pied pour que les trajets entre elles soient les plus secs possible, en respectant les horaires d'ouverture et la durée de chaque tâche.

**Analogie.** Un GPS te dit par où passer. Une appli météo te dit s'il pleut là où tu es. WeatherWindow joue le rôle d'un ami qui regarde le radar et te dit : « fais la poste d'abord, et pars dans 15 minutes ».

**Exemple concret (celui du HD1).** À 14:10, tu sors du supermarché pour 12 min de marche vers la bibliothèque. La prévision dit « 60 % de pluie entre 14 h et 15 h » : inutile. Le radar montre une bande de pluie à 4 km à l'ouest, à 30 km/h. Elle touche ton trajet vers 14:18. Partir maintenant = \~4 min sous la pluie. Attendre 20 min = trajet sec.

### Les trois briques

- **Solveur (P6)** : teste tous les ordres × toutes les heures de départ, simule la journée (attente si fermé, rejet si fini après fermeture), mesure la pluie traversée minute par minute.
- **Prévision horaire (Open-Meteo)** : sert au-delà d'une heure.
- **Route Nowcast (HD1, Wow Factor)** : images radar passées → mouvement de la pluie → extrapolation sur 30 min → croisée avec ta position prévue à chaque minute.

### Ce que le P9 va vérifier

| Critère P9 | Ce que ça impose concrètement |
| --- | --- |
| Fonctionnalités clés du P6 | Le MVP du P6 et le Route Nowcast du HD1 tournent en démo, de bout en bout |
| Interface utilisable et cohérente | Navigation standard, états vides et d'erreur, Dynamic Type, mode sombre |
| Pratiques iOS appropriées | SwiftUI + `@Observable`, SwiftData, async/await, Swift 6 (section 5) |
| Erreurs et cas inattendus | Aucun crash : réseau coupé, aucun planning valide, radar indisponible |
| Compréhension en discussion | Tu expliques chaque fichier toi-même, sans commentaires verbeux |
| Ressources externes citées | Page À propos : nom, ID 37465848, RainViewer, Open-Meteo, Apple Maps, articles, usage de l'IA |

**Dates fixes :** fin des cours le 23 oct., démo en semaine 14/15, soit entre le 2 et le 13 nov. 2026 (période d'examens Monash : 2–18 nov.).

## 2. Améliorations par rapport au P6 et au HD1

Le concept tient la route ; le vrai risque est le **temps Mac**. Il reste **3 mercredis garantis** avant la fin des cours (7, 14 et 21 oct.), peut-être 2 de plus (28 oct. et 4 nov.) si le lab est ouvert. Le HD1 à lui seul prévoyait 4 sessions Mac, sans compter le MVP du P6. D'où huit changements.

**1. Un périmètre en 4 niveaux, livrés dans l'ordre.** On ne commence un niveau que si le précédent tourne dans le simulateur.

| Niveau | Contenu | Rôle pour la note |
| --- | --- | --- |
| A — Indispensable | Bibliothèque de courses, recherche de lieux MapKit, assemblage de la journée, matrice de temps de marche + cache, prévision horaire, solveur, liste classée, page À propos, gestion d'erreurs | Le MVP promis au P6 : sans lui, rien d'autre ne compte |
| B — Attendu | Score robuste (décalages temporels), courbe de compromis Swift Charts, carte teintée par trajet, notification de départ | Les frameworks « en plus » du P6 |
| C — Wow Factor | Route Nowcast tel que défini dans le MVP du HD1 : radar live + rejeu, block matching, horizon 30 min, conseil « partir ou attendre », collision view avec curseur temporel, vérification dans les tests | Ce qui justifie le HD |
| D — Bonus | Ensemble Open-Meteo, Vision, horizon 60 min, écran de vérification, alerte nowcast, saisie en langage naturel, préférence apprise | Seulement s'il reste du temps |

**2. Tout ce qui n'est pas de l'interface vit dans un package Swift qui compile sous Linux.** Pas seulement le solveur et le nowcast : le décodage JSON d'Open-Meteo et de RainViewer aussi. *Analogie : le moteur se construit et se teste au garage (Linux) ; le mercredi, on ne fait que le monter dans la carrosserie (Xcode).*

**3. Une seule « prise » pour la pluie : le protocole `RainField`.** Prévision horaire, nowcast, mélange des deux, prévision décalée de 15 min, membre d'ensemble : tous répondent à la même question, « quel poids de pluie ici, à cette minute ? ». Le solveur ne sait pas qui lui répond. *Comme une prise électrique standard : on branche ce qu'on veut sans recabler la maison.* Le score robuste devient simplement le pire résultat sur une liste de `RainField`.

**4. Le solveur évalue les trajets en ligne droite, pas avec les polylignes MapKit.** Un pixel radar fait \~480 m à Melbourne. Pour une marche de 1,5 km, l'écart entre le vrai chemin et la ligne droite tient souvent dans un pixel. Tu économises \~30 appels `MKDirections.calculate` et tout reste testable sous Linux. Les vraies polylignes servent seulement à l'affichage du planning choisi.

**5. Robustesse : d'abord des décalages temporels, l'ensemble ensuite.** Scénarios −30, −15, 0, +15, +30 min : c'est exactement ce que décrit le texte du P6, et c'est du pur Swift. L'API d'ensemble passe en bonus (niveau D), côté Linux uniquement.

**6. Une seule horloge : `Date` partout.** Open-Meteo accepte `timeformat=unixtime` (horodatages UTC en secondes) : plus de chaînes en heure locale à parser. Le fuseau `Australia/Melbourne` ne sert qu'à l'affichage et aux horaires d'ouverture. Cela règle le problème des « trois horloges » du HD1.

**7. Fixtures radar décodées en Python, testées en Swift sous Linux.** Core Graphics n'existe pas sous Linux. Un script Python convertit chaque PNG en grille d'intensités binaire ; les tests Swift lisent ces grilles. Un seul test iOS vérifie que le décodeur Core Graphics donne la même grille. **L'enregistrement doit tourner dès ce week-end** : sans jours de pluie enregistrés, pas de rejeu en démo.

**8. Un plan B pour la collision view.** Si le pont `MKMapView` n'est pas fini, un `Canvas` SwiftUI dessine la grille de pluie, le trajet et ton marqueur avec le même curseur et les mêmes données. Moins joli, mais la démo du Wow Factor reste possible.

**À valider avec Jason à sa prochaine consultation :** que le P9 est jugé sur le MVP du P6 + le Route Nowcast du HD1 (et non sur toute la liste du P6), et si les Mac du lab sont accessibles pendant la SWOT vac et la période d'examens.

## 3. Règles de travail : Linux la semaine, Mac le mercredi

Règle d'or : **zéro minute de Mac pour ce qui tourne sous Linux.** Le mercredi sert à compiler, brancher et tester dans le simulateur, pas à écrire de la logique.

### Avant chaque mercredi (Linux)

- [ ] `swift test` est vert dans `WeatherWindowKit`.
- [ ] Les fichiers SwiftUI de la session sont déjà écrits (non compilés, donc courts et simples).
- [ ] Une checklist de session de 5 à 8 points, dans l'ordre, avec « terminé quand » pour chacun.
- [ ] Les questions pour Jason sont notées.

### Pendant la session (Mac du lab)

- [ ] `git pull`, puis build immédiat : corriger les erreurs des fichiers écrits sous Linux en premier.
- [ ] Commit + push **toutes les heures** ; ne jamais laisser du travail seulement sur le Mac du lab.
- [ ] Fin de session : tag `mac-1`, `mac-2`… et une note de 3 lignes dans `README.md` (fait / cassé / suivant).

### Réglages qui rendent ce fonctionnement possible

- **Même version de Swift des deux côtés.** Au premier mercredi, note la version d'Xcode (menu Xcode ▸ About Xcode) et installe la même version de Swift sous Linux avec `swiftly`. Sinon, du code valide chez toi peut casser au lab.
- **Dossiers synchronisés d'Xcode** (dossiers bleus, par défaut dans les projets récents) : un fichier `.swift` créé sous Linux dans le dossier de l'app est pris en compte au build suivant, sans toucher au projet. Ne jamais modifier `project.pbxproj` à la main.
- **Simulateur sans iPhone :** position simulée via Features ▸ Location ▸ Custom Location (Melbourne CBD : −37.8136, 144.9631). Les notifications et MapKit fonctionnent dans le simulateur ; la saisie en langage naturel (Foundation Models) dépend d'Apple Intelligence sur le Mac hôte, d'où son passage en bonus.

### IA générative et entretien

Le sujet autorise l'IA pour développer, mais tu dois pouvoir expliquer et modifier chaque partie en démo, sans IA ni commentaires verbeux. Test personnel avant de committer un fichier : *peux-tu l'expliquer à voix haute en 30 secondes ?*

### Le dépôt

Les labs restent dans `Labs/` tels quels ; l'app les réutilise par motif (section 4). Le lien soumis sur OnTrack pointe vers ce dépôt ; le `README.md` racine sert de carte pour le correcteur.

## 4. Architecture et organisation du repo

Deux mondes : un **package `WeatherWindowKit`** (pur Swift + Foundation, compilé et testé sous Linux) et une **app iOS** fine qui ne fait que récupérer, stocker, afficher et notifier.

&#91;embedded content: Architecture · 3 couches, 4 modules Linux\]

ForecastKit et NowcastKit fournissent chacun un `RainField` ; SolverKit ne connaît que ce protocole, d'où l'ajout du nowcast sans toucher au solveur.

### Arborescence

```text
FIT3178/                          ← racine du dépôt soumis sur OnTrack
├── README.md                     ← carte du repo, build, crédits, notes de session
├── Labs/                         ← labs 1 à 6, inchangés
├── WeatherWindowKit/             ← package local, Linux + iOS
│   ├── Package.swift
│   ├── Sources/
│   │   ├── WeatherWindowCore/    ← GeoPoint, TimeWindow, RainField, DateProvider
│   │   ├── ForecastKit/          ← DTO Open-Meteo et RainViewer, HourlyRainField
│   │   ├── SolverKit/            ← simulation, score robuste, front de Pareto
│   │   └── NowcastKit/           ← RainGrid, géoréférence, mouvement, advection, vérification
│   └── Tests/                    ← un dossier de tests par module + Fixtures/
├── WeatherWindow/                ← projet Xcode (Mac uniquement)
│   ├── WeatherWindow.xcodeproj
│   ├── WeatherWindow/            ← dossier synchronisé
│   │   ├── App/                  ← WeatherWindowApp, injection des dépendances
│   │   ├── Models/               ← classes @Model SwiftData
│   │   ├── Services/             ← OpenMeteo, Directions, PlaceSearch, Radar, Location, Notification
│   │   ├── Features/             ← Errands, DayPlan, Results, Nowcast, About (vue + view model)
│   │   ├── Shared/               ← erreurs, formateurs, petits composants
│   │   └── Resources/            ← Assets, session radar enregistrée pour le rejeu
│   └── WeatherWindowTests/       ← tests propres à iOS (décodeur PNG, SwiftData)
└── Tools/
    ├── record_radar.py           ← enregistre les images radar (cron)
    └── decode_tiles.py           ← PNG → grilles binaires pour les tests Linux
```

### `Package.swift` de départ

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherWindowKit",
    platforms: [.iOS(.v18), .macOS(.v15)],   // ignoré sous Linux
    products: [
        .library(name: "WeatherWindowKit",
                 targets: ["WeatherWindowCore", "ForecastKit", "SolverKit", "NowcastKit"])
    ],
    targets: [
        .target(name: "WeatherWindowCore"),
        .target(name: "ForecastKit", dependencies: ["WeatherWindowCore"]),
        .target(name: "SolverKit", dependencies: ["WeatherWindowCore"]),
        .target(name: "NowcastKit", dependencies: ["WeatherWindowCore"]),
        .testTarget(name: "SolverKitTests", dependencies: ["SolverKit"]),
        .testTarget(name: "ForecastKitTests", dependencies: ["ForecastKit"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "NowcastKitTests", dependencies: ["NowcastKit"],
                    resources: [.copy("Fixtures")])
    ]
)
```

Trois interdits dans le package, sinon il ne compile plus sous Linux : `import CoreLocation` (→ ton propre `GeoPoint`), `import MapKit` (→ Mercator recodé dans `Georeference`), `import CoreGraphics` (→ `RainGrid` = tableau de `Float`). Pas d'isolation `MainActor` par défaut dans le package : le moteur doit pouvoir tourner hors du thread principal.

### Réutilisation des labs

| Motif vu en lab | Où il revient dans WeatherWindow |
| --- | --- |
| `List`, `Form`, navigation SwiftUI | Bibliothèque de courses, formulaire d'ajout, assemblage de la journée |
| SwiftData (`@Model`, `@Query`, `ModelContext`) | `SavedErrand`, `DayPlan`, `PlannedStop`, `TransitMatrixCache` |
| `URLSession` + `Decodable` + async/await | Clients Open-Meteo et RainViewer |
| View model `@Observable` | Un view model par écran dans `Features/` |

Indique dans le `README.md` quel lab correspond à chaque ligne : c'est une preuve facile de continuité pour le correcteur.

## 5. Règles Apple à respecter

Chaque ligne ci-dessous est une règle de la documentation Apple ou de swift.org, avec l'endroit exact où elle s'applique dans l'app. En démo, savoir dire *pourquoi* tu as suivi la règle compte autant que l'avoir suivie.

| Domaine | Règle | Exemple dans WeatherWindow |
| --- | --- | --- |
| Nommage | Swift API Design Guidelines : clarté au point d'usage, types en `UpperCamelCase`, le reste en `lowerCamelCase`, booléens en `is`/`has`, appels qui se lisent comme une phrase | `solver.rankSchedules(for: request)` plutôt que `solver.run(r)` ; `errand.isOpen(at: time)` |
| Documentation | Un commentaire `///` d'une phrase sur chaque déclaration publique ; pas de pavés | `/// Rain weight in 0...1 at a place and time.` |
| Concurrence | Swift 6. Projet Xcode 26 : isolation par défaut `MainActor` + Approachable Concurrency (réglages par défaut). Le travail lourd sort explicitement du thread principal avec `@concurrent` ou un `actor` | `NowcastService` est un `actor` ; le classement des plannings passe par une fonction `@concurrent` |
| Données partagées | Ce qui traverse les acteurs est `Sendable` : des `struct` immuables, jamais un objet `@Model` | Le solveur reçoit un `PlanRequest` (struct), pas un `DayPlan` |
| État SwiftUI | `@Observable` + `@State` pour posséder, `@Bindable` pour éditer, `@Environment` pour injecter ; pas de nouveau `ObservableObject`. Rien de coûteux dans `body` | `DayPlanViewModel` est `@Observable`, créé en `@State` par sa vue |
| Navigation | `TabView` pour les sections principales, `NavigationStack` + `navigationDestination(for:)` dans chaque onglet | Onglets : Planifier, Courses, À propos |
| SwiftData | `.modelContainer(for:)` à la racine, `@Query` dans les vues, règle de suppression explicite (`@Relationship(deleteRule: .cascade)`) | `DayPlan` possède ses `PlannedStop` en cascade |
| Réseau | `async`/`await` avec `URLSession`, contrôle du code HTTP, erreurs typées conformes à `LocalizedError`, annulation via le modificateur `.task` | `ServiceError.httpStatus(503)` → message « Service météo indisponible, réessaie dans une minute » |
| Accessibilité (HIG) | Dynamic Type (polices sémantiques), libellés VoiceOver, cibles ≥ 44 × 44 pt, **jamais l'information par la couleur seule** | Trajet pluvieux = couleur **+** pointillé **+** texte « \~4 min sous la pluie » |
| Apparence | Couleurs sémantiques et SF Symbols pour le mode sombre gratuit | `Color.primary`, `Image(systemName: "cloud.rain")` |
| Vie privée | Chaîne `NSLocationWhenInUseUsageDescription` claire ; permissions demandées au moment où elles servent, pas au lancement | Notification demandée au premier appui sur « Me rappeler » |
| Tests | Swift Testing (`import Testing`, `@Test`, `#expect`) ; tourne sous Linux et dans Xcode | Tous les tests du package |
| Journalisation | `Logger` (OSLog) dans l'app, pas `print` | `Logger(subsystem: "…WeatherWindow", category: "radar")` |
| Attributions | Ne jamais masquer l'attribution de la carte Apple ; afficher les crédits des données | « Radar : RainViewer » sur la carte, Open-Meteo (CC BY 4.0) visible |

### Le motif de concurrence à retenir

Avec l'isolation `MainActor` par défaut, tout le code de l'app tourne sur le thread principal sauf si tu dis le contraire. *Analogie : un restaurant où le serveur (thread principal) prend les commandes ; on ne lui demande pas de cuisiner, on envoie la commande en cuisine (`@concurrent`) et il revient avec l'assiette.*

```swift
@Observable
final class DayPlanViewModel {
    private(set) var schedules: [ScoredSchedule] = []

    func solve(_ request: PlanRequest, scenarios: [any RainField]) async {
        schedules = await Self.rank(request, scenarios)   // revient sur le MainActor
    }

    @concurrent
    private static func rank(_ request: PlanRequest,
                             _ scenarios: [any RainField]) async -> [ScoredSchedule] {
        ScheduleSolver().rankSchedules(for: request, scenarios: scenarios)  // hors MainActor
    }
}
```

Vérifie au premier mercredi, dans Build Settings ▸ Swift Compiler – Concurrency, que *Default Actor Isolation* vaut `MainActor` et *Approachable Concurrency* vaut `Yes` ([réglages par défaut d'Xcode 26](https://useyourloaf.com/blog/approachable-concurrency-in-swift-packages/)).

## 6. Étape 0 — Mise en place et faisabilité

**But :** un repo propre, un package qui passe `swift test`, l'enregistrement radar qui tourne, et les deux paris techniques tranchés dès le premier mercredi.

### Sous Linux (d'ici mardi 6 oct.)

- [ ] Réorganiser le dépôt selon l'arborescence de la section 4 ; `README.md` minimal.
- [ ] Créer `WeatherWindowKit` (`swift package init --type library`), puis les 4 cibles ; un test trivial passe.
- [ ] Écrire `Tools/record_radar.py` et le lancer en cron **toutes les 30 min**. L'API garde 2 h d'historique, donc aucune image n'est perdue même si ton PC dort un peu.
- [ ] Écrire `Tools/decode_tiles.py` (Pillow) : PNG → grille 512 × 512 de `Float32` en dBZ, fichier `.bin` + `.json` (horodatage, tuile).
- [ ] Calculer à la main deux plannings de référence (déjà prévu au P6) : ils deviendront les premiers tests du solveur.

### Ce que fait `record_radar.py`

1. Lire `https://api.rainviewer.com/public/weather-maps.json` → `host` + liste `radar.past` (`time`, `path`).
2. Pour chaque frame absente du disque, télécharger `{host}{path}/512/7/115/78/2/0_0.png` : taille 512, zoom 7, tuile x = 115, y = 78 (Melbourne), schéma 2 (Universal Blue), sans lissage ni neige.
3. Ranger dans `recordings/AAAA-MM-JJ/<time>.png` et noter l'heure de téléchargement (pour mesurer le retard des données).

Limite RainViewer : 100 requêtes par minute et par IP ; un passage complet en fait 14 au maximum.

**Table de couleurs :** RainViewer publie la correspondance dBZ → RGBA du schéma Universal Blue en [CSV téléchargeable](https://www.rainviewer.com/api/color-schemes.html). Copie ce fichier dans `Tests/Fixtures/` et dans les ressources de l'app : c'est la source unique de la palette pour Python **et** Swift.

### Au lab (mercredi 7 oct.) — Mac n° 1

- [ ] Noter : version d'Xcode, du SDK iOS et des simulateurs disponibles. Ajuster Swift sous Linux le soir même.
- [ ] Créer le projet : iOS App, Interface SwiftUI, Storage *None* (SwiftData ajouté à la main, pour pouvoir l'expliquer), Testing System *Swift Testing*. Cible de déploiement iOS 18.
- [ ] Vérifier les réglages de concurrence (section 5) et ajouter le package local (File ▸ Add Package Dependencies ▸ Add Local…).
- [ ] Ajouter `NSLocationWhenInUseUsageDescription` dans les réglages Info de la cible.
- [ ] **Go/no-go n° 1 :** décoder une tuile PNG avec Core Graphics et comparer à la grille Python (écart max 0 dBZ hors bords).
- [ ] **Go/no-go n° 2 :** `VNGenerateOpticalFlowRequest` dans le simulateur, **15 min maximum**. Si ça ne tourne pas : abandon définitif, le block matching suffit.
- [ ] Puis enchaîner sur la partie Mac de l'étape 2 (modèles SwiftData).
- [ ] Push + tag `mac-1`.

**Terminé quand :** le projet vide compile avec le package, les deux go/no-go sont notés dans le `README.md`, et au moins une journée de radar est enregistrée.

## 7. Étape 1 — SolverKit (Linux)

**But :** à partir d'une liste d'arrêts, d'une matrice de temps de marche et d'une liste de scénarios de pluie, renvoyer le front de Pareto des plannings, ou la raison pour laquelle aucun n'est possible. Aucun réseau, aucune UI.

### Types de base (`WeatherWindowCore`)

```swift
public struct GeoPoint: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double
}

/// Rain weight in 0...1 at a place and time.
public protocol RainField: Sendable {
    func weight(at point: GeoPoint, time: Date) -> Double
}

/// Source of "now", injectable for tests and replay.
public protocol DateProvider: Sendable {
    var now: Date { get }
}
```

### Types du solveur (`SolverKit`) — signatures à respecter

```swift
public enum Node: Hashable, Sendable { case start, end, stop(UUID) }

public struct Stop: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var location: GeoPoint
    public var serviceDuration: TimeInterval
    public var openingMinute: Int        // minutes depuis minuit, heure de Melbourne
    public var closingMinute: Int
}

public struct PlanRequest: Sendable {
    public var start: GeoPoint
    public var end: GeoPoint
    public var stops: [Stop]
    public var departureWindow: ClosedRange<Date>
    public var departureStep: TimeInterval   // 5 min
    public var walkingTimes: [Node: [Node: TimeInterval]]
    public var timeZone: TimeZone
}

public enum SolveOutcome: Sendable {
    case frontier([ScoredSchedule])          // trié par heure de fin
    case infeasible(InfeasibilityReason)     // ex. .closesTooEarly(stopName: "Poste")
}

public struct ScheduleSolver: Sendable {
    public func rankSchedules(for request: PlanRequest,
                              scenarios: [any RainField]) -> SolveOutcome
}
```

### L'algorithme en 6 temps

1. **Ordres** : toutes les permutations des arrêts (4 arrêts → 24 ordres).
2. **Départs** : chaque heure de la fenêtre, par pas de 5 min (fenêtre de 2 h → 25 départs).
3. **Simulation** de la journée, arrêt par arrêt (formules ci-dessous).
4. **Échantillonnage** : chaque trajet devient un point par minute, en ligne droite de A vers B, horodaté au milieu de la minute.
5. **Score** : exposition = somme des poids de pluie des échantillons ; score robuste = pire scénario.
6. **Pareto** : on garde les plannings qu'aucun autre ne bat sur les deux axes.

Ordre de grandeur : 24 × 25 × 5 scénarios = 3 000 évaluations, instantané sur un iPhone.

```latex
\text{serviceStart}_i = \max(\text{arrival}_i,\ \text{opening}_i) \qquad \text{waiting}_i = \text{serviceStart}_i - \text{arrival}_i
```

```latex
\text{departure}_i = \text{serviceStart}_i + \text{duration}_i \qquad \text{rejet si } \text{departure}_i > \text{closing}_i
```

```latex
E_f(S) = \sum_{s \in S} w_f(p_s, t_s) \times 1\,\text{min} \qquad R(S) = \max_{f \in \text{scénarios}} E_f(S)
```

**Précision qui manquait au P6 : l'axe du temps.** Mesure la durée depuis le **début de ta fenêtre** jusqu'au retour, pas depuis le départ effectif. Sinon « partir 20 min plus tard » ne coûte rien sur le graphe et le compromis disparaît.

**Pareto, par analogie :** en choisissant un vol, tu n'achètes jamais un billet à la fois plus cher *et* plus long qu'un autre. Les vols restants forment le front ; à toi de choisir entre « rapide » et « pas cher ». Ici : « rapide » et « sec ».

**Scénarios de départ :** la prévision telle quelle, puis décalée de −30, −15, +15 et +30 min. Un `ShiftedRainField(base:offset:)` répond `base.weight(at: p, time: t - offset)`.

### Tests à écrire d'abord (Swift Testing)

| Test | Situation | Résultat attendu |
| --- | --- | --- |
| `waitsWhenArrivingBeforeOpening` | Arrivée 13:50, ouverture 14:00 | Attente 10 min, début 14:00 |
| `rejectsTaskEndingAfterClosing` | Arrivée 16:40, tâche de 30 min, fermeture 17:00 | Planning rejeté |
| `splitsLegAcrossHourBoundary` | Trajet de 25 min parti à 14:50 | 10 échantillons dans 14 h, 15 dans 15 h |
| `enumeratesAllOrders` | 4 arrêts | 24 ordres |
| `dryForecastGivesZeroExposure` | Poids de pluie nul partout | Exposition 0 |
| `robustScoreIsWorstScenario` | 3 scénarios d'expositions 1, 3, 2 | Score robuste 3 |
| `paretoDropsDominated` | (50 min ; 2,0), (55 ; 1,0), (60 ; 1,5) | Garde les deux premiers |
| `reportsWhyNothingFits` | Poste fermant avant toute arrivée possible | `.infeasible(.closesTooEarly)` |
| `handComputedCaseA`, `…B` | Tes deux cas papier de l'étape 0 | Valeurs calculées à la main |

**Terminé quand :** tous ces tests passent sous Linux avec `swift test`.

**À savoir dire en démo (30 s) :** « Je teste tous les ordres et toutes les heures de départ, je simule la journée avec attente et fermeture, je découpe chaque trajet en minutes et je somme la pluie. Je garde seulement les plannings qu'aucun autre ne bat à la fois en temps et en pluie. »

## 8. Étape 2 — Services réseau et persistance

**But :** obtenir de vraies données (prévision, temps de marche, lieux) et les garder entre deux lancements. Le décodage se fait sous Linux ; les appels réels et SwiftData au lab.

### Sous Linux : `ForecastKit`

- [ ] Enregistrer de vraies réponses avec `curl` dans `Tests/Fixtures/` : `hourly_melbourne.json` et `weather_maps.json`.
- [ ] `OpenMeteoHourlyResponse: Decodable` avec un `init(from:)` écrit à la main qui « zippe » les tableaux parallèles `time`, `precipitation_probability`, `precipitation` en `[WeatherSample]`. Valeurs `null` tolérées ; longueurs différentes → `DecodingError.dataCorrupted`.
- [ ] Construire l'URL avec `URLComponents`, jamais par concaténation de chaînes.
- [ ] `HourlyRainField: RainField` : cherche l'heure qui contient `time` et ignore la position (prévision au centroïde, limite à afficher dans l'UI).
- [ ] `RainViewerMaps: Decodable` (`host`, `radar.past[].time`, `radar.past[].path`) + une fonction qui fabrique l'URL de tuile.

Requête Open-Meteo de référence :

```text
https://api.open-meteo.com/v1/forecast?latitude=-37.81&longitude=144.96
    &hourly=precipitation_probability,precipitation&timeformat=unixtime&forecast_days=2
```

**Poids de pluie horaire (choix à justifier en démo) :**

```latex
w = \frac{p}{100} \times \min\left(1,\ \frac{P}{1\ \text{mm/h}}\right)
```

où *p* est la probabilité (%) et *P* la précipitation prévue. Idée : 1 mm/h suffit à mouiller un piéton, au-delà « plus mouillé » ne change pas la décision. Exemple : 60 % et 0,5 mm → w = 0,3.

| Test | Attendu |
| --- | --- |
| `decodesHourlyFixture` | 48 échantillons, premier horodatage = celui du fichier |
| `toleratesNullValues` | Un `null` devient 0, pas un crash |
| `rejectsMismatchedArrays` | Erreur de décodage explicite |
| `rainWeightExamples` | (60 % ; 0,5 mm) → 0,3 ; (100 % ; 3 mm) → 1 ; (0 % ; 2 mm) → 0 |
| `buildsTileURL` | `…/512/7/115/78/2/0_0.png` exactement |

### Au lab : modèles SwiftData

SwiftData ne stocke pas `CLLocationCoordinate2D` : on garde deux `Double` et une propriété calculée (non persistée) qui renvoie un `GeoPoint`.

| Modèle | Contenu | Règle importante |
| --- | --- | --- |
| `SavedErrand` | Nom, nom normalisé (minuscules), latitude, longitude, durée par défaut, ouverture et fermeture en minutes | Doublon détecté sur le nom normalisé avant insertion |
| `DayPlan` | Date, départ, arrivée optionnelle, fenêtre de départ, planning choisi | `@Relationship(deleteRule: .cascade)` vers ses arrêts |
| `PlannedStop` | **Copie** des valeurs du jour (nom, position, durée, horaires, rang, heures d'arrivée et de départ) + lien optionnel vers le `SavedErrand` | Modifier ou supprimer une course ne réécrit pas l'historique |
| `TransitMatrixCache` | Clé unique, matrice encodée en `Data`, date de création | Valable 7 jours ; la clé change si un lieu, le mode ou la version de schéma change |

`ErrandStore` (sur le `MainActor`) possède le `ModelContext` et renvoie un résultat typé : `enum AddErrandResult { case added, duplicateName, failed(Error) }`. L'interface peut alors dire « tu as déjà une course "Coles" » au lieu d'un message générique.

### Au lab : services

| Service | API Apple | Point d'attention |
| --- | --- | --- |
| `OpenMeteoService` | `URLSession.shared.data(from:)` | Contrôle du code HTTP ; erreurs `ServiceError: LocalizedError` (hors ligne, délai, réponse invalide, statut HTTP, limitation) |
| `PlaceSearchService` | `MKLocalSearchCompleter` puis `MKLocalSearch` | Région centrée sur Melbourne ; le choix d'une suggestion donne un nom + un `GeoPoint` |
| `DirectionsService` | `MKDirections.calculateETA()` en mode `.walking` | 4 arrêts + départ + arrivée = **20 requêtes** ; 3 au maximum en parallèle (`TaskGroup`) ; sur `MKError.loadingThrottled`, attendre puis réessayer deux fois |
| `LocationService` | `CLLocationManager`, autorisation *when in use* | Chaque état d'autorisation géré ; refus → départ choisi à la main |

MapKit suppose une allure fixe. Ajoute un **facteur d'allure** (0,8× à 1,3×) dans les réglages, appliqué à la matrice : sinon chaque horodatage de la journée dérive pour qui marche plus vite ou plus lentement.

**Terminé quand :** un écran de debug affiche la matrice des 20 temps de marche pour 4 vrais lieux et la prévision 48 h ; au relancement, la matrice vient du cache sans réseau.

## 9. Étape 3 — Interface MVP

**But :** la boucle complète dans le simulateur. Je crée mes courses, je compose ma journée, j'appuie sur « Calculer », je vois des plannings classés avec de vraies données. C'est le jalon **MVP** du P6.

### Structure

`TabView` à trois onglets, chacun avec sa `NavigationStack` : **Planifier**, **Courses**, **À propos** (qui contient aussi les réglages : facteur d'allure, mode rejeu).

### Écrans

| Écran | Contenu | Validation et cas limites |
| --- | --- | --- |
| Courses (`ErrandListView`) | `List` + `.searchable` + suppression par balayage (`.onDelete`) + bouton « + » | Bibliothèque vide → `ContentUnavailableView` « Ajoute la poste, le supermarché… » |
| Ajout d'une course (`ErrandFormView`, en feuille) | `Form` : nom, lieu (vers la recherche), durée (`Stepper`, 5–120 min par pas de 5), ouverture et fermeture (`DatePicker` heure seule) | Enregistrer désactivé tant que : nom vide, lieu absent, fermeture ≤ ouverture, durée > amplitude d'ouverture. Message sous le champ fautif |
| Recherche de lieu (`PlaceSearchView`) | Champ + suggestions en direct | Aucun résultat, ou réseau coupé → message dans la liste, pas d'alerte |
| Planifier (`DayPlanView`) | 1 à 4 courses cochées ; départ (position actuelle ou lieu) ; arrivée (retour au départ par défaut) ; fenêtre de départ (par défaut maintenant → +2 h) ; bouton « Calculer » | Au-delà de 4 courses : refus expliqué ; localisation refusée → bascule sur « Choisir un lieu » |
| Résultats (`ResultsView`) | Deux cartes « Le plus rapide » et « Le plus sec », puis la liste du front : départ, retour, exposition | Aucun planning possible → `ContentUnavailableView` avec la raison (« La poste ferme à 17:00 : impossible d'y être à temps ») |
| Itinéraire (`ItineraryView`) | Arrêts dans l'ordre : arrivée, attente, départ ; chaque trajet « sec » ou « \~3 min de pluie » ; bouton « Enregistrer ce plan » | Bandeau d'honnêteté : « Prévision horaire au centre de tes courses » |

### Le motif d'état à utiliser dans chaque view model

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(ServiceError)
}
```

La vue fait un `switch` sur cet état : `ProgressView` pendant le chargement, contenu une fois chargé, message d'erreur avec bouton « Réessayer » en cas d'échec. *Analogie : un feu tricolore. La vue ne devine jamais où on en est, elle lit la couleur du feu.* C'est aussi ce qui rend la gestion d'erreurs visible au correcteur.

### Enchaînement de « Calculer »

1. Lire la matrice dans le cache, sinon la demander à `DirectionsService` (puis la mettre en cache).
2. Récupérer la prévision horaire pour le centroïde des arrêts.
3. Construire le `PlanRequest` (structs uniquement) et les 5 scénarios.
4. Appeler le solveur via la fonction `@concurrent` (section 5).
5. Passer l'état à `.loaded(outcome)` sur le `MainActor`.

**Terminé quand :** avec la position simulée à Melbourne et 3 vrais lieux, la boucle complète fonctionne, et un relancement retrouve courses et plans enregistrés. Tag `mvp`.

## 10. Étape 4 — Courbe de compromis, carte teintée, notification

**But :** rendre le résultat du solveur lisible d'un coup d'œil et actionnable. Le score robuste est déjà dans le solveur (étape 1) ; ici on le montre.

**Pourquoi « au pire » plutôt qu'« en moyenne » :** pour un rendez-vous, tu prends le train de 8:10 plutôt que celui de 8:25, parce que le premier marche même si ton bus a du retard. Un planning robuste est celui qui reste bon si la pluie arrive 15 min plus tôt ou plus tard que prévu.

### Courbe de compromis (Swift Charts)

- [ ] `Chart` de `PointMark` : axe x = durée jusqu'au retour (min), axe y = exposition au pire.
- [ ] Sélection au toucher avec `chartOverlay` + `ChartProxy` : on convertit la position du doigt en valeurs, on prend le point le plus proche en 2D.
- [ ] Point choisi : symbole plus gros + annotation « Départ 14:25 » ; la liste et la carte en dessous se mettent à jour.
- [ ] Accessibilité : chaque point a un libellé VoiceOver (« Départ 14 h 25, retour 15 h 40, exposition 0,8 »). La liste du front reste disponible comme alternative au graphe.

### Carte de l'itinéraire (MapKit pour SwiftUI)

- [ ] Vraies polylignes avec `MKDirections.calculate()`, **seulement pour le planning choisi** (5 requêtes au plus).
- [ ] Chaque trajet est rééchantillonné par minute puis coupé en sous-polylignes là où la condition change : un trajet qui commence au sec et finit sous la pluie change de style en cours de route.
- [ ] `Map { MapPolyline(…).stroke(…) }` : trajet sec = trait plein ; trajet pluvieux = couleur d'alerte **et** pointillé (`StrokeStyle(dash: [6, 4])`). Un `Marker` numéroté par arrêt.

### Notification de départ (UserNotifications)

- [ ] Demande d'autorisation au premier appui sur « Me rappeler », jamais au lancement.
- [ ] `UNCalendarNotificationTrigger` à l'heure de départ recommandée ; identifiant = identifiant du plan, pour remplacer un rappel existant au lieu d'en empiler deux.
- [ ] Refus → explication + bouton vers les Réglages (`UIApplication.openSettingsURLString`).

**Terminé quand :** toucher un point du graphe met à jour liste et carte, un trajet pluvieux est identifiable sans voir les couleurs, et la notification s'affiche dans le simulateur.

**À savoir dire en démo :** « Je ne choisis pas à ta place entre vite et sec : je te montre les plannings qu'aucun autre ne bat, et tu choisis le compromis sur le graphe. »

## 11. Étape 5 — NowcastKit (Linux)

**But :** à partir des dernières images radar, produire une grille de pluie prévue pour chaque minute des 30 prochaines, et la brancher sur le solveur comme un `RainField`. Tout se développe et se teste sous Linux, sur grilles synthétiques puis sur tes enregistrements.

### Le pipeline en 6 composants

1. **`RainGrid`** : 512 × 512 `Float` en dBZ, la tuile (z 7, x 115, y 78) et l'heure de l'image. Lecture bilinéaire en coordonnées non entières.
2. **`Georeference`** : pixel de tuile ↔ `GeoPoint` en Mercator sphérique (formules ci-dessous). 1 pixel ≈ 480 m à Melbourne.
3. **`BlockMatchingEstimator`** : champ de mouvement entre deux images.
4. **`Advector`** : extrapolation semi-lagrangienne, une grille par minute jusqu'à 30 min.
5. **`NowcastRainField: RainField`** : répond au solveur, mélangé avec la prévision horaire selon l'échéance.
6. **`Verifier`** : note les prédictions passées quand l'image réelle arrive.

Plus `RadarFrameSource` (protocole) avec `RecordedSource` pour le rejeu, et un `DateProvider` fixe pour que « maintenant » soit l'heure enregistrée.

### Géoréférence

```latex
X = \frac{\lambda + 180}{360} \cdot 2^{z} \cdot 512 \qquad Y = \frac{1 - \ln\left(\tan\varphi + \sec\varphi\right)/\pi}{2} \cdot 2^{z} \cdot 512
```

Pixel dans la tuile = X − 115 × 512 et Y − 78 × 512. Contrôle : Melbourne CBD (−37.8136 ; 144.9631) tombe vers le pixel (278 ; 277), presque au centre.

### Mouvement : block matching

*Analogie : deux photos d'une foule prises à 10 min d'écart. Pour chaque petit groupe de la première, tu essaies tous les décalages proches dans la seconde ; celui qui ressemble le plus est son déplacement.*

- Blocs de 16 × 16 px, recherche à ± 24 px (jusqu'à \~70 km/h entre deux images), critère = somme des différences absolues.
- Blocs sans pluie ignorés ; filtre médian 3 × 3 sur les vecteurs ; moyenne sur les 3 dernières paires d'images.
- Trop peu de blocs valides → un seul vecteur global pour toute la tuile.

**Pourquoi la médiane et le repli global :** à l'intérieur d'une grande zone de pluie uniforme, tous les décalages se ressemblent. *C'est comme un mur gris qui glisse : impossible de dire de combien il a bougé en ne regardant que son milieu.* Les bords de la zone, eux, se voient bien ; le lissage propage leur information.

### Extrapolation : semi-lagrangien arrière

*Analogie : pour savoir ce qui passera sous un pont dans 10 min, regarde ce qui flotte 10 min en amont maintenant.* Chaque case du futur va chercher sa valeur en remontant le courant, au lieu d'attendre qu'une valeur lui arrive : aucune case ne reste vide.

```latex
I_{t_0 + k}(\mathbf{x}) = I_{t_0}\left(\mathbf{x} - \tfrac{k}{10}\,\mathbf{v}(\mathbf{x})\right), \qquad k = 1, \dots, 30 \text{ min}
```

v en pixels par 10 min, lecture bilinéaire, hors tuile = 0. **Performance :** ne calcule que la zone utile, soit le trajet + la distance que la pluie peut parcourir en 30 min (\~35 km, \~73 px de marge) : environ 150 × 150 px au lieu de 512 × 512, \~12 fois moins de calcul.

### De la couleur à la pluie

La palette Universal Blue encode la réflectivité en dBZ. Conversion en mm/h par la relation de Marshall–Palmer :

```latex
Z = 10^{\,\text{dBZ}/10} = 200\,R^{1.6} \quad \Rightarrow \quad R = \left(\frac{10^{\,\text{dBZ}/10}}{200}\right)^{1/1.6}
```

Repères : 20 dBZ ≈ 0,65 mm/h ; 30 dBZ ≈ 2,7 mm/h ; 40 dBZ ≈ 11,5 mm/h. Poids de pluie nowcast : w = min(1, R / 1 mm/h), cohérent avec le poids horaire de l'étape 2.

**Mélange avec la prévision :** échéance = heure visée − heure de la **dernière image** (pas « maintenant » : l'image a déjà du retard). α = max(0, 1 − échéance / 30 min), puis w = α · w\_nowcast + (1 − α) · w\_horaire. Les résultats de vérification serviront à ajuster cette pente (bonus).

### Vérification

*La référence à battre est la persistance : « la pluie ne bouge pas », comme dire que la météo de demain sera celle d'aujourd'hui. Si ton nowcast ne fait pas mieux, il n'apporte rien.*

Seuil de pluie 20 dBZ. Pour chaque pixel : prévu et observé (touché), observé non prévu (manqué), prévu non observé (fausse alerte).

```latex
\text{CSI} = \frac{\text{touchés}}{\text{touchés} + \text{manqués} + \text{fausses alertes}}
```

### Tests

| Test | Situation | Attendu |
| --- | --- | --- |
| `georeferencesMelbourneCBD` | (−37.8136 ; 144.9631) | Pixel ≈ (278 ; 277) à ±1 |
| `convertsReflectivityToRainRate` | 20, 30, 40 dBZ | 0,65 ; 2,73 ; 11,5 mm/h (±0,05) |
| `recoversUniformShift` | Disque décalé de (+10 ; +4) px par image | Vecteur à ±1 px |
| `zeroMotionKeepsFrame` | Mouvement nul | Grille prévue = dernière image |
| `predictsMovingDisc` | Disque à 10 px / 10 min, échéance 20 min | Centre décalé de 20 px à ±1 |
| `fallsBackToGlobalVector` | Pluie sur moins de 5 blocs | Un seul vecteur |
| `csiBounds` | Prévision identique / disjointe | CSI = 1 / CSI = 0 |
| `beatsPersistenceOnRecordedDay` | Journée enregistrée avec front pluvieux, échéance 20 min | CSI nowcast > CSI persistance |

**Terminé quand :** jalon M1 du HD1, soit tous les tests synthétiques au vert et le nowcast meilleur que la persistance à 20 min sur au moins un jour enregistré. Si une journée d'averses échoue, raccourcis l'horizon et dis-le en démo : c'est un résultat, pas un échec.

**À savoir dire en démo (30 s) :** « Je mesure comment la pluie s'est déplacée entre les dernières images radar, je prolonge ce mouvement minute par minute, et je lis la pluie là où tu seras à chaque minute. Je vérifie mes prédictions contre les images qui arrivent ensuite, et contre l'hypothèse naïve d'une pluie immobile. »

## 12. Étape 6 — Intégration du nowcast et collision view

**But :** jalons M2 et M3 du HD1. Entre deux arrêts, l'app dit « partir maintenant ou attendre » pour le trajet suivant, et un curseur fait bouger ensemble la pluie observée, la pluie prévue et ta position.

### Au lab : du PNG à la décision

| Composant | Rôle | Point d'attention |
| --- | --- | --- |
| `FrameDecoder` (Core Graphics) | PNG → `CGImage` → octets RGBA → dBZ via la table CSV → `RainGrid` | **Piège de l'alpha prémultiplié** : dessiner dans un `CGContext` modifie le RGB des pixels semi-transparents. Lire `cgImage.alphaInfo` ; si prémultiplié, prémultiplier aussi la palette avant comparaison. Test : même grille que Python |
| `LiveRainViewerSource` | JSON des frames, puis tuiles en parallèle (`withThrowingTaskGroup`, 13 au plus) | Cache dans un `actor` indexé par heure d'image ; rafraîchi toutes les 10 min tant que l'écran est visible |
| `NowcastService` (`actor`) | Dernières grilles → mouvement → 30 grilles prévues → `NowcastRainField` mélangé | Image la plus récente vieille de plus de 30 min → nowcast désactivé, retour à la prévision **et message affiché** |
| Re-planification | Arrêts restants, départ = arrêt actuel, fenêtre maintenant → +30 min, même solveur | « Attendre 15 min » respecte toujours l'heure de fermeture du prochain arrêt |
| `DepartureAdviceCard` | « Partir maintenant : \~4 min sous la pluie » / « Attendre 20 min : trajet sec » + « Me rappeler à 14:30 » | Le rappel réutilise le service de notification de l'étape 4 |

Boucle de rafraîchissement, annulée automatiquement quand la vue disparaît :

```swift
.task {
    while !Task.isCancelled {
        await viewModel.refreshRadar()
        try? await Task.sleep(for: .minutes(10))
    }
}
```

### Collision view (`UIViewRepresentable` autour de `MKMapView`)

**Simplification par rapport au HD1 :** un seul overlay maison pour les images observées *et* prévues, plutôt qu'un `MKTileOverlay` pour le passé et un renderer pour le futur. Les grilles sont déjà décodées en mémoire, et le zoom de la carte ne dépend plus du zoom maximal 7 de RainViewer.

- [ ] `RadarImageOverlay: MKOverlay` dont le `boundingMapRect` est celui de la tuile. MapKit utilise le même Mercator que RainViewer, donc la conversion est linéaire : le monde fait 2²⁸ points de carte de côté, une tuile de zoom 7 en fait 2²¹, d'origine (115 × 2²¹ ; 78 × 2²¹).
- [ ] `RadarImageRenderer: MKOverlayRenderer` dessine l'image courante dans `draw(_:zoomScale:in:)`. Images prévues plus transparentes à mesure que l'échéance augmente.
- [ ] Le trajet en `MKPolyline` ; ta position = interpolation des échantillons de trajet à l'heure du curseur.
- [ ] Le `Coordinator` garde les références de l'overlay, du renderer et de l'annotation. `updateUIView` change seulement l'image affichée et la position du marqueur, puis `setNeedsDisplay()` ; il ne retire et ne rajoute jamais d'overlay.
- [ ] Attribution « Radar : RainViewer » visible sur la carte.

**`TimeScrubber` :** `Slider` de −30 à +30 min par pas de 1 min, libellé « 14:18 · observé » ou « 14:18 · prévu ». VoiceOver annonce l'heure, le statut et la pluie à ta position.

### Mode rejeu

- [ ] Une session de pluie enregistrée (PNG, JSON, trajet) copiée dans `Resources/`.
- [ ] Interrupteur dans les réglages : `RecordedSource` + `DateProvider` figé à l'heure enregistrée.
- [ ] Bandeau permanent « Rejeu · 14 oct. 2026, 15:20 », texte + couleur, pour qu'une pluie rejouée ne soit jamais prise pour la météo du jour.

### Plan B si le pont `MKMapView` résiste

Un `Canvas` SwiftUI dessine la zone recadrée (\~150 × 150 px de grille), le trajet projeté avec `Georeference` et ton marqueur, avec le même curseur. Mêmes données, aucun UIKit ; la démo du Wow Factor reste possible.

**Terminé quand :** en rejeu, le conseil s'affiche pour le prochain trajet (M2) et le curseur fait bouger pluie observée, pluie prévue et marqueur ensemble (M3).

## 13. Étape 7 — À propos, robustesse, finitions

**But :** cocher les exigences explicites du P9 (page À propos, erreurs gérées, crédits) et rendre l'app stable. Les bonus ne viennent qu'après.

### Page À propos (obligatoire)

- [ ] Nom de l'app, version (lue dans le bundle), but en deux phrases.
- [ ] **Clement Boudon — Student ID 37465848 — FIT3178, Monash University, S2 2026.**
- [ ] Données : Open-Meteo (CC BY 4.0), RainViewer (radar, usage personnel et éducatif), Apple Maps / MapKit — chacun avec un `Link`.
- [ ] Méthodes : Germann et Zawadzki (2002), Pulkkinen et al. (2019, pysteps), Staniforth et Côté (1991), Marshall et Palmer (1948), Wilks (vérification).
- [ ] Supports FIT3178 (labs 1 à 6), déclaration d'usage de l'IA générative, et la mention « aucune bibliothèque Swift tierce ».
- [ ] Réglages : facteur d'allure, mode rejeu.

### Situations à tester une par une

| Situation | Comportement attendu |
| --- | --- |
| Pas de réseau | Message clair ; matrice en cache utilisée si elle existe |
| Open-Meteo répond 429 ou 5xx | Message + bouton « Réessayer », aucun crash |
| MapKit limite les requêtes | Deux nouvelles tentatives, puis message |
| Aucun planning possible | La raison en clair (quel lieu, quelle fermeture) |
| Aucune pluie dans les 30 min | « Aucune pluie prévue sur ton trajet d'ici 30 min » |
| Images radar trop anciennes | Bascule sur la prévision, message affiché |
| Localisation refusée | Départ choisi à la main |
| Notifications refusées | Explication + bouton vers les Réglages |
| Bibliothèque vide | `ContentUnavailableView` avec action « Ajouter » |
| Nom de course en double | « Tu as déjà une course "Coles" » |

### Passe d'accessibilité et d'apparence

- [ ] VoiceOver sur chaque écran, avec l'Accessibility Inspector d'Xcode (Xcode ▸ Open Developer Tool).
- [ ] Plus grande taille de Dynamic Type : rien n'est coupé.
- [ ] Mode sombre : tout reste lisible.
- [ ] Aucune information portée par la couleur seule (graphe, carte, bandeau de rejeu).

### Propreté du code

- [ ] Zéro avertissement du compilateur, aucun `print`, pas de code mort.
- [ ] `///` d'une phrase sur chaque déclaration publique du package.
- [ ] `README.md` final : structure, build (`open WeatherWindow/WeatherWindow.xcodeproj`, `cd WeatherWindowKit && swift test`), lancer le rejeu, crédits, correspondance avec les labs, journal des sessions Mac.

### Bonus, dans cet ordre, seulement si tout le reste est vert

1. Écran de vérification : Swift Charts, CSI selon l'échéance (10, 20, 30 min), nowcast contre persistance ; scores stockés dans SwiftData.
2. Alerte nowcast : notification si de la pluie est prévue sur le prochain trajet avant son départ.
3. Scénarios issus de l'API d'ensemble d'Open-Meteo (côté Linux, aucun changement du solveur grâce à `RainField`).
4. Estimateur Vision, si le go/no-go de l'étape 0 était positif.

**Terminé quand :** chaque ligne du tableau a été provoquée volontairement dans le simulateur sans crash, et la page À propos est complète.

## 14. Planning des mercredis

Le MVP doit tourner le soir du **14 oct.** et le nowcast le **21 oct.** : ce sont les deux seules sessions Mac certaines après la mise en place. Tout le reste de la semaine se passe sous Linux.

&#91;embedded content: Planning · 8 étapes, 5 mercredis dont 3 garantis\]

Les étapes 1 et 5 (marquées Linux) se font entièrement chez toi : elles avancent entre les mercredis sans consommer de temps Mac.

| Session | Date | Objectif | Terminé quand |
| --- | --- | --- | --- |
| Mac 1 | 7 oct. | Projet Xcode + package, go/no-go, modèles SwiftData, bibliothèque de courses | Les courses persistent après relancement |
| Mac 2 | 14 oct. | Services réels, Planifier, Résultats ; puis courbe et carte s'il reste du temps | Tag `mvp` |
| Mac 3 | 21 oct. | `FrameDecoder`, `NowcastService`, carte conseil, collision view (ou `Canvas`) | M2 et M3 du HD1 en rejeu |
| Mac 4 (à confirmer) | 28 oct. | Notification, À propos, tableau des erreurs, accessibilité, vidéo de secours | Tableau de l'étape 7 entièrement vérifié |
| Mac 5 (à confirmer) | 4 nov. | Répétition, corrections, bonus | Démo fluide en 5 min |

**Si les Mac 4 et 5 ne sont pas accessibles :** la page À propos et le tableau des erreurs passent en fin de Mac 3, et la collision view part directement en version `Canvas`. Décide-le dès la réponse de Jason, pas le 21 au soir.

## 15. Préparer la démo et la discussion

La démo se joue en **mode rejeu** : elle ne doit dépendre ni de la météo du jour ni du réseau du lab.

### Scénario de 5 minutes

1. **Courses** : la bibliothèque contient déjà 4 lieux réels (poste, Coles, bibliothèque, salle de sport).
2. **Planifier** : 3 courses, fenêtre de 2 h, « Calculer ». Montrer la courbe, toucher « le plus rapide » puis « le plus sec », la carte change, le trajet pluvieux est en pointillé.
3. **Rejeu** : le bandeau s'affiche ; ouvrir le plan entre deux arrêts ; la carte conseil dit « Attendre 20 min ».
4. **Curseur** : à gauche la pluie observée, à droite la pluie prévue, ton marqueur avance ; montrer le passage évité de justesse.
5. **Preuve** : le résultat du test `beatsPersistenceOnRecordedDay` (CSI nowcast contre persistance à 20 min).
6. **Une erreur provoquée** : une fermeture trop tôt → « aucun planning possible » avec la raison.
7. **À propos** : identité, crédits, usage de l'IA.

### Les six questions du sujet, préparées

| Question du P9 | Ta réponse s'appuie sur |
| --- | --- |
| Conception et but de l'app | L'exemple de 14:10 (section 1) |
| Implémentation des fonctions clés | Les deux résumés de 30 s : solveur (section 7) et nowcast (section 11) |
| Technologies et patrons | SwiftUI + `@Observable`, SwiftData, MapKit, Swift Charts, Core Graphics, `actor` / `@concurrent` / `TaskGroup` ; protocole `RainField` (patron stratégie) ; injection de `DateProvider` |
| Respect des exigences | Le tableau P9 de la section 1, ligne par ligne |
| Difficultés et solutions | Suppression du nowcast RainViewer au 1er janvier 2026 ; alpha prémultiplié ; problème d'ouverture du block matching ; un seul jour de Mac → package Linux |
| Ressources externes | La page À propos |

### Modifications à répéter une fois chacune

Le sujet prévoit qu'on te demande de modifier ton code en direct. Entraîne-toi sur :

- [ ] passer le pas de départ de 5 à 10 min ;
- [ ] changer le seuil de pluie de 20 à 25 dBZ et relancer les tests ;
- [ ] ajouter un champ à `SavedErrand` (ex. une note) et l'afficher dans le formulaire ;
- [ ] étendre le curseur à ±45 min.

**Filet de sécurité :** un enregistrement vidéo de la démo dans le simulateur (File ▸ Record Screen), fait au dernier mercredi disponible.

## 16. Risques et plans B

Le risque n°1 est le temps Mac, pas la technique. Chaque ligne a un **signal d'alerte** précis : quand il apparaît, tu bascules sur le plan B sans attendre.

| Risque | Signal d'alerte | Plan B |
| --- | --- | --- |
| Trop peu de mercredis | MVP pas fini le soir du 14 oct. | Niveau B réduit à la courbe seule ; collision view en `Canvas` |
| Le SwiftUI écrit sous Linux ne compile pas | Plus d'une heure de corrections au début d'une session | Vues plus petites, calquées sur celles des labs ; logique déplacée dans le package |
| Versions de Swift différentes | Le package compile sous Linux mais pas dans Xcode | Aligner Swift avec `swiftly` sur la version du lab ; garder `swift-tools-version: 6.0` |
| Pas de pluie enregistrée | Moins d'une journée pluvieuse le 14 oct. | Continuer le cron ; en dernier recours, une session synthétique clairement étiquetée comme telle |
| Palette impossible à inverser proprement | Plus de 1 % de pixels de couleur inconnue | Classes discrètes (faible, modérée, forte), suffisantes pour l'exposition |
| Le nowcast ne bat pas la persistance | Test `beatsPersistenceOnRecordedDay` rouge | Horizon réduit à 20 min, résultat présenté honnêtement |
| RainViewer change encore ou tombe | Erreurs HTTP ou format JSON modifié | Protocole `RadarFrameSource`, rejeu, retour à la prévision |
| Vision indisponible dans le simulateur | Go/no-go n°2 négatif | Block matching seul (déjà l'estimateur principal) |
| Limitation MapKit | `MKError.loadingThrottled` répété | Cache de la matrice, 3 requêtes en parallèle au plus, nouvelles tentatives |
| Travail perdu sur le Mac du lab | Session non poussée | Push toutes les heures, tag en fin de session |
| Dérive du périmètre | Envie d'ajouter une fonction après le 21 oct. | Règle : après le 21 oct., seulement la liste des bonus de l'étape 7, dans l'ordre |

## Sources

- [RainViewer — API Transition Summary](https://www.rainviewer.com/api/transition-faq.html) : fin du nowcast, schéma Universal Blue seul, zoom 7 maximum, 100 requêtes par minute et par IP depuis le 1er janvier 2026.
- [RainViewer — Weather Maps API](https://www.rainviewer.com/api/weather-maps-api.html) : format du JSON et des URL de tuiles, 2 h d'historique par pas de 10 min.
- [RainViewer — Color Schemes](https://www.rainviewer.com/api/color-schemes.html) : identifiant 2 = Universal Blue, table dBZ → RGBA en CSV.
- [Monash — Semester dates summary](https://www.monash.edu/students/admin/dates/summary-dates) : fin des cours le 23 oct., SWOT vac 26–30 oct., examens 2–18 nov. 2026.
- [Use Your Loaf — Approachable Concurrency in Swift Packages](https://useyourloaf.com/blog/approachable-concurrency-in-swift-packages/) : réglages de concurrence par défaut des projets Xcode 26.
- Sujets FIT3178 fournis : P6 (26 août 2026), HD1 Wow Factor (21 sept. 2026), P9 Custom App.
