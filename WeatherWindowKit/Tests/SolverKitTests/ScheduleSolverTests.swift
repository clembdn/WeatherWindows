import Foundation
import Testing
import WeatherWindowCore
@testable import SolverKit

// MARK: - Spec tests

@Test func waitsWhenArrivingBeforeOpening() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 14 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(13, 40)...at(13, 40))

    let schedule = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()]))?.first)

    #expect(schedule.visits[0].arrival == at(13, 50))
    #expect(schedule.visits[0].serviceStart == at(14, 0))
    #expect(schedule.visits[0].waiting == 10 * 60)
}

@Test func rejectsTaskEndingAfterClosing() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 30 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(16, 30)...at(16, 30))

    let outcome = ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()])

    #expect(reason(outcome) == .closesTooEarly(stopName: "Post", closingMinute: 17 * 60))
}

@Test func splitsLegAcrossHourBoundary() {
    let samples = LegSampler.samples(from: homePlace, to: libraryPlace, departure: at(14, 50), duration: 25 * 60)
    let hours = samples.map { melbourneCalendar.component(.hour, from: $0.time) }

    #expect(samples.count == 25)
    #expect(hours.count { $0 == 14 } == 10)
    #expect(hours.count { $0 == 15 } == 15)
    #expect(samples.allSatisfy { $0.minutes == 1 })
}

@Test func enumeratesAllOrders() {
    let orders = ScheduleSolver.orders(of: [1, 2, 3, 4])

    #expect(orders.count == 24)
    #expect(Set(orders).count == 24)
}

@Test func dryForecastGivesZeroExposure() throws {
    let stops = [
        Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60),
        Stop(name: "Coles", location: colesPlace, serviceDuration: 20 * 60, openingMinute: 7 * 60, closingMinute: 22 * 60),
        Stop(name: "Library", location: libraryPlace, serviceDuration: 15 * 60, openingMinute: 10 * 60, closingMinute: 18 * 60)
    ]
    let request = makeRequest(
        stops: stops,
        minutesFromHome: [stops[0].id: 10, stops[1].id: 8, stops[2].id: 15],
        between: [(stops[0].id, stops[1].id, 6), (stops[0].id, stops[2].id, 7), (stops[1].id, stops[2].id, 12)],
        window: at(14, 0)...at(16, 0)
    )

    let schedules = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()])))

    #expect(!schedules.isEmpty)
    #expect(schedules.allSatisfy { $0.robustExposure == 0 })
}

@Test func robustScoreIsWorstScenario() throws {
    let request = makeRequest(stops: [], minutesFromHome: [:], window: at(14, 0)...at(14, 0), directMinutes: 10)
    let scenarios: [any RainField] = [ConstantRain(weight: 0.1), ConstantRain(weight: 0.3), ConstantRain(weight: 0.2)]

    let schedule = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: scenarios))?.first)

    #expect(zip(schedule.exposureByScenario, [1.0, 3.0, 2.0]).allSatisfy { abs($0 - $1) < 1e-9 })
    #expect(abs(schedule.robustExposure - 3) < 1e-9)
}

@Test func paretoDropsDominated() {
    let points: [(minutes: Double, exposure: Double)] = [(50, 2.0), (55, 1.0), (60, 1.5)]

    let kept = ParetoFrontier.frontier(of: points, first: { $0.minutes }, second: { $0.exposure })

    #expect(kept.map(\.minutes) == [50, 55])
}

@Test func reportsWhyNothingFits() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 13 * 60)
    let library = Stop(name: "Library", location: libraryPlace, serviceDuration: 15 * 60, openingMinute: 10 * 60, closingMinute: 18 * 60)
    let request = makeRequest(
        stops: [post, library],
        minutesFromHome: [post.id: 10, library.id: 15],
        between: [(post.id, library.id, 5)],
        window: at(14, 0)...at(16, 0)
    )

    let outcome = ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()])

    #expect(reason(outcome) == .closesTooEarly(stopName: "Post", closingMinute: 13 * 60))
}

/// Four errands, a 2-hour window and five scenarios: 24 orders × 25 departures × 5 = 3,000 evaluations.
@Test func frontierTradesTimeForRainOnARealisticDay() throws {
    let stops = [
        Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60),
        Stop(name: "Coles", location: colesPlace, serviceDuration: 20 * 60, openingMinute: 7 * 60, closingMinute: 22 * 60),
        Stop(name: "Library", location: libraryPlace, serviceDuration: 15 * 60, openingMinute: 10 * 60, closingMinute: 18 * 60),
        Stop(name: "Gym", location: homePlace, serviceDuration: 45 * 60, openingMinute: 6 * 60, closingMinute: 21 * 60)
    ]
    let request = makeRequest(
        stops: stops,
        minutesFromHome: [stops[0].id: 10, stops[1].id: 8, stops[2].id: 15, stops[3].id: 12],
        between: [(stops[0].id, stops[1].id, 6), (stops[0].id, stops[2].id, 7), (stops[0].id, stops[3].id, 9),
                  (stops[1].id, stops[2].id, 12), (stops[1].id, stops[3].id, 5), (stops[2].id, stops[3].id, 11)],
        window: at(14, 0)...at(16, 0)
    )
    let scenarios = ShiftedRainField.scenarios(around: RainBetween(start: at(14, 20), end: at(15, 10)))

    let schedules = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: scenarios)))

    #expect(schedules.count > 1)
    #expect(zip(schedules, schedules.dropFirst()).allSatisfy { $0.duration < $1.duration && $0.robustExposure > $1.robustExposure })
}

// MARK: - Hand-computed cases

/// A shower from 14:00 to 14:30. Post office 10 min away, 10 min task: go, task, come back = 30 min.
///
/// | Leave | Way out (rain min) | Way back (rain min) | Total | Back at | Duration | Kept? |
/// | 13:55 | 13:55–14:05 → 5    | 14:15–14:25 → 10    | 15    | 14:25   | 30       | yes   |
/// | 14:00 | 10                 | 14:20–14:30 → 10    | 20    | 14:30   | 35       | no    |
/// | 14:05 | 10                 | 14:25–14:35 → 5     | 15    | 14:35   | 40       | no    |
/// | 14:10 | 10                 | 14:30–14:40 → 0     | 10    | 14:40   | 45       | yes   |
/// | 14:15 | 10                 | 0                   | 10    | 14:45   | 50       | no    |
/// | 14:20 | 10                 | 0                   | 10    | 14:50   | 55       | no    |
/// | 14:25 | 14:25–14:35 → 5    | 0                   | 5     | 14:55   | 60       | yes   |
/// | 14:30 | 0                  | 0                   | 0     | 15:00   | 65       | yes   |
@Test func handComputedCaseA() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(13, 55)...at(14, 30))
    let shower = RainBetween(start: at(14, 0), end: at(14, 30))

    let schedules = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: [shower])))

    #expect(schedules.map(\.departure) == [at(13, 55), at(14, 10), at(14, 25), at(14, 30)])
    #expect(schedules.map { $0.duration / 60 } == [30, 45, 60, 65])
    #expect(schedules.map(\.robustExposure) == [15, 10, 5, 0])
}

/// Dry afternoon, leave at 14:00. Post: 10 min from home, 10 min task. Library: 15 min from home,
/// opens 14:30, 20 min task. Post ↔ Library: 5 min.
///
/// Post first:    14:10 post → 14:20, 14:25 library, wait 5, 14:30 → 14:50, home 15:05 (65 min).
/// Library first: 14:15 library, wait 15, 14:30 → 14:50, 14:55 post → 15:05, home 15:15 (75 min).
@Test func handComputedCaseB() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let library = Stop(name: "Library", location: libraryPlace, serviceDuration: 20 * 60,
                       openingMinute: 14 * 60 + 30, closingMinute: 18 * 60)
    let request = makeRequest(
        stops: [library, post],
        minutesFromHome: [post.id: 10, library.id: 15],
        between: [(post.id, library.id, 5)],
        window: at(14, 0)...at(14, 0)
    )

    let schedules = try #require(frontier(ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()])))

    #expect(schedules.count == 1)
    #expect(schedules[0].order.map(\.name) == ["Post", "Library"])
    #expect(schedules[0].visits[1].waiting == 5 * 60)
    #expect(schedules[0].returnTime == at(15, 5))
}

@Test func reportsMissingWalkingTime() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    var request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(14, 0)...at(14, 0))
    request.walkingTimes[.stop(post.id)] = nil

    let outcome = ScheduleSolver().rankSchedules(for: request, scenarios: [NoRain()])

    #expect(reason(outcome) == .missingWalkingTime(from: .stop(post.id), to: .end))
}

// MARK: - Helpers

private let homePlace = GeoPoint(latitude: -37.8136, longitude: 144.9631)
private let postPlace = GeoPoint(latitude: -37.8140, longitude: 144.9633)
private let colesPlace = GeoPoint(latitude: -37.8102, longitude: 144.9628)
private let libraryPlace = GeoPoint(latitude: -37.8098, longitude: 144.9652)

private let melbourneCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
    return calendar
}()

/// A local Melbourne time on Wednesday 14 October 2026.
private func at(_ hour: Int, _ minute: Int) -> Date {
    melbourneCalendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour, minute: minute))!
}

/// Start and end at home; walking times are symmetric and given in minutes.
private func makeRequest(stops: [Stop], minutesFromHome: [UUID: Int], between: [(UUID, UUID, Int)] = [],
                         window: ClosedRange<Date>, directMinutes: Int = 0) -> PlanRequest {
    var times: [Node: [Node: TimeInterval]] = [.start: [.end: TimeInterval(directMinutes * 60)]]
    for (id, minutes) in minutesFromHome {
        times[.start, default: [:]][.stop(id)] = TimeInterval(minutes * 60)
        times[.stop(id), default: [:]][.end] = TimeInterval(minutes * 60)
    }
    for (a, b, minutes) in between {
        times[.stop(a), default: [:]][.stop(b)] = TimeInterval(minutes * 60)
        times[.stop(b), default: [:]][.stop(a)] = TimeInterval(minutes * 60)
    }
    return PlanRequest(start: homePlace, end: homePlace, stops: stops, departureWindow: window,
                       walkingTimes: times, timeZone: melbourneCalendar.timeZone)
}

private func frontier(_ outcome: SolveOutcome) -> [ScoredSchedule]? {
    if case .frontier(let schedules) = outcome { return schedules }
    return nil
}

private func reason(_ outcome: SolveOutcome) -> InfeasibilityReason? {
    if case .infeasible(let reason) = outcome { return reason }
    return nil
}

private struct NoRain: RainField {
    func weight(at point: GeoPoint, time: Date) -> Double { 0 }
}

private struct ConstantRain: RainField {
    let weight: Double
    func weight(at point: GeoPoint, time: Date) -> Double { weight }
}

private struct RainBetween: RainField {
    let start: Date
    let end: Date
    func weight(at point: GeoPoint, time: Date) -> Double { time >= start && time < end ? 1 : 0 }
}
