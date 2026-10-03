# WeatherWindow roadmap

Read by `./ww status`. Tick a box only when it is really true. Part headings use
`## Part — Name · Where · due YYYY-MM-DD`; `Tests:` lists the tests named in the spec.

## Part 0 — Setup · Linux · due 2026-10-06
- [x] Repository layout, README, specification in docs/
- [x] WeatherWindowKit builds and swift test is green on Linux (Swift 6.4 and 6.3.3)
- [x] Radar PNG decoder in pure Swift, identical to Pillow on a real tile
- [x] Swift tools: ww record, ww sync-radar, ww status
- [x] CI workflows written: Kit (Linux), Apple, Radar backup
- [x] CI green on GitHub, Linux and macOS
- [x] Radar cron running every 30 minutes
- [ ] At least one full rainy day recorded near the CBD
Tests: geoPointRoundTripsThroughJSON, melbourneTimeZoneIsAvailable, paletteMapsUniversalBlueColors, decodesRecordedTile, undoesEveryRowFilter

## Part 1 — SolverKit · Linux · due 2026-10-06
- [x] Solver types: Stop, Node, PlanRequest, ScoredSchedule, SolveOutcome
- [x] Day simulation with waiting before opening and rejection after closing
- [x] Per-minute leg sampling and exposure score
- [x] Robust score over shifted scenarios (−30, −15, 0, +15, +30 min)
- [x] Pareto frontier, duration measured from the start of the window
- [x] Two hand-computed reference cases (documented as tables in the tests)
Tests: waitsWhenArrivingBeforeOpening, rejectsTaskEndingAfterClosing, splitsLegAcrossHourBoundary, enumeratesAllOrders, dryForecastGivesZeroExposure, robustScoreIsWorstScenario, paretoDropsDominated, reportsWhyNothingFits, handComputedCaseA, handComputedCaseB

## Part 2a — ForecastKit · Linux · due 2026-10-06
- [x] Real Open-Meteo and RainViewer responses saved as fixtures
- [x] RainViewerMaps decoding and tile URL
- [x] OpenMeteoHourlyResponse with a hand-written init(from:) zipping the parallel arrays
- [x] Open-Meteo URL built with URLComponents (timeformat=unixtime)
- [x] HourlyRainField conforming to RainField
Tests: decodesHourlyFixture, toleratesNullValues, rejectsMismatchedArrays, rainWeightExamples, buildsTileURL

## Part 2b — Data and services · Mac 1 · due 2026-10-07
- [x] App sources for Mac 1 written in AppStaging/, compiled and tested by CI on iOS
- [ ] Xcode project (iOS 18, Swift Testing), local package added, concurrency settings checked
- [ ] NSLocationWhenInUseUsageDescription set
- [ ] SwiftData models: SavedErrand, DayPlan, PlannedStop, CachedWalkingTime
- [ ] ErrandStore with duplicate detection (AddErrandResult)
- [ ] OpenMeteoService, PlaceSearchService, DirectionsService, LocationService
- [ ] Errand library: errands persist after relaunch
- [ ] Debug screen: 20 walking times and 48 h forecast, matrix read from cache on relaunch
Tests: addsErrand, rejectsDuplicateNameIgnoringCaseAccentsAndSpaces, deletingPlanDeletesItsStops, deletingErrandKeepsThePlannedCopy, needsANameAndAPlace, rejectsClosingBeforeOpening, rejectsDurationLongerThanOpeningHours

## Part 3 — MVP interface · Mac 2 · due 2026-10-14
- [ ] TabView (Plan, Errands, About), one NavigationStack per tab
- [ ] LoadState in every view model: loading, content, error with Retry
- [ ] Errand form with validation messages under the faulty field
- [ ] Place search with live suggestions and empty or offline messages
- [ ] Day plan: 1 to 4 errands, start, end, departure window
- [ ] Results: fastest and driest cards, frontier list, infeasible reason
- [ ] Itinerary with dry or rainy legs and Save plan
- [ ] Full loop in the simulator with 3 real places, tag mvp

## Part 4 — Chart, map, notification · Mac 2–3 · due 2026-10-21
- [ ] Trade-off chart with tap selection and a VoiceOver label per point
- [ ] Route map: real polylines, rainy legs coloured, dashed and labelled
- [ ] Departure notification: permission on first tap, Settings link on refusal

## Part 5 — NowcastKit · Linux · due 2026-10-20
- [x] Radar PNG decoder shared by Linux tests and the app
- [ ] RainGrid with tile, time and bilinear sampling
- [ ] Georeference (spherical Mercator)
- [ ] Block matching motion estimator with median filter and global fallback
- [ ] Semi-Lagrangian advection to 30 min on the cropped area
- [ ] NowcastRainField blended with the hourly forecast
- [ ] Verifier: nowcast beats persistence at 20 min on a recorded day
Tests: georeferencesMelbourneCBD, convertsReflectivityToRainRate, recoversUniformShift, zeroMotionKeepsFrame, predictsMovingDisc, fallsBackToGlobalVector, csiBounds, beatsPersistenceOnRecordedDay

## Part 6 — Nowcast in the app · Mac 3 · due 2026-10-21
- [ ] LiveRainViewerSource and NowcastService actor, stale radar falls back to the forecast
- [ ] Departure advice card (go now or wait) with reminder
- [ ] Collision view (MKMapView overlay, or Canvas plan B) with time scrubber
- [ ] Replay mode with a permanent banner

## Part 7 — Finish · Mac 4–5 · due 2026-11-04
- [ ] About screen complete: identity, data credits, methods, AI statement
- [ ] Every error situation provoked in the simulator without a crash
- [ ] VoiceOver, largest Dynamic Type and dark mode checked on every screen
- [ ] Zero compiler warnings, no print, final README
- [ ] Backup demo video recorded
- [ ] Live code changes rehearsed

## Calendar
- [ ] 2026-10-07 · Mac 1 · Xcode project, SwiftData models, errand library
- [ ] 2026-10-14 · Mac 2 · Real services, Plan and Results screens, tag mvp
- [ ] 2026-10-21 · Mac 3 · Nowcast service, advice card, collision view
- [ ] 2026-10-23 · End of classes
- [ ] 2026-10-28 · Mac 4 (to confirm) · Notification, About, error table, accessibility, demo video
- [ ] 2026-11-02 · Demo window opens · interviews until 13 Nov
- [ ] 2026-11-04 · Mac 5 (to confirm) · Rehearsal, fixes, bonus
