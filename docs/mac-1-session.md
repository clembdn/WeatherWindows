# Séance Mac 1 — mercredi 7 octobre 2026

But : le projet Xcode existe, le code d'`AppStaging/` y tourne, et les courses persistent après relancement.
Tout le code a déjà été compilé et testé sur iOS par la CI : la séance sert à brancher et à vérifier, pas à écrire.

## Avant de partir (Linux)

- [ ] Créer un jeton GitHub pour pousser depuis le Mac du lab : github.com ▸ Settings ▸ Developer settings ▸ Fine-grained tokens ▸ dépôt `WeatherWindows`, permission *Contents: Read and write*, expiration 7 jours. Le garder sous la main (il remplace le mot de passe au `git push`).
- [ ] `./ww status` : CI Apple verte.

## Au lab, dans l'ordre

**1. Récupérer le dépôt et noter les versions.**
```bash
cd ~/Desktop && git clone https://github.com/clembdn/WeatherWindows.git && cd WeatherWindows
xcodebuild -version
```
Terminé quand : la version d'Xcode est notée dans le journal du `README.md`. Si ce n'est pas Xcode 26.6, me le dire : la CI et Docker s'aligneront dessus.

**2. Créer le projet.** Xcode ▸ File ▸ New ▸ Project ▸ iOS ▸ App.
- Product Name `WeatherWindow`, Team *None*, Organization Identifier `edu.monash.cboudon`
- Interface *SwiftUI*, Language *Swift*, Testing System *Swift Testing with XCTest UI Tests*, Storage *None*
- Enregistrer **dans le dossier `WeatherWindows/`**, case « Create Git repository » **décochée**.

Terminé quand : `WeatherWindows/WeatherWindow/WeatherWindow.xcodeproj` existe et ⌘B compile le modèle vide.

**3. Réglages de la cible `WeatherWindow`.**
- General ▸ Minimum Deployments : iOS 18.0
- Build Settings (rechercher) : *Default Actor Isolation* = MainActor, *Approachable Concurrency* = Yes, *Swift Language Version* = Swift 6
- Info ▸ + ▸ *Privacy - Location When In Use Usage Description* : `WeatherWindow uses your location as the starting point of your errands.`

Terminé quand : les quatre valeurs sont vérifiées.

**4. Ajouter le package local.** File ▸ Add Package Dependencies… ▸ Add Local… ▸ dossier `WeatherWindowKit` ▸ produit `WeatherWindowKit` → cible `WeatherWindow`.

Terminé quand : il apparaît sous *Package Dependencies* dans le navigateur.

**5. Mettre les fichiers préparés à leur place** (Terminal, à la racine du dépôt) :
```bash
rm WeatherWindow/WeatherWindow/ContentView.swift WeatherWindow/WeatherWindow/WeatherWindowApp.swift
cp -R AppStaging/WeatherWindow/ WeatherWindow/WeatherWindow/
rm WeatherWindow/WeatherWindowTests/*.swift WeatherWindow/WeatherWindowUITests/*.swift
cp AppStaging/WeatherWindowTests/*.swift WeatherWindow/WeatherWindowTests/
cp AppStaging/WeatherWindowUITests/*.swift WeatherWindow/WeatherWindowUITests/
git rm -r -q AppStaging
```
Les dossiers sont synchronisés : Xcode voit les fichiers sans rien faire, y compris `Resources/Replay` (la matinée enregistrée pour le mode rejeu).
Si un test signale `No such module 'SolverKit'` : cible `WeatherWindowTests` ▸ Build Phases ▸ Link Binary With Libraries ▸ + ▸ `WeatherWindowKit`.

Terminé quand : ⌘B donne 0 erreur et 0 avertissement. **Commit + push.**

**6. Tests.** ⌘U.

Terminé quand : tous les tests unitaires et les 3 tests de captures passent (ils passent déjà en CI). Sinon, copier l'erreur et me l'envoyer.

**7. Essai dans le simulateur.** Features ▸ Location ▸ Custom Location : −37.8136, 144.9631.
- Ajouter 4 vraies courses par la recherche : Australia Post GPO, Coles Melbourne Central, State Library Victoria, une salle de sport.
- Essayer un doublon (« coles ») : le message apparaît sous le nom.
- Arrêter l'app (■) et la relancer.

Terminé quand : les 4 courses sont toujours là.

**8. Écran de debug.** About ▸ Developer ▸ Walking times and forecast.

Terminé quand : 20 temps de marche et 48 h de prévision s'affichent, puis, après retour et réouverture, *From cache 20 · Requested 0*.

**9. Go/no-go n° 2 (15 min maximum, facultatif).** `VNGenerateOpticalFlowRequest` sur deux images radar dans le simulateur. Si ça ne tourne pas : abandon définitif, le block matching suffit.

Terminé quand : le résultat est noté dans le `README.md`.

**10. Clôture.**
```bash
git add -A && git commit -m "Mac 1: Xcode project, errand library, services"
git tag mac-1 && git push && git push --tags
```
Terminé quand : la CI Apple est verte sur GitHub avec le job *app* (captures dans l'artifact `screenshots`), et le journal du `README.md` a ses 3 lignes (fait / cassé / suivant).

Rappel : commit + push **toutes les heures**, jamais de travail laissé seulement sur le Mac du lab.

## Questions pour Jason

- Le P9 est-il jugé sur le MVP du P6 + le Route Nowcast du HD1, et non sur toute la liste du P6 ?
- Les Mac du lab sont-ils accessibles pendant la SWOT vac (26–30 oct.) et la période d'examens ?
- Le rendu GitLab doit-il contenir les tests et le package local (recommandé : oui) ?
