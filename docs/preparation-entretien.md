# Préparation à l'entretien final

Ce fichier complète `explication-du-code.md`. L'explication dit **ce que fait** chaque dossier ; ce fichier dit **comment le code le fait** : les lignes qu'on peut te montrer, les pièges, et les modifications à savoir faire en direct.

Tous les chemins partent de `repo-mac-gitlab/WeatherWindow/`.

---

## 0. Le périmètre

- **Les vues SwiftUI sont dans le périmètre.** C'est ton code, et les modifications demandées en direct sont souvent visibles à l'écran (un texte, un bouton, un champ, un tri). Ils veulent voir le changement dans le simulateur.
- **Les tests unitaires** : savoir les lancer (⌘U), citer 2 ou 3 noms, et savoir qu'une modification peut en casser un (c'est normal, il faut le dire).
- **Les tests UI** (`WeatherWindowUITests`) : savoir en une phrase ce qu'ils font (captures + audit d'accessibilité Apple), c'est tout.

---

## 1. Le fil complet, du lancement à « Leave now »

| Étape | Fichier : ligne | Ce qui se passe |
| --- | --- | --- |
| Lancement | `App/WeatherWindowApp.swift` `init` | `ModelContainer` pour les 5 modèles ; en mémoire seulement avec `--sample-data` (tests UI). `ErrandStore` créé avec `container.mainContext` |
| Injection | `WeatherWindowApp.body` | `.environment(errandStore)`, `.environment(notificationService)`, `.modelContainer(container)` |
| Onglets | `App/RootView.swift` | `TabView` + `Tab(...)` (API iOS 18) ; bandeau si `@AppStorage("replayMode")` |
| Choix | `Screens/Plan/DayPlanView.swift` | `@Query` lit les courses ; un toucher appelle `model.toggle(errand)` |
| Calculate | `DayPlanView.calculate()` → `DayPlanViewModel.calculate` | `Task { await ... }`, puis `showsResults = true` si `model.result != nil` |
| Données | `Services/PlanDataSource.swift` | `data` vaut `ReplayData()` ou `LiveData(...)` selon le réglage |
| Solveur | `DayPlanViewModel.rankSchedules` (`@concurrent`) → `Planner.rankSchedules` | ordres × départs → `simulate` → `TradeOffs.best` |
| Résultats | `Screens/Plan/ResultsView.swift` | `switch result.outcome` : `.noPlan` ou `.schedules` |
| Itinéraire | `Screens/Plan/ItineraryView.swift` | étapes, Save (`PlanResult.save`), rappel, partage |
| Radar | `Screens/NextWalk/NextWalkView.swift` | boucle `.task` toutes les 10 min → `NextWalkViewModel.load` → `NowcastMaker.make` → `DepartureAdvisor.advice` |

---

## 2. Les détails qu'on peut te demander (et que tu dois savoir expliquer)

### Le solveur (`Planner/`)

- **`Schedule.duration` se compte depuis le début de la fenêtre**, pas depuis le départ (`Planner.swift`, `simulate`, dernier `return`). Donc « Fastest » = **rentré le plus tôt**. Attendre chez soi compte comme du temps perdu.
- **Ordre du front de Pareto** (`TradeOffs.best`) : on trie par durée croissante (à égalité, par pluie), puis on garde un plan **seulement s'il a strictement moins de pluie** que le dernier gardé. Le résultat va donc du plus rapide (le plus mouillé) au plus sec (le plus lent). C'est pour ça que :
  - `PlanResult.fastest` = `schedules.first` ;
  - `PlanResult.driest` = `schedules.last` ;
  - `DepartureAdvisor` prend `schedules.last` comme meilleur départ.
- `- 1e-9` dans `TradeOffs` : tolérance pour les erreurs d'arrondi des `Double`.
- **`orders(of:)` est récursive** : pour chaque course, on la met en premier et on ajoute toutes les permutations du reste. 4 courses → 4! = 24 ordres.
- **`simulate`** :
  - `makeWalk` cherche le temps dans `walkingTimes[from]?[to]` (dictionnaire de dictionnaires) ;
  - `serviceStart = max(arrivée, ouverture)` : on **attend** si c'est fermé ;
  - `serviceEnd > closing` → `.rejected(stop)` ;
  - à la fin, la pluie par scénario = la somme des trajets pour ce scénario.
- **Message « closes too early »** : `rejections[stop.id, default: 0] += 1` compte combien de plans chaque course a fait échouer. On accuse celle qui en a fait échouer le plus (`max`).
- **`PlanRequest.neededPairs`** : départ → chaque course, chaque course → arrivée, chaque course → chaque autre. Pour n courses : 2n + n(n−1). Pour 4 : 8 + 12 = **20 trajets**.
- **`Waypoint`** est un enum avec valeur associée (`.stop(UUID)`) : un seul type pour « départ », « arrivée » et « course », utilisable comme clé de dictionnaire parce qu'il est `Hashable`.
- **`Schedule.id`** = heure de départ + ordre des UUID. Deux plans avec le même ordre à la même heure sont le même plan.

### La pluie (`Rain/`)

- **`RainForecast`** est un **protocole** avec une seule fonction. `[any RainForecast]` = un tableau de n'importe quelles sources (`any` = type existentiel).
- **`HourlyForecast.weight`** : `hours.first { $0.time > time }`, la première heure **après** l'instant. Open-Meteo donne à 15:00 la pluie de 14:00 à 15:00. À 14:20, on lit donc la ligne 15:00. Plus d'une heure d'écart → 0.
- **`ShiftedForecast`** : `time.addingTimeInterval(-offset)`. Avec `offset = +15 min`, la pluie de 14:00 arrive à 14:15 : la pluie est **en retard**.
- **`ForecastHour.rainWeight`** = probabilité (0 à 1) × pluie bornée à 1 mm. Le `min(max(...))` sert à **borner** (clamp).
- **`Ensemble.scenarios`** : on additionne la pluie de chaque run sur la fenêtre, on trie, et on prend les centiles 50, 10, 30, 70, 90. `Int((Double(count - 1) * percentile).rounded())` transforme un centile en indice. La médiane est mise en premier.

### Le radar (`Radar/`)

- **`MotionFinder` normalise sur 10 min** : `scale = 600 / secondes entre les 2 images`. Un mouvement vaut donc « pixels par 10 minutes ». `RainMover` utilise `steps = minute / 10`. Les deux sont cohérents.
- **Coût d'un décalage** (`cheapestShift`) : somme des différences absolues (SAD) entre le bloc avant et le bloc décalé après. À coût égal, on préfère le plus petit décalage.
- **`intensity`** retire 10 dBZ de bruit (`noiseFloor`), pour que le fond n'influence pas le mouvement.
- **`RainMover`** : pour chaque pixel futur (x, y), on lit l'image actuelle **en amont**, en (x − steps·dx, y − steps·dy), avec `sample` (interpolation **bilinéaire**). C'est l'advection semi-lagrangienne **arrière**.
- **`RainMotion.movement(atX:y:)`** : interpolation bilinéaire entre les 4 blocs voisins, pour que le mouvement change en douceur d'un bloc à l'autre.
- **`RadarForecast.weight`** : `share = 1 − lead / 30 min`, où `lead` part de la **dernière image**. Si l'image a 10 min, la part du radar est déjà 2/3 au moment présent.
- **`RainRate.weight`** compte tout ce qui dépasse −32 dBZ (« pas d'écho »), donc même une pluie très faible (10 dBZ ≈ 0,15 mm/h) pèse un peu. Le seuil de 20 dBZ ne sert qu'aux blocs de `MotionFinder` et au CSI.
- **`NowcastMaker.margin = 73`** pixels autour du trajet (≈ 35 km) : la pluie qui arrivera dans 30 min est déjà dans cette zone.
- **`PNGImage`** : 8 octets de signature, puis des **chunks** (longueur, type, données, CRC). `IHDR` = taille et format, `IDAT` = données compressées, `IEND` = fin. On enlève l'en-tête zlib (2 octets) et le checksum (4 octets) avant `decompressed(using: .zlib)`, qui attend du deflate brut. Chaque ligne commence par un octet de filtre (0 à 4, dont **Paeth**).
- **`&+`** dans `unfilter` : addition qui **déborde sans planter** (255 + 1 = 0), comme le veut la norme PNG.

### Les données (`Database/`)

- **`@Attribute(.unique) var key`** (`CachedWalkingTime`) : une seule entrée par trajet.
- **La clé du cache** a 5 décimales, soit environ 1 m de précision.
- **Le cache stocke le temps brut d'Apple Maps.** `paceFactor` s'applique **après** (`DirectionsService.walkingMatrix`). Changer l'allure ne vide donc pas le cache.
- **`DayPlan.endName == nil`** veut dire « retour au départ » (`end` renvoie alors `start`).
- **`PlannedStop` copie** le nom, le lieu, la durée et les horaires de la course. Il garde aussi un lien `errand` (nullify) pour « Used in Plans » et « Use a Saved Itinerary ».
- **`ErrandStore` passe par l'environnement** (`@Environment(ErrandStore.self)`) pour **écrire**. Les vues **lisent** avec `@Query`, qui se met à jour seul.
- **`#Predicate { $0.normalizedName == normalizedName }`** : un filtre traduit en requête de base de données, pas une boucle Swift.

### Les services (`Services/`)

- **`LocationService`** transforme le délégué `CLLocationManager` en `async` avec **`withCheckedThrowingContinuation`**. La continuation est gardée, puis `finish` l'appelle **une seule fois** et la remet à `nil` (la reprendre deux fois ferait planter l'app). Un `Task` de 15 s sert de délai maximum.
- **`DirectionsService.walkingTime`** : si Apple Maps répond `loadingThrottled`, on attend 3 s et on réessaie une fois.
- **`savedLines`** est un dictionnaire `static` : les tracés restent en mémoire tant que l'app tourne, pas sur le disque.
- **`OpenMeteoService`** : `URLComponents` + `URLQueryItem` (pas de chaîne collée à la main), `timeformat=unixtime` pour lire les heures comme des nombres. `HourlyData` utilise `CodingKeys` pour `precipitation_probability`. `[Double?]` parce qu'Open-Meteo renvoie parfois `null`.
- **L'ensemble** a des clés `precipitation_member01`... : on lit donc `[String: [Double?]]` et on garde les clés qui commencent par `precipitation`.
- **`ServiceError.check`** : 429 → `rateLimited`, hors 200–299 → `httpStatus(code)`.
- **`PlaceSearchService.query`** a un `didSet` qui relance la recherche à chaque lettre. `@ObservationIgnored` sur le `completer` : SwiftUI n'a pas besoin de le suivre.
- **`NotificationService`** : `userNotificationCenter(_:willPresent:)` renvoie `[.banner, .sound]` pour que la notification s'affiche **même quand l'app est ouverte**.

### Les view models (`Screens/`)

- **`@Observable final class`** : SwiftUI redessine seulement les vues qui **lisent** une propriété modifiée.
- **`private(set) var state`** : la vue peut lire l'état mais pas le changer.
- **`@State private var model = DayPlanViewModel()`** : la vue **possède** le view model, qui survit aux redessins.
- **`_model = State(initialValue: ErrandFormModel(errand: errand))`** (`ErrandFormView.init`) : comment créer un `@State` avec un paramètre reçu dans `init`.
- **`didSet`** sur `startsAtCurrentLocation` et `startPlace` : sauvegarde dans `UserDefaults` (le lieu en JSON avec `JSONEncoder`, parce que `Place` est `Codable`).
- **`defer { progress = nil }`** : s'exécute à la sortie de la fonction, qu'elle réussisse ou échoue.
- **Erreur de localisation** dans `calculate` : `startsAtCurrentLocation = false`, donc le sélecteur passe tout seul sur « Choose Place ».
- **`PlanResult.tradeOff`** : position du plan sur le front, de 0 (le plus rapide) à 1 (le plus sec). `usualChoice` fait la moyenne des plans enregistrés et prend le plan à la même position.
- **`PlanResult.isSaved`** compare l'heure de départ, l'heure de retour et les **noms** des courses, pour ne pas enregistrer deux fois le même plan.
- **`DayPlanViewModel.reuse`** reconnaît un départ « position actuelle » par le texte `"Current Location"`, le même texte que celui écrit dans `calculate`.
- **`NextWalkViewModel.rainAlert`** : `foundRain` garde l'état précédent ; on n'alerte que quand on passe de sec à pluvieux, une seule fois.

### Les vues

- **`.task { }`** : démarre quand la vue apparaît, **annulée** quand elle disparaît (d'où `while !Task.isCancelled` dans `NextWalkView`).
- **`.task(id: schedule.id)`** (`RouteMapView`) : relancée quand l'`id` change, c'est-à-dire quand on touche un autre point du graphe.
- **`.onChange(of: replayMode, initial: true)`** : s'exécute aussi au premier affichage.
- **`.safeAreaInset(edge: .bottom)`** : le bouton Calculate reste en bas, au-dessus du formulaire.
- **`.navigationDestination(isPresented:)`** : navigation déclenchée par du code, après le calcul.
- **`.sheet(item: $editedErrand)`** : la feuille s'ouvre quand `editedErrand` n'est plus `nil`, avec cette course.
- **Closures de retour** : `PlaceSearchView { place in model.startPlace = place }` et `ItinerariesView { plan in model.reuse(plan) }`. La vue enfant appelle `onSelect(...)` puis `dismiss()`.
- **`@Binding`** : `TradeOffChart` reçoit `$selectedID` et le modifie ; `ResultsView` voit le changement.
- **`ViewThatFits`** (`RouteMapView`) : la légende en ligne si elle tient, sinon en colonne (très grand texte).
- **`Canvas`** (`CollisionView`) : dessin direct, avec `scaleBy` et `translateBy` pour travailler en pixels radar.
- **`#available(iOS 26, *)`** : la section « Describe It » n'existe que sur iOS 26 ; l'app tourne dès iOS 18.

### La concurrence (Swift 6)

- **Réglage du projet** : `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Tout est sur le fil principal sauf ce qui est marqué autrement.
- **`nonisolated struct`** : utilisable depuis n'importe quel fil (`Planner`, `Rain`, `Radar`, les réponses `Decodable`).
- **`@concurrent`** : la fonction async tourne **hors** du fil principal (`rankSchedules`, `advise`, `evaluate`, `frames`).
- **`RainForecast: Sendable`** : les scénarios peuvent passer vers le fil du solveur sans risque.

---

## 3. Modifications en direct

Entraîne-toi sur le Mac, dans le clone GitLab, puis annule avec `git checkout .`. Pour chacune : **dire où**, **taper**, **⌘R**, **montrer**, et **dire quel test peut casser**.

### Faciles (une ligne)

| Demande | Où | Code | À dire aussi |
| --- | --- | --- | --- |
| Départs toutes les 10 min | `Planner/PlanRequest.swift:15` | `var departureStep: TimeInterval = 10 * 60` | Changer le texte « 5 minutes apart » (`DayPlanView.swift:162`). Le cas A de `PlannerTests` attend des départs de 5 min et va échouer |
| 5 courses au lieu de 4 | `Screens/Plan/DayPlanViewModel.swift:98` | `static let maxErrands = 5` | 120 ordres au lieu de 24 (encore instantané), mais 30 trajets Apple Maps au lieu de 20, proche de la limite d'environ 50/min. `DebugView` garde `prefix(4)`. `DayPlanViewModelTests` attend 4 |
| Fenêtre jusqu'à 6 h | `DayPlanViewModel.swift:187-188` | `> 6 * 3600` et le message « under 6 hours » | — |
| Fenêtre par défaut de 1 h | `DayPlanViewModel.swift:127` et `:137` | `addingTimeInterval(1 * 3600)` | Deux endroits : `init` et `resetWindow` |
| « Dry » sous 1 min de pluie | `Helpers/PlanText.swift:12` | `exposure < 1` | Change tous les badges, l'alerte pluie et le conseil Next Walk |
| N'attendre que pour 3 min de gain | `Planner/DepartureAdvisor.swift:22` | `static let minimumSaving = 3.0` | — |
| Radar rechargé toutes les 5 min | `Screens/NextWalk/NextWalkView.swift:83` | `.seconds(5 * 60)` | Texte du pied de section (ligne 45). RainViewer publie une image toutes les 10 min |
| Trajets pluvieux en rouge | `Screens/Plan/RouteMapView.swift:27` | `Color.red : Color.blue` | Le pointillé reste : la couleur n'est jamais la seule info (accessibilité) |
| Courses triées par durée | `Screens/Errands/ErrandListView.swift:13` | `@Query(sort: [SortDescriptor(\SavedErrand.durationMinutes), SortDescriptor(\SavedErrand.name)])` | Le 2e tri départage les égalités |
| Nombre de plans dans le titre | `Screens/Plan/ResultsView.swift:85` | `Section("All Trade-offs (\(schedules.count))")` | — |
| Seuil radar à 25 dBZ | `Radar/RainRate.swift:11` | `static let rainThresholdDBZ: Float = 25` | Change les blocs de `MotionFinder` et le CSI ; `beatsPersistenceOnRecordedDay` peut changer |

### Moyennes (quelques lignes)

**Moyenne au lieu du pire scénario** — `Planner/Schedule.swift:35`
```swift
var robustExposure: Double {
    if exposureByScenario.isEmpty { return 0 }
    return exposureByScenario.reduce(0, +) / Double(exposureByScenario.count)
}
```
À dire : le plan devient moins prudent. Le test du pire scénario (`PlannerTests`, `robustExposure - 3`) échoue, c'est voulu.

**Décalages à ±45 min (7 scénarios)** — `Rain/ShiftedForecast.swift:19-25`
```swift
ShiftedForecast(base: base, offset: -45 * 60),
ShiftedForecast(base: base, offset: 45 * 60)
```
À dire : 7 scénarios au lieu de 5, donc 40 % de calcul en plus. Changer « up to 30 minutes » dans `ForecastNotice` (`SharedViews.swift`). `DayPlanViewModelTests` attend 5 scénarios.

**Temps de marche total dans l'itinéraire** — `Screens/Plan/ItineraryView.swift`, après la ligne 26 :
```swift
LabeledContent("Walking", value: PlanText.duration(
    schedule.walks.reduce(0) { $0 + $1.arrival.timeIntervalSince($1.departure) }))
```

**Badge du nombre de courses sur l'onglet** — `App/RootView.swift`
```swift
@Query private var errands: [SavedErrand]   // + import SwiftData
...
Tab("Errands", systemImage: "checklist") {
    ErrandListView()
}
.badge(errands.count)
```

**Curseur radar à ±45 min**
- `NextWalkView.swift:119` : `in: -45...45`, et les libellés `−45` et `+45` ;
- `Radar/NowcastMaker.swift:51` : `minutes: 1...45` ;
- `CollisionView.swift:134` et `:136` : `min(45, …)` et `max(-45, …)` ;
- `RadarForecast.horizon` reste à 30 min : au-delà, c'est la prévision seule qui compte.

**Confirmation avant de supprimer une course** — `Screens/Errands/ErrandListView.swift`
```swift
@State private var pendingDelete: [SavedErrand] = []
@State private var confirmsDelete = false
...
.onDelete { offsets in
    pendingDelete = offsets.map { visibleErrands[$0] }
    confirmsDelete = true
}
...
.confirmationDialog("Delete this errand?", isPresented: $confirmsDelete) {
    Button("Delete", role: .destructive) { store.delete(pendingDelete) }
} message: {
    Text("Saved plans keep their own copy.")
}
```
Remplace `.onDelete(perform: deleteErrands)` à la ligne 50.

### Grosses (plusieurs fichiers)

**Ajouter une note à une course** (le cas classique « ajoute un champ au modèle »)
1. `Database/SavedErrand.swift` : `var note = ""`. La valeur par défaut permet à SwiftData de migrer les courses déjà enregistrées.
2. `Screens/Errands/ErrandFormModel.swift` : `var note = ""` ; dans `init`, `note = errand.note` ; dans `makeErrand`, créer l'objet, puis `errand.note = note`, puis le renvoyer.
3. `Database/ErrandStore.swift`, `update` : `errand.note = edited.note`. **C'est l'oubli classique** : sans cette ligne, la modification n'est jamais enregistrée.
4. `Screens/Errands/ErrandFormView.swift`, section « Errand » : `TextField("Note", text: $model.note)`.
5. `Screens/Errands/ErrandListView.swift`, `ErrandRow` : `if !errand.note.isEmpty { Text(errand.note).font(.caption) }`.

**Afficher la température** (le cas classique « ajoute un champ à l'API », pattern du lab 5)
1. `Services/OpenMeteoService.swift:37` : `value: "precipitation_probability,precipitation,temperature_2m"`.
2. `HourlyData` : `let temperature: [Double?]?` et, dans `CodingKeys`, `case temperature = "temperature_2m"`. Optionnel pour que les JSON des tests (sans température) se lisent encore.
3. `Rain/ForecastHour.swift` : `var temperature: Double? = nil`. La valeur par défaut évite de changer tous les appels existants (`Ensemble`, tests).
4. `forecastHours(from:)` : ajouter `temperature: hourly.temperature?[index]` dans le `ForecastHour(...)`.
5. L'afficher dans `Screens/About/DebugView.swift`, dans la ligne de chaque heure.

---

## 4. Les points faibles, et la réponse honnête

| Critique possible | Réponse |
| --- | --- |
| « La pluie est lue sur une ligne droite » | Seulement dans le solveur. Un pixel radar fait environ 480 m, donc la ligne droite et la rue tombent dans les mêmes pixels. Les cartes montrent la vraie rue |
| « La prévision n'est lue qu'en un point » | Le centre des courses. Les courses sont à pied, à quelques km ; la prévision Open-Meteo a une maille plus large que ça. Le radar, lui, est lu point par point |
| « Force brute, ça ne passe pas à l'échelle » | n! ordres, donc limité à 4 courses (24 ordres). Pour plus, il faudrait un algorithme heuristique ; pour 4, la force brute donne la vraie meilleure solution |
| « `"Current Location"` est une chaîne magique » | Vrai. Un booléen dans `DayPlan` serait plus propre, mais il faudrait changer le modèle SwiftData |
| « Les tracés ne sont gardés qu'en mémoire » | Ils servent seulement au dessin. Les temps de marche, qui comptent pour le calcul, sont dans SwiftData pendant 7 jours |
| « Le nowcast bat à peine la persistance » | 0,314 contre 0,291 à 20 min le 3 octobre. Gain modeste mais mesuré, et c'est dit dans l'app |
| « L'ensemble n'existe pas en replay » | Il n'a pas été enregistré le 3 octobre ; l'app retombe sur les décalages de ±15 et ±30 min sans message d'erreur |

---

## 5. Le jour J

- Arriver **en avance** pour préparer le Mac : Xcode ouvert sur le clone GitLab, build réussi, simulateur lancé, position réglée sur le CBD.
- Avoir **le replay prêt** (About ▸ Replay) au cas où il ne pleut pas ou si le réseau tombe.
- Avant chaque modification : `git status` propre. Après la démo : `git checkout .` pour revenir en arrière.
- Quand on te pose une question : **ouvrir le fichier** et montrer la ligne, plutôt que réciter.
