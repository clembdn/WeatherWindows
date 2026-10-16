# WeatherWindow

FIT3178 Custom App: Clement Boudon, Student ID 37465848, Monash University, S2 2026.

WeatherWindow picks the order and departure time of 1 to 4 walking errands so the walks between them stay as dry as possible, while respecting opening hours and how long each errand takes. It uses the Open-Meteo hourly forecast and, within 30 minutes, RainViewer radar images extrapolated along the route (Route Nowcast).

## Features

- **Errands**: a library of errands saved with SwiftData. Each errand has a place found with Apple Maps search, a duration and opening hours. Tap an errand to edit it, swipe to delete it. Duplicate names are refused, ignoring case, accents and spaces. On iOS 26 with Apple Intelligence, an errand can also be described in one sentence ("post office, 10 min, open 9 to 5"), and the on-device Foundation Models framework fills in the form.
- **Plan**: choose 1 to 4 errands, a start (current location or a chosen place), an end and a departure window, then tap Calculate.
- **Results**: the fastest and the driest plans, a time-versus-rain chart (Swift Charts) of every plan that no other plan beats on both, and the route map with rainy stretches dashed. Once two plans have been saved, the app also suggests "your usual choice", the trade-off you usually save.
- **Robust scores**: each plan is scored against five scenarios and keeps the worst. By default these are the hourly forecast shifted 15 and 30 minutes earlier and later. With the About setting, they are five of the 40 runs of the Open-Meteo ensemble forecast, from the driest to the wettest.
- **Itinerary**: each walk with its rain and each errand with its arrival, wait and departure. You can set a departure reminder, share the plan as text and save it. Saved plans keep their own copy of the errands, so editing or deleting an errand never changes them.
- **Check the radar before leaving**: radar motion is measured and extrapolated 30 minutes ahead along the next walk. The app then advises leaving now or waiting. A time slider shows the rain crossing the route, either on an Apple map or on a plain radar grid that also works offline. While the screen is open, an optional alert notifies you when rain heads for your next walk.
- **Nowcast accuracy** (About): replays the recorded rainy day or the last 2 hours of live radar, and compares the nowcast with persistence (the rain does not move) using the Critical Success Index at 10, 20 and 30 minutes. A chart shows the scores, which are kept in SwiftData.
- **Replay mode**: a recorded rainy morning (3 October 2026, 83 radar images) with a frozen clock. It works offline for the demo, and a permanent banner says the weather is recorded.

## Build and run

1. Open `WeatherWindow.xcodeproj` in Xcode 26 (iOS 18 target, Swift 6, main actor default isolation).
2. Pick an iPhone simulator and press ⌘R.
3. In the simulator, set Features ▸ Location ▸ Custom Location to −37.8136, 144.9631 (Melbourne CBD).
4. Without network or rain, turn on About ▸ *Replay a recorded rainy morning*.

Everything is in the app target: no package and no third-party library.

## Tests

⌘U in Xcode runs:

- the unit tests (Swift Testing): planner, forecast decoding, radar nowcast, view models, errand store and services;
- the UI tests: screenshots in light, dark and largest text, and Apple's accessibility audit.

## Structure

| Folder | Content |
| --- | --- |
| `WeatherWindow/App` | `WeatherWindowApp` (SwiftData container) and `RootView` (tabs and replay banner) |
| `WeatherWindow/Screens/Plan` | Plan tab: `DayPlanView` + `DayPlanViewModel` (the Calculate button, `PlanResult`), `ResultsView`, `TradeOffChart`, `RouteMapView`, `ItineraryView`, `SavedPlanView` |
| `WeatherWindow/Screens/NextWalk` | "Check the radar before leaving": `NextWalkView` + `NextWalkViewModel`, `DepartureAdviceCard`, `CollisionView`, `RadarMapView`, `RainColor` |
| `WeatherWindow/Screens/Errands` | Errands tab: `ErrandListView`, `ErrandFormView` + `ErrandFormModel`, `PlaceSearchView` |
| `WeatherWindow/Screens/About` | About tab: `AboutView`, nowcast accuracy (`VerificationView` + `VerificationViewModel`), `DebugView` |
| `WeatherWindow/Screens/Common` | Small views shared by several screens (`RainBadge`, `ErrorRow`, `ReplayBanner`…) |
| `WeatherWindow/Database` | SwiftData models (`SavedErrand`, `DayPlan`, `PlannedStop`, `CachedWalkingTime`, `VerificationScore`), `ErrandStore`, `SampleData` |
| `WeatherWindow/Services` | The outside world: `OpenMeteoService`, `RainViewerService`, `DirectionsService`, `LocationService`, `PlaceSearchService`, `NotificationService`, `ErrandAssistant`, and `PlanDataSource` (`LiveData`, `ReplayData`) |
| `WeatherWindow/Planner` | The planning algorithm: `Planner` tries every order and departure, `Schedule`, `Walk`, `Stop`, `Waypoint`, `TradeOffs`, `WalkRain`, `DepartureAdvisor` |
| `WeatherWindow/Rain` | "How much rain here at this minute?": the `RainForecast` protocol, `HourlyForecast`, `ShiftedForecast`, `Ensemble`, `ForecastHour` |
| `WeatherWindow/Radar` | Radar nowcast: `PNGImage`, `RadarTileDecoder`, `RadarColorTable`, `RainGrid`, `PixelConverter`, `MotionFinder`, `RainMover`, `NowcastMaker`, `RadarForecast`, `NowcastScorer`, `RecordedRadar` |
| `WeatherWindow/Helpers` | `GeoPoint`, `Melbourne` time zone, `PlanText`, `ServiceError`, `LoadState`, `RouteSplitter` |
| `WeatherWindow/Resources` | The 83 radar tiles and the forecast recorded on 3 October 2026, and RainViewer's colour table |
| `WeatherWindowTests`, `WeatherWindowUITests` | Unit tests and UI tests |

## Patterns reused from the labs

| Lab pattern | Where it returns in WeatherWindow |
| --- | --- |
| `List`, `Form`, navigation (Lab 3) | Errand library, errand form, day planning |
| Store with a result enum (Lab 3 `HeroStore`) | `ErrandStore.add` and `update` return `SaveErrandResult` (saved, duplicate name, failed) |
| SwiftData `@Model`, `@Query`, `ModelContext` (Lab 5) | `SavedErrand` (with a `UUID` id like `StoredBook`), `DayPlan`, `PlannedStop`, `CachedWalkingTime` |
| `URLSession` + `Decodable` with `CodingKeys` + async/await, `@Observable` view model (Lab 5) | `OpenMeteoService` (`OpenMeteoResponse`, `HourlyData`), `RainViewerService`, `DayPlanViewModel`, `NextWalkViewModel`, `ErrandFormModel` |
| `TabView`, typed `LocalizedError` (Week 6 Campus Questboard) | Main tabs, `ServiceError` |
| MapKit, `CLLocationManager` provider (Lab 7) | Place search, walking times, route map; `LocationService` is the Lab 7 `LocationProvider` made `async` |
| Swift Charts (Lab 9) | Time-versus-rain trade-off chart, nowcast accuracy chart |

## Credits

- Weather data: [Open-Meteo](https://open-meteo.com) forecast and ensemble APIs (CC BY 4.0).
- Radar: [RainViewer](https://www.rainviewer.com/api.html) (personal and educational use).
- Maps, place search and walking times: Apple Maps / MapKit.
- Methods:
  - Germann & Zawadzki (2002), [doi:10.1175/1520-0493(2002)130<2859:SDOTPO>2.0.CO;2](https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2)
  - Pulkkinen et al. (2019), pysteps, [doi:10.5194/gmd-12-4185-2019](https://doi.org/10.5194/gmd-12-4185-2019)
  - Staniforth & Côté (1991), [doi:10.1175/1520-0493(1991)119<2206:SLISFA>2.0.CO;2](https://doi.org/10.1175/1520-0493(1991)119%3C2206:SLISFA%3E2.0.CO;2)
  - Marshall & Palmer (1948), [doi:10.1175/1520-0469(1948)005<0165:TDORWS>2.0.CO;2](https://doi.org/10.1175/1520-0469(1948)005%3C0165:TDORWS%3E2.0.CO;2)
  - Wilks (2019), [doi:10.1016/C2017-0-03921-6](https://doi.org/10.1016/C2017-0-03921-6)
- No third-party libraries. Radar images are decoded with the system zlib.
- Generative AI (Claude, Anthropic) helped design and write parts of the code, tests and documentation. Every file was reviewed, run and can be explained by the author. The full statement is on the About screen.

## Mac session log

| Tag | Date | Done | Broken | Next |
| --- | --- | --- | --- | --- |
| `mac-1` | 7 Oct 2026 | Xcode project (iOS 18, Swift 6, MainActor isolation, local package), location permission, errand library; typed address searched on Return, start place remembered | `import ForecastKit` missing in a test (member import visibility), one main actor warning in the collision view, both fixed | Mac 2: real services, full loop, tag `mvp` |
| `mvp` | 14 Oct 2026 | Full loop in the simulator with real data: 4 errands searched in Apple Maps, edit and duplicate check, walking times cached (20 from cache, 0 requested), plan calculated, saved once and kept after relaunch, location refused falls back to a chosen start, chart selection and departure reminder | Nothing | Bonus branch: nowcast accuracy, ensemble, radar map, rain alert, errand from a sentence |
