# Erreurs et cas inattendus — preuves

Tableau du cahier (§13), avec pour chaque ligne **ce que fait l'app** et **comment c'est prouvé**. En entretien : « chaque ligne est soit un test automatique, soit vérifiée dans le simulateur ».

| Situation | Comportement | Preuve |
| --- | --- | --- |
| Pas de réseau | Message « You're offline… » avec Retry ; temps de marche lus dans le cache s'il existe | `noConnectionIsOffline`, `reportsAnOfflineForecast` ; cache : `WalkingMatrixBuilder` lit le cache avant tout appel |
| Open-Meteo 5xx | « Weather service unavailable, try again in a minute. » + Retry | `serverErrorBecomesARetryLaterMessage` |
| Open-Meteo 429 | « Too many requests… » | `tooManyRequestsIsRateLimited` |
| Réponse illisible | « The service sent an unexpected answer. » | `unreadableBodyIsAnInvalidResponse`, `rejectsMismatchedArrays` |
| MapKit limite les requêtes | Deux nouvelles tentatives (2 s, 5 s), 3 requêtes en parallèle au plus, puis message | `DirectionsService` ; à provoquer au Mac |
| Aucun planning possible | « Post closes at 13:00, so it can't fit in this window… » | `reportsWhyNothingFits`, `explainsWhichErrandClosesTooEarly`, `adviceExplainsWhenNothingFits` |
| Aucune pluie dans les 30 min | « No rain expected on your walks in the next 30 minutes. » | `advisesLeavingNowWhenDry` ; capture `*-7-next-walk` |
| Images radar trop anciennes | Bascule sur la prévision horaire + message « too old to use » | `engineRefusesStaleRadar`, `fallsBackToTheForecastWhenRadarIsStale` |
| Radar illisible ou absent | Bascule sur la prévision + message, jamais de crash | `rejectsDataThatIsNotPNG` ; bug CgBI trouvé et corrigé grâce aux captures CI |
| Localisation refusée | Départ basculé sur « Choose Place » + message | `switchesToAChosenStartWhenLocationIsDenied` ; à provoquer au Mac (Réglages) |
| Notifications refusées | Message + bouton « Turn On Notifications in Settings » | `NotificationService.isDenied` ; à provoquer au Mac |
| Bibliothèque vide | `ContentUnavailableView` avec bouton « Add Errand » | À voir au Mac (premier lancement) |
| Nom de course en double | « You already have an errand called “Coles”. » | `rejectsDuplicateNameIgnoringCaseAccentsAndSpaces`, `duplicateMessageClearsWhenNameChanges` |
| Plus de 4 courses cochées | « You can plan up to 4 errands at once. » | `refusesAFifthErrand` |
| Fermeture avant ouverture, durée trop longue | Message sous le champ, Save désactivé | `rejectsClosingBeforeOpening`, `rejectsDurationLongerThanOpeningHours` |
| Base de données inaccessible | Seul `fatalError` de l'app, comme le modèle Apple : sans stockage, rien n'est utilisable | Lecture du code (`WeatherWindowApp.init`) |

## Accessibilité et apparence

| Exigence | Preuve |
| --- | --- |
| Dynamic Type | Captures `largest-text-*` à chaque push |
| Mode sombre | Captures `dark-*` à chaque push |
| Jamais l'information par la couleur seule | Pluie : icône + texte (`RainBadge`) ; carte : pointillés + légende ; graphe : losange + annotation ; bandeau rejeu : texte |
| VoiceOver | Libellés sur les points du graphe, la carte, la collision view et le curseur ; audit automatique `AccessibilityAuditTests` |
