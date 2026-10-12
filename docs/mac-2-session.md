# Séance Mac 2 — mercredi 14 octobre 2026

But : la boucle complète tourne dans le simulateur avec de vraies données (position, Apple Maps, Open-Meteo). La séance se termine par le tag `mvp`.

Depuis le Mac 1, le code a été simplifié, mais toutes les fonctions sont restées. Le dépôt de référence est le GitLab (`repo-mac-gitlab/`). `Tools/sync-from-gitlab.sh` le recopie dans `AppStaging/` et `WeatherWindowKit/` pour que la CI GitHub compile les mêmes fichiers.

## Avant de partir (Linux)

- [ ] Pousser sur GitHub, puis `./ww status` : CI *Apple* verte (tests unitaires, captures, audit d'accessibilité). `./ww screenshots` pour voir les captures.
- [ ] Pousser sur GitLab.
- [ ] Relire « Ce qui a changé » ci-dessous : c'est ce qu'on peut te demander d'expliquer.

## Ce qui a changé depuis le Mac 1

| Avant | Maintenant | À dire en une phrase |
| --- | --- | --- |
| `PlanServices` (struct de closures), `AppMode`, `ReplaySession` | Protocole `PlanDataSource`, avec `LiveData`, `ReplayData` et, dans les tests, `FakeData` | « Le rejeu et les tests sont juste d'autres sources de données ; les view models ne voient pas la différence. » |
| `DirectionsService` + `WalkingMatrixBuilder` + `RouteService` | Un seul `DirectionsService` : temps de marche (cache SwiftData d'une semaine), tracé pour la carte | « Une requête à la fois ; si Apple Maps limite, j'attends 3 s et je réessaie une fois. » |
| `LocationService` avec `CLServiceSession` et `TaskGroup` | Le `LocationProvider` du lab 7 + une fonction `async` | « Le délégué `CLLocationManager` du lab 7, transformé en `async` avec une continuation. » |
| Bandeau de rejeu ajouté sur 7 écrans | Une seule fois, au-dessus du `TabView` (`RootView`) | |
| `NavigationPath` + `PlanRoute` | `NavigationLink { … }` et `.navigationDestination(isPresented:)` | |
| Graphe : `chartOverlay` + `GeometryReader` | `chartXSelection`, puis le plan dont la durée est la plus proche | |
| Collision view : fabrication d'un `CGImage` | Le `Canvas` dessine un carré de couleur par pixel radar | |
| Package : génériques, recherche dichotomique, `DateProvider` | Boucles simples, `PlanRequest.neededPairs`, `Node.location`, nouveau cas `outsideRadar` | Mêmes résultats : `ww verify` donne des scores CSI identiques sur tous les jours enregistrés |

Bugs corrigés au passage :

- les tests écrivaient dans les vrais réglages de l'app ;
- la carte gardait le tracé d'un autre plan ;
- le nowcast pouvait planter hors de la tuile radar de Melbourne ;
- la fenêtre de départ pouvait être déjà passée.

## Au lab, dans l'ordre

**1. Récupérer et compiler.** `git pull` dans le clone GitLab, puis ouvrir `WeatherWindow.xcodeproj`. Les dossiers sont synchronisés : les fichiers ajoutés ou supprimés sous Linux apparaissent ou disparaissent d'eux-mêmes.

Terminé quand : ⌘B donne 0 erreur et 0 avertissement. Sinon, copier l'erreur exacte (fichier:ligne) et me l'envoyer.

**2. Repartir d'une base vide.** Les modèles SwiftData ont changé : `SavedErrand.id` a été ajouté, `DayPlan` simplifié et le cache passé en `@Attribute(.unique)`. Supprimer l'app du simulateur (appui long sur l'icône ▸ Supprimer l'app) avant de la lancer.

Terminé quand : l'app démarre sans `fatalError`.

**3. Tests.** ⌘U.

Terminé quand : les 20 tests unitaires et les 2 classes de tests UI passent.

**4. Vraies courses.** Features ▸ Location ▸ Custom Location : −37.8136, 144.9631. Ajouter 4 courses :

- Australia Post GPO ;
- Coles Melbourne Central ;
- State Library Victoria, en tapant l'adresse puis Retour ;
- une salle de sport.

Essayer ensuite le doublon « coles ».

Terminé quand : le message de doublon apparaît sous le nom, et les 4 courses sont toujours là après ■ puis relance.

**5. Écran de debug.** About ▸ Developer ▸ Walking times and forecast.

Terminé quand : 20 temps de marche et 48 h de prévision s'affichent, puis, après retour et réouverture, *From cache 20 · Requested 0*.

**6. Boucle complète (rejeu désactivé dans About).** Plan ▸ 3 courses ▸ Current Location ▸ Calculate ▸ Results (cartes, graphe, carte) ▸ une carte ▸ Itinerary ▸ Save This Plan. Arrêter, relancer.

Terminé quand : le plan apparaît dans *Saved Plans* après la relance.

**7. Localisation refusée.** Réglages du simulateur ▸ Confidentialité et sécurité ▸ Service de localisation ▸ WeatherWindow ▸ Jamais. Revenir et appuyer sur Calculate.

Terminé quand : le message s'affiche avec Retry, et le départ passe sur *Choose Place*.

**8. S'il reste du temps (partie 4).**

- Toucher un point du graphe : la carte change.
- *Remind Me* : la demande d'autorisation apparaît au premier appui, puis la notification s'affiche.
- Refuser une fois : le bouton *Turn On Notifications in Settings* apparaît.

Terminé quand : chaque point est noté fait ou cassé dans le journal.

**9. Clôture.**
```bash
git add -A && git commit -m "Mac 2: MVP loop with real data"
git tag mvp && git push && git push --tags
```
Puis, sous Linux : `git pull` dans `repo-mac-gitlab/`, `Tools/sync-from-gitlab.sh`, commit et push sur GitHub.

Terminé quand : la CI GitHub est verte et le journal du `README.md` a ses 3 lignes (fait / cassé / suivant).

## Questions pour Jason (toujours ouvertes)

- Le P9 est-il jugé sur le MVP du P6 + le Route Nowcast du HD1, et non sur toute la liste du P6 ?
- Les Mac du lab sont-ils accessibles pendant la SWOT vac (26–30 oct.) et la période d'examens ?
- Le rendu GitLab doit-il contenir les tests et le package local (recommandé : oui) ?
