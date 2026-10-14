# WeatherWindow

WeatherWindow picks the **order** and **departure time** of 3–4 walking errands so that the walks between them stay as dry as possible, while respecting opening hours and how long each errand takes. Beyond one hour it uses the Open-Meteo hourly forecast; within 30 minutes it extrapolates RainViewer radar images along your route (Route Nowcast).

FIT3178 Custom App (P9) — Clement Boudon, Student ID 37465848, Monash University, S2 2026.

## Repository map

| Path | Content |
| --- | --- |
| `WeatherWindowKit/` | Swift package, pure Swift + Foundation, built and tested on Linux and Apple platforms |
| `WeatherWindowKit/Sources/WeatherWindowCore` | Shared types: `GeoPoint`, `RainField`, `RadarTile`, `RouteGeometry` |
| `WeatherWindowKit/Sources/ForecastKit` | Open-Meteo (hourly and ensemble) and RainViewer decoding, hourly rain field |
| `WeatherWindowKit/Sources/SolverKit` | Day simulation, robust score, Pareto frontier |
| `WeatherWindowKit/Sources/NowcastKit` | Radar grids, georeference, motion estimation, advection, verification |
| `repo-mac-gitlab/` (not tracked here) | The real Xcode project, in the Monash GitLab repository `fit3178-cbou0034/weatherwindow`, created in Mac session 1 |
| `AppStaging/` | Copy of the GitLab app sources and tests (`Tools/sync-from-gitlab.sh`); CI compiles, tests and screenshots them |
| `ci/preview/` | CI-only XcodeGen spec that wraps `AppStaging/` to run UI tests and take screenshots |
| `Tools/` | Swift command-line tools (`ww`), Docker wrapper for Swift 6.3.3 |
| `ROADMAP.md` | Parts, "done when" checklists, spec tests and calendar, read by `./ww status` |
| `docs/cahier-des-charges.md` | Development specification (French) |

## Build and test

```bash
# Swift package (Linux or macOS)
cd WeatherWindowKit && swift test

# Same Swift version as CI and Xcode 26 (Swift 6.3.3, needs Docker)
Tools/swift.sh test

# Command-line tools
cd Tools && swift test

# iOS app (macOS only), in the GitLab clone
open repo-mac-gitlab/WeatherWindow.xcodeproj

# After a Mac session: copy the GitLab sources here so GitHub CI builds the same files
Tools/sync-from-gitlab.sh
```

## Continuous integration

| Workflow | Runs on | Trigger | Checks |
| --- | --- | --- | --- |
| `Kit (Linux)` | `swift:6.3.3-noble` | every push | package builds with warnings as errors, all tests pass; tools tests |
| `Apple` | `macos-26`, Xcode 26.6 | PRs to `main`, pushes to `main`, manual | package tests on macOS, package builds for iOS Simulator, app unit tests on an iPhone simulator, UI tests with screenshots (light, dark, largest text) |
| `Radar backup` | `ubuntu-latest` | hourly | records radar frames as a 90-day artifact |

## Progress and tools

Everything is Swift; `./ww` builds the tools package on first use.

```bash
./ww status          # roadmap, spec tests, CI, radar recordings, git — one screen
./ww status --test   # same, after running the package tests
./ww record          # download new radar frames (cron runs this every 30 minutes)
./ww sync-radar      # import the frames saved by the hourly GitHub backup
./ww verify          # replay recorded days: nowcast vs persistence (CSI) at 10, 20, 30 min
./ww screenshots     # download the app screenshots taken by CI into screenshots/
```

Cron entry:

```cron
*/30 * * * * cd /path/to/WeatherWindows && ./ww record >> recordings/cron.log 2>&1
```

## Radar recording

The replay demo needs recorded rainy days. Frames are stored in `recordings/YYYY-MM-DD/<unix time>.png` (Melbourne local day, git-ignored). Each day's `index.json` keeps the download delay and rain statistics (share of the tile and of a 10 km area around the CBD above 20 dBZ, peak dBZ).

Tile: zoom 7, x 115, y 78, 512 px, Universal Blue (scheme 2), no smoothing, no snow. The palette `WeatherWindowKit/Sources/NowcastKit/Resources/rainviewer_colors.csv` is RainViewer's published colour table, used by the same pure-Swift PNG decoder in the tests, the tools and the app. Universal Blue gives a distinct colour to every value from −10 to 64 dBZ; above that colours repeat and decode to the lowest dBZ (65 or 75), which already means full rain weight. No echo decodes to −32 dBZ.

## Patterns reused from the labs

| Lab pattern | Where it returns in WeatherWindow |
| --- | --- |
| `List`, `Form`, navigation (Lab 3) | Errand library, errand form, day planning |
| SwiftData `@Model`, `@Query`, `ModelContext` (Lab 5) | `SavedErrand` (with a `UUID` id like `StoredBook`), `DayPlan`, `PlannedStop`, `CachedWalkingTime` |
| `URLSession` + `Decodable` + async/await, `@Observable` view model (Lab 5) | `OpenMeteoService`, `LiveRainViewerSource`, `DayPlanViewModel`, `NextWalkViewModel`, `ErrandFormModel` |
| Store with a result enum (Lab 3 `HeroStore`) | `ErrandStore.add` and `update` return `SaveErrandResult` (saved, duplicate name, failed) |
| `TabView`, typed `LocalizedError` (Week 6 Campus Questboard) | Main tabs, `ServiceError` |
| MapKit, `CLLocationManager` provider (Lab 7) | Place search, walking times, route map; `LocationService` is the Lab 7 `LocationProvider` made `async` |
| Swift Charts (Lab 9) | Time-versus-rain trade-off chart, nowcast accuracy chart |

## Before each Wednesday Mac session

- [ ] `swift test` is green in `WeatherWindowKit`, and `Tools/swift.sh test` too.
- [ ] The `Apple` workflow is green on the open PR.
- [ ] The SwiftUI files for the session are written.
- [ ] A 5–8 item session checklist exists, each with a "done when".
- [ ] Questions for Jason are written down.

## Mac session log

| Tag | Date | Done | Broken | Next |
| --- | --- | --- | --- | --- |
| `mac-1` | 7 Oct 2026 | Xcode project on GitLab (iOS 18, Swift 6, MainActor isolation, local package), location permission, errand library; typed address searched on Return, start place remembered | `import ForecastKit` missing in a test (member import visibility), one main actor warning in the collision view, both fixed | Mac 2: real services, full loop, tag `mvp` (checklist in `docs/mac-2-session.md`) |
| `mvp` | 14 Oct 2026 | Full loop in the simulator with real data: 4 errands searched in Apple Maps, edit and duplicate check, walking times cached (20 from cache, 0 requested), plan calculated, saved once and kept after relaunch, location refused falls back to a chosen start, chart selection and departure reminder. Then the bonus branch merged and checked: nowcast accuracy, ensemble, usual choice, sharing, rain alert, radar map | Errand from a sentence (Foundation Models) still to fix on the lab Mac | Mac 3: live radar, notification banners, error situations, VoiceOver and Dynamic Type |

## Credits

- Weather data: [Open-Meteo](https://open-meteo.com) (CC BY 4.0).
- Radar: [RainViewer](https://www.rainviewer.com/api.html) (personal and educational use).
- Maps and walking times: Apple Maps / MapKit.
- No third-party libraries; PNG inflation uses the system zlib.
- Generative AI was used during development; see the About screen for the full statement.
