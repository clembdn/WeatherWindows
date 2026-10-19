# Erreurs et cas inattendus — preuves

Tableau du cahier (§13), avec pour chaque ligne **ce que fait l'app** et **comment c'est prouvé**. En entretien : « chaque ligne est soit un test automatique, soit vérifiée dans le simulateur ».

| Situation | Comportement | Preuve |
| --- | --- | --- |
| Pas de réseau | Message « You're offline… » avec Retry ; temps de marche lus dans le cache s'il existe | `noConnectionIsOffline`, `reportsAnOfflineForecast` ; cache : `DirectionsService.walkingMatrix` lit le cache avant tout appel |
| Open-Meteo 5xx | « Weather service unavailable, try again in a minute. » + Retry | `serverErrorBecomesARetryLaterMessage` |
| Open-Meteo 429 | « Too many requests… » | `tooManyRequestsIsRateLimited` |
| Réponse illisible | « The service sent an unexpected answer. » | `unreadableBodyIsAnInvalidResponse`, `rejectsMismatchedArrays` |
| MapKit limite les requêtes | Requêtes envoyées une par une ; une nouvelle tentative après 3 s, puis message. Tracés gardés en mémoire, pas redemandés à chaque toucher du graphe | `DirectionsService.walkingTime`, `savedLines` ; à provoquer au Mac |
| Pas d'itinéraire Apple Maps (hors ligne, replay sans réseau) | La carte trace une ligne droite, le reste de l'écran marche | `DirectionsService.routeLine` ; à provoquer au Mac (Wi-Fi coupé) |
| Aucun planning possible | « Post closes at 13:00, so it can't fit in this window… » | `reportsWhyNothingFits`, `explainsWhichErrandClosesTooEarly`, `adviceExplainsWhenNothingFits` |
| Aucune pluie dans les 30 min | « No rain expected on your walks in the next 30 minutes. » | `advisesLeavingNowWhenDry` ; capture `*-7-next-walk` |
| Images radar trop anciennes | Bascule sur la prévision horaire + message « too old to use » | `engineRefusesStaleRadar`, `fallsBackToTheForecastWhenRadarIsStale` |
| Radar illisible ou absent | Bascule sur la prévision + message, jamais de crash | `rejectsDataThatIsNotPNG` ; bug CgBI trouvé et corrigé grâce aux captures CI |
| Trajet hors de la zone radar (Melbourne) | Bascule sur la prévision + message « The radar only covers the Melbourne area » | `engineIgnoresPlacesOffTheRadarTile` |
| Écran quitté pendant un calcul | Aucun message d'erreur, l'écran revient à son état de départ | `cancellationIsNotReportedAsAnError` |
| Localisation refusée | Départ basculé sur « Choose Place » + message | `switchesToAChosenStartWhenLocationIsDenied` ; à provoquer au Mac (Réglages) |
| Notifications refusées | Message + bouton « Turn On Notifications in Settings » qui ouvre la page Notifications de l'app | `NotificationService.isDenied` ; à provoquer au Mac |
| Heure du rappel déjà passée (toujours le cas en replay) | Rappel dans 5 s, l'heure affichée est celle du rappel | `NotificationService.scheduleReminder` ; à vérifier au Mac |
| Bibliothèque vide | `ContentUnavailableView` avec bouton « Add Errand » | Vu au Mac 2 (premier lancement après suppression de l'app) |
| Nom de course en double | « You already have an errand called “Coles”. » | `rejectsDuplicateNameIgnoringCaseAccentsAndSpaces` ; vu au Mac 2 |
| Course renommée avec le nom d'une autre | Même message ; garder son propre nom reste permis | `editingRejectsAnotherErrandsName` |
| Course modifiée après avoir été planifiée | Le plan enregistré garde l'ancienne copie | `editingErrandKeepsThePlannedCopy` ; vu au Mac 2 |
| Plus de 4 courses cochées | « You can plan up to 4 errands at once. » | `refusesAFifthErrand` |
| Course cochée puis supprimée dans Errands | Sa place est libérée, on peut en cocher une autre | `forgetsADeletedErrand` ; vu au Mac 2 |
| « Save This Plan » appuyé deux fois (ou itinéraire rouvert) | Un seul plan enregistré, « Plan saved » affiché | `savesTheSamePlanOnlyOnce` ; vu au Mac 2 |
| Prévision d'ensemble indisponible (réseau, rejeu) | Repli silencieux sur la prévision décalée, la note des résultats le dit | `scoresWithTheEnsembleWhenItIsAvailable` |
| Ensemble Open-Meteo sans aucun run de pluie | Réponse refusée comme illisible | `rejectsAnEnsembleWithoutRain` |
| Score du radar en direct hors ligne (écran Nowcast Accuracy) | Message + Retry ; les scores déjà enregistrés restent affichés | `LoadState` de `VerificationViewModel` ; à provoquer au Mac |
| Pluie qui arrive sur le prochain trajet | Une seule alerte, pas une toutes les 10 min | `alertsOnceWhenRainHeadsForTheNextWalk` |
| Apple Intelligence absent (Mac sans IA) | La section « Describe It » reste, le pied le dit, la phrase est lue sans IA | `readsASentenceWithoutAppleIntelligence` |
| Apple Intelligence échoue | Formulaire déjà rempli sans IA + message « Apple Intelligence failed: … » | à vérifier au Mac 3 |
| Lieu de la phrase introuvable | Message sous la section, l'utilisateur choisit le lieu à la main | `fillsTheFormFromADescription` (valeurs ramenées dans les bornes) |
| Fermeture avant ouverture, durée trop longue | Message sous le champ, Save désactivé | `rejectsClosingBeforeOpening`, `rejectsDurationLongerThanOpeningHours` |
| Base de données inaccessible | Seul `fatalError` de l'app, comme le modèle Apple : sans stockage, rien n'est utilisable | Lecture du code (`WeatherWindowApp.init`) |

## Accessibilité et apparence

| Exigence | Preuve |
| --- | --- |
| Dynamic Type | Captures `largest-text-*` à chaque push |
| Mode sombre | Captures `dark-*` à chaque push |
| Jamais l'information par la couleur seule | Pluie : icône + texte (`RainBadge`) ; carte : pointillés + légende ; graphe : losange + annotation ; bandeau rejeu : texte |
| VoiceOver | Libellés sur les points du graphe, la carte, la collision view et le curseur ; audit automatique `AccessibilityAuditTests` |
