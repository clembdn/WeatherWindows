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
- [x] At least one full rainy day recorded near the CBD
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
- [x] Xcode project (iOS 18, Swift Testing), local package added, concurrency settings checked
- [x] NSLocationWhenInUseUsageDescription set
- [x] SwiftData models: SavedErrand, DayPlan, PlannedStop, CachedWalkingTime
- [x] ErrandStore with duplicate detection (SaveErrandResult, also used when editing)
- [x] OpenMeteoService, PlaceSearchService, DirectionsService, LocationService
- [x] Errand library: errands persist after relaunch
- [x] Debug screen: 20 walking times and 48 h forecast, matrix read from cache on relaunch
Tests: addsErrand, rejectsDuplicateNameIgnoringCaseAccentsAndSpaces, deletingPlanDeletesItsStops, deletingErrandKeepsThePlannedCopy, needsANameAndAPlace, rejectsClosingBeforeOpening, rejectsDurationLongerThanOpeningHours, editingErrandKeepsThePlannedCopy, editingRejectsAnotherErrandsName, fillsTheFormFromAnErrand

## Part 3 — MVP interface · Mac 2 · due 2026-10-14
- [x] Plan, Results, Itinerary and saved plans written in AppStaging/, tested and screenshotted by CI
- [x] TabView (Plan, Errands, About), one NavigationStack per tab
- [x] LoadState in every view model: loading, content, error with Retry
- [x] Errand form with validation messages under the faulty field
- [x] Place search with live suggestions and empty or offline messages
- [x] Day plan: 1 to 4 errands, start, end, departure window
- [x] Results: fastest and driest cards, frontier list, infeasible reason
- [x] Itinerary with dry or rainy legs and Save plan
- [x] Full loop in the simulator with 3 real places, tag mvp
Tests: refusesAFifthErrand, calculatesAFrontierWithFakeServices, reportsAnOfflineForecast, switchesToAChosenStartWhenLocationIsDenied, explainsWhichErrandClosesTooEarly, savesTheChosenScheduleWithCopiedStops, forgetsADeletedErrand, savesTheSamePlanOnlyOnce

## Part 4 — Chart, map, notification · Mac 2–3 · due 2026-10-21
- [x] Chart, route map and reminders written in AppStaging/, compiled and screenshotted by CI
- [x] Trade-off chart with tap selection and a VoiceOver label per point
- [x] Route map: real polylines, rainy legs coloured, dashed and labelled
- [ ] Departure notification: permission on first tap (checked at Mac 2), Settings link on refusal
- [ ] All three checked in the simulator (notification shows, rainy stretch readable without colour)
Tests: slicesAThirdOfARoute, groupsRainyMinutesIntoSegments

## Part 5 — NowcastKit · Linux · due 2026-10-20
- [x] Radar PNG decoder shared by Linux tests and the app
- [x] RainGrid with bilinear sampling, RadarFrame with tile and time
- [x] Georeference (spherical Mercator)
- [x] Block matching motion estimator with median filter and global fallback
- [x] Semi-Lagrangian advection to 30 min on the cropped area
- [x] NowcastRainField blended with the hourly forecast
- [x] Verifier: nowcast beats persistence at 20 min on a recorded day
- [x] ./ww verify replays every recorded day (CSI nowcast vs persistence at 10, 20, 30 min)
Tests: georeferencesMelbourneCBD, convertsReflectivityToRainRate, recoversUniformShift, zeroMotionKeepsFrame, predictsMovingDisc, fallsBackToGlobalVector, csiBounds, beatsPersistenceOnRecordedDay

## Part 6 — Nowcast in the app · Mac 3 · due 2026-10-21
- [x] Nowcast screens written in AppStaging/, tested and screenshotted by CI (replay)
- [x] RecordedFrameSource, NowcastEngine (stale radar detected) and DepartureAdvisor in the package
- [ ] LiveRainViewerSource actor checked against live radar in the simulator
- [ ] Departure advice card (go now or wait) with reminder
- [x] Collision view with time scrubber: Apple map (rain as MapPolygon bands) or Canvas radar grid, checked in replay
- [ ] Replay mode with a permanent banner, demo works offline
Tests: recordedSourceReturnsFramesUpToTheReplayTime, engineBuildsThirtyMinutesAroundTheRoute, engineRefusesStaleRadar, advisesWaitingForTheShowerToPass, advisesLeavingNowWhenDry, waitingNeverMissesClosingTime, adviceExplainsWhenNothingFits, advisesFromTheRecordedRadar, fallsBackToTheForecastWhenRadarIsStale

## Part 7 — Finish · Mac 4–5 · due 2026-11-04
- [x] About screen written: identity, data credits, methods with DOIs, labs, AI statement
- [x] About screen checked in the simulator
- [x] Error table mapped to automatic tests (docs/error-table.md)
- [x] Apple accessibility audit runs in CI, exemptions justified in the test
- [ ] Every error situation provoked in the simulator without a crash
- [ ] VoiceOver, largest Dynamic Type and dark mode checked on every screen (screenshots in CI, Inspector at the Mac)
- [ ] Zero compiler warnings, no print, final README
- [ ] Backup demo video recorded
- [ ] Live code changes rehearsed
Tests: serverErrorBecomesARetryLaterMessage, tooManyRequestsIsRateLimited, unreadableBodyIsAnInvalidResponse, noConnectionIsOffline, cancellationIsNotReportedAsAnError

## Part 8 — Bonus · Mac 2 · due 2026-11-04
- [x] Nowcast accuracy screen: whole rainy day or last 2 hours of live radar, CSI chart, scores in SwiftData
- [x] Open-Meteo ensemble: five of 40 runs as robustness scenarios (About setting), shifted forecast as fallback
- [x] Learned preference: "Your Usual Choice" from the trade-offs of saved plans
- [x] Share a plan as text from the itinerary
- [x] Rain alert on the next walk while the Next Walk screen is open
- [x] Collision view on an Apple map (pixel to place in Georeference)
- [x] Errand from a sentence with Foundation Models (iOS 26, hidden without Apple Intelligence)
- [x] All of the above compiled and tested on the lab Mac (Mac 2)
- [ ] Errand from a sentence checked on a Mac with Apple Intelligence
- [ ] Rain alert banner checked in the simulator
- [ ] Next 7 Days: same errands and window on each day of the 7-day forecast, driest day highlighted (checked in the simulator)
Tests: findsTheDriestDayOfTheWeek, bundlesTheWholeRainyDay, scoresEachLeadTimeAndKeepsTheScores, learnsTheUsualTradeOff, sharesThePlanAsText, scoresWithTheEnsembleWhenItIsAvailable, alertsOnceWhenRainHeadsForTheNextWalk, fillsTheFormFromADescription, decodesEnsembleFixture, picksFiveRunsFromDryToWet, rejectsAnEnsembleWithoutRain, buildsEnsembleURL, pixelRoundTripsToTheSamePlace

## Calendar
- [x] 2026-10-07 · Mac 1 · Xcode project, SwiftData models, errand library
- [x] 2026-10-14 · Mac 2 · Real services, Plan and Results screens, tag mvp
- [ ] 2026-10-21 · Mac 3 · Nowcast service, advice card, collision view
- [ ] 2026-10-23 · End of classes
- [ ] 2026-10-28 · Mac 4 (to confirm) · Notification, About, error table, accessibility, demo video
- [ ] 2026-11-02 · Demo window opens · interviews until 13 Nov
- [ ] 2026-11-04 · Mac 5 (to confirm) · Rehearsal, fixes, bonus
