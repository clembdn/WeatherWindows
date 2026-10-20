# Séance Mac 3 (la dernière) — jeudi 22 octobre 2026

But : vérifier à la main ce que la CI ne peut pas voir, puis répéter la démo, qui se fera en direct à l'entretien. La séance se termine par le tag `final`.

Après cette séance, il n'y a plus de Mac. La CI GitHub (`macos-26`) continue de compiler, lancer les tests et faire les captures : une petite correction reste possible, mais elle ne pourra plus être vérifiée à la main.

## Avant de partir (Linux)

- [ ] Pousser sur GitHub, puis `./ww status` : CI *Apple* verte. `./ww screenshots` pour voir les cartes et le formulaire.
- [ ] Pousser sur GitLab.
- [ ] Relire « Ce qui a changé » ci-dessous, puis les sections « Les tracés », « Les notifications » et « Apple Intelligence » de `docs/explication-du-code.md`.

## Ce qui a changé depuis le Mac 2

| Avant | Maintenant | À dire en une phrase |
| --- | --- | --- |
| Carte Next Walk en lignes droites, point orange qui traverse les bâtiments | Tracés Apple Maps ; le point orange avance sur la rue (`RouteSplitter.point(on:at:)`) | « La collision view charge les tracés comme `RouteMapView`. » |
| Replay en lignes droites ; chaque toucher du graphe redemandait les tracés | `DirectionsService.routeLine` partagé par Live et Replay, tracés gardés dans un dictionnaire | « Apple Maps limite à environ 50 requêtes par minute, donc je garde les tracés déjà reçus. » |
| Rappel jamais affiché en replay (heure du 3 octobre) | `UNTimeIntervalNotificationTrigger` de `max(5, secondes restantes)` | « En replay, l'heure de départ est dans le passé, donc le rappel arrive dans 5 secondes. » |
| Le bouton Réglages ouvrait la page générale de l'app | Il ouvre la page Notifications | |
| Écarts au cahier : but d'About en une phrase, crédit Open-Meteo seulement dans About, plan par défaut pas mis en avant sur le graphe, pas de message pour un nom vide ou un lieu absent, curseur sans la pluie pour VoiceOver | Deux phrases ; crédit sous la prévision ; plan par défaut en losange ; « Enter a name… » et « Choose a place… » ; carte de pluie réglable avec VoiceOver | « VoiceOver : on glisse vers le haut sur la carte, elle avance de 5 min et lit la pluie à ta position. » |
| « Describe It » : erreur avalée, formulaire vide | Formulaire d'abord rempli sans IA (`fill(fromSentence:)`), puis par Apple Intelligence si elle répond ; sinon message avec l'erreur | « Même sans Apple Intelligence, le nom et les nombres de la phrase remplissent le formulaire. » |

## Au lab, dans l'ordre

**1. Récupérer et compiler.** `git pull` dans le clone GitLab, puis ouvrir `WeatherWindow.xcodeproj`.

Terminé quand : ⌘B donne 0 erreur et 0 avertissement. Sinon, noter l'erreur exacte (fichier:ligne) et me l'envoyer.

**2. Tests.** ⌘U.

Terminé quand : tout est vert, y compris `findsThePointPartWayAlongARoute` et `readsASentenceWithoutAppleIntelligence`.

**3. Tracés en replay.** Wi-Fi du Mac allumé. About ▸ *Replay a recorded rainy morning*. Plan ▸ 3 courses ▸ Calculate ▸ Results ▸ une carte ▸ Itinerary ▸ *Check the Radar Before Leaving*.

Terminé quand :
- les tracés suivent les rues dans Results, Itinerary et Next Walk (Map et Radar Grid) ;
- en glissant le curseur, le point orange suit la rue ;
- après 10 touchers sur le graphe, le tracé reste dans les rues.

**4. Tracés et radar en direct.** Replay désactivé. Features ▸ Location ▸ Custom Location : −37.8136, 144.9631. Mêmes écrans avec 3 vraies courses.

Terminé quand : les tracés suivent les rues, et Next Walk n'affiche pas « No radar images are available ».

**4 bis. Next 7 Days.** Toujours sans replay : Results ▸ *Compare the Next 7 Days*. Puis avec le replay activé.

Terminé quand :
- 7 jours en direct (2 en replay), une seule ligne « Driest Day » ;
- toucher un jour ouvre ses Results, avec des heures de ce jour-là ;
- VoiceOver lit chaque ligne d'un coup (jour, départ, pluie).

**5. Apple Intelligence.** Errands ▸ + ▸ taper « Post office, 10 min, open 9 to 5 » ▸ *Fill In the Form*.

Terminé quand : le nom, 10 min, 9:00–17:00 et un lieu sont remplis. Noter mot pour mot le message rouge (« Apple Intelligence failed: … ») s'il y en a un, et le pied de la section.

**6. Notifications** (replay activé).
- Itinerary ▸ *Remind Me* : « Reminder set for » avec l'heure actuelle + 5 s, puis la bannière arrive.
- Next Walk : la carte affiche « Leave now » ou « Wait », et *Remind Me* quand il faut attendre.
- Next Walk ▸ *Alert Me If Rain Is Coming* : la bannière « Rain is coming » arrive si le prochain trajet est pluvieux.
- Réglages du simulateur ▸ Notifications ▸ WeatherWindow ▸ désactiver, revenir et toucher *Remind Me* : le bouton *Turn On Notifications in Settings* apparaît. Le toucher : la page Notifications de l'app s'ouvre.

Terminé quand : chaque point est noté fait ou cassé.

**7. Situations d'erreur, sans plantage.** Couper le Wi-Fi du Mac.
- Replay désactivé ▸ Calculate : « You're offline » avec Retry.
- Replay activé : tout marche, avec des tracés droits (c'est normal).
- About ▸ précision du nowcast ▸ 2 dernières heures : message et Retry.

Rallumer le Wi-Fi.

Terminé quand : aucun plantage, et chaque message est noté.

**8. Accessibilité.** Xcode ▸ Open Developer Tool ▸ Accessibility Inspector, cible : le simulateur.
- *Run Audit* sur Plan, Results, Itinerary, Next Walk et New Errand.
- Pointeur d'inspection : écouter un point du graphe, la carte du trajet, la carte de pluie et le curseur.
- VoiceOver sur la carte de pluie (Next Walk) : glisser vers le haut, l'heure avance de 5 min, et la pluie à ta position est lue.
- Results : sans rien toucher, le plan affiché est en losange sur le graphe.
- Texte au maximum (panneau Settings de l'Inspector), puis About ▸ Appearance ▸ Dark.

Terminé quand : aucun problème bloquant, ou chaque problème est noté (écran, élément).

**9. Répétition de la démo en direct** (replay activé). Environ 3 min, chronométrées, dans cet ordre :
1. Errands ▸ « Describe It » ;
2. Plan, 3 courses ▸ Calculate ;
3. Results : toucher le graphe, la carte change, puis *Compare the Next 7 Days* ;
4. Itinerary ▸ *Remind Me* ▸ bannière ;
5. Next Walk : conseil, curseur, Map puis Radar Grid ;
6. About ▸ précision du nowcast.

Terminé quand : les 6 points passent d'un trait en moins de 3 min, sans hésiter sur un bouton.

**10. Modification en direct.** Faire une ligne du tableau §9 de `docs/explication-du-code.md` (par exemple des départs toutes les 10 min), ⌘R, puis `git checkout .` pour annuler.

Terminé quand : c'est fait en moins de 5 minutes.

**11. Clôture.**
```bash
git add -A && git commit -m "Mac 3: routes, reminders and Apple Intelligence checked"
git tag final && git push && git push --tags
```
Puis, sous Linux : `git pull` dans `repo-mac-gitlab/`, `Tools/sync-from-gitlab.sh`, commit et push sur GitHub. Ensuite, cocher `ROADMAP.md` et ajouter la ligne `final` au journal du `README.md`.

Terminé quand : la CI GitHub est verte et le journal a ses 3 colonnes (fait / cassé / suivant).

## Si quelque chose casse

Noter l'écran, l'action et le message exact, et faire une capture (⌘S dans le simulateur). La correction se fera sous Linux et sera vérifiée par la CI GitHub.

## Questions pour Jason

- L'entretien (2–13 nov.) se fait-il sur un Mac du lab ? Sinon, sur quelle machine faire la démo en direct ?
- Faut-il modifier le code en direct pendant l'entretien, et sur quelle machine ?
