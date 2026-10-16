//
//  PlannerTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

@Test func waitsWhenArrivingBeforeOpening() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 14 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(13, 40)...at(13, 40))

    let schedule = try #require(foundSchedules(Planner().rankSchedules(for: request, scenarios: [NoRain()]))?.first)

    #expect(schedule.visits[0].arrival == at(13, 50))
    #expect(schedule.visits[0].serviceStart == at(14, 0))
    #expect(schedule.visits[0].waiting == 10 * 60)
}

@Test func rejectsTaskEndingAfterClosing() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 30 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(16, 30)...at(16, 30))

    let outcome = Planner().rankSchedules(for: request, scenarios: [NoRain()])

    #expect(reason(outcome) == .closesTooEarly(stopName: "Post", closingMinute: 17 * 60))
}

@Test func splitsLegAcrossHourBoundary() {
    let minutes = WalkRain.minutes(from: homePlace, to: libraryPlace, departure: at(14, 50), duration: 25 * 60)
    let hours = minutes.map { melbourneCalendar.component(.hour, from: $0.time) }

    #expect(minutes.count == 25)
    #expect(hours.count { $0 == 14 } == 10)
    #expect(hours.count { $0 == 15 } == 15)
    #expect(minutes.allSatisfy { $0.minutes == 1 })
}

@Test func enumeratesAllOrders() {
    let stops = ["Post", "Coles", "Library", "Gym"].map { name in
        Stop(name: name, location: homePlace, serviceDuration: 600, openingMinute: 9 * 60, closingMinute: 17 * 60)
    }

    let orders = Planner.orders(of: stops)

    #expect(orders.count == 24)
    #expect(Set(orders.map { $0.map(\.name) }).count == 24)
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

    let schedules = try #require(foundSchedules(Planner().rankSchedules(for: request, scenarios: [NoRain()])))

    #expect(!schedules.isEmpty)
    #expect(schedules.allSatisfy { $0.robustExposure == 0 })
}

@Test func robustScoreIsWorstScenario() throws {
    let request = makeRequest(stops: [], minutesFromHome: [:], window: at(14, 0)...at(14, 0), directMinutes: 10)
    let scenarios: [any RainForecast] = [ConstantRain(weight: 0.1), ConstantRain(weight: 0.3), ConstantRain(weight: 0.2)]

    let schedule = try #require(foundSchedules(Planner().rankSchedules(for: request, scenarios: scenarios))?.first)

    #expect(zip(schedule.exposureByScenario, [1.0, 3.0, 2.0]).allSatisfy { abs($0 - $1) < 1e-9 })
    #expect(abs(schedule.robustExposure - 3) < 1e-9)
}

@Test func paretoDropsDominated() {
    let schedules = [schedule(minutes: 50, exposure: 2.0), schedule(minutes: 55, exposure: 1.0), schedule(minutes: 60, exposure: 1.5)]

    let kept = TradeOffs.best(of: schedules)

    #expect(kept.map { $0.duration / 60 } == [50, 55])
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

    let outcome = Planner().rankSchedules(for: request, scenarios: [NoRain()])

    #expect(reason(outcome) == .closesTooEarly(stopName: "Post", closingMinute: 13 * 60))
}

@Test func handComputedCaseA() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(13, 55)...at(14, 30))
    let shower = RainBetween(start: at(14, 0), end: at(14, 30))

    let schedules = try #require(foundSchedules(Planner().rankSchedules(for: request, scenarios: [shower])))

    #expect(schedules.map(\.departure) == [at(13, 55), at(14, 10), at(14, 25), at(14, 30)])
    #expect(schedules.map { $0.duration / 60 } == [30, 45, 60, 65])
    #expect(schedules.map(\.robustExposure) == [15, 10, 5, 0])
}

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

    let schedules = try #require(foundSchedules(Planner().rankSchedules(for: request, scenarios: [NoRain()])))

    #expect(schedules.count == 1)
    #expect(schedules[0].order.map(\.name) == ["Post", "Library"])
    #expect(schedules[0].visits[1].waiting == 5 * 60)
    #expect(schedules[0].returnTime == at(15, 5))
}

@Test func advisesWaitingForTheShowerToPass() throws {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(14, 0)...at(14, 30))

    let advice = DepartureAdvisor.advice(for: request, scenarios: [RainBetween(start: at(14, 0), end: at(14, 15))])

    #expect(advice.bestLater != nil)
    #expect(advice.leaveNow?.robustExposure == 10)
    #expect(advice.bestLater?.robustExposure == 0)
    #expect(advice.waitingTime(from: at(14, 0)) == 15 * 60)
}

@Test func advisesLeavingNowWhenDry() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 17 * 60)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(14, 0)...at(14, 30))

    let advice = DepartureAdvisor.advice(for: request, scenarios: [NoRain()])

    #expect(advice.bestLater == nil)
    #expect(advice.leaveNow?.departure == at(14, 0))
}

@Test func waitingNeverMissesClosingTime() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 14 * 60 + 25)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(14, 0)...at(14, 30))

    let advice = DepartureAdvisor.advice(for: request, scenarios: [RainBetween(start: at(14, 0), end: at(14, 15))])

    #expect(advice.bestLater == nil)
    #expect(advice.leaveNow != nil)
}

@Test func adviceExplainsWhenNothingFits() {
    let post = Stop(name: "Post", location: postPlace, serviceDuration: 10 * 60, openingMinute: 9 * 60, closingMinute: 14 * 60 + 5)
    let request = makeRequest(stops: [post], minutesFromHome: [post.id: 10], window: at(14, 0)...at(14, 30))

    let advice = DepartureAdvisor.advice(for: request, scenarios: [NoRain()])

    #expect(advice.leaveNow == nil)
    #expect(advice.noPlanReason == .closesTooEarly(stopName: "Post", closingMinute: 14 * 60 + 5))
}

private let homePlace = GeoPoint(latitude: -37.8136, longitude: 144.9631)
private let postPlace = GeoPoint(latitude: -37.8140, longitude: 144.9633)
private let colesPlace = GeoPoint(latitude: -37.8102, longitude: 144.9628)
private let libraryPlace = GeoPoint(latitude: -37.8098, longitude: 144.9652)

private let melbourneCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
    return calendar
}()

private func at(_ hour: Int, _ minute: Int) -> Date {
    melbourneCalendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour, minute: minute))!
}

private func makeRequest(stops: [Stop], minutesFromHome: [UUID: Int], between: [(UUID, UUID, Int)] = [],
                         window: ClosedRange<Date>, directMinutes: Int = 0) -> PlanRequest {
    var times: [Waypoint: [Waypoint: TimeInterval]] = [.start: [.end: TimeInterval(directMinutes * 60)]]
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

private func schedule(minutes: Double, exposure: Double) -> Schedule {
    Schedule(departure: at(14, 0), returnTime: at(14, 0), visits: [], walks: [],
             exposureByScenario: [exposure], duration: minutes * 60)
}

private func foundSchedules(_ outcome: PlanOutcome) -> [Schedule]? {
    if case .schedules(let schedules) = outcome { return schedules }
    return nil
}

private func reason(_ outcome: PlanOutcome) -> NoPlanReason? {
    if case .noPlan(let reason) = outcome { return reason }
    return nil
}

private nonisolated struct NoRain: RainForecast {
    func weight(at point: GeoPoint, time: Date) -> Double { 0 }
}

private nonisolated struct ConstantRain: RainForecast {
    let weight: Double
    func weight(at point: GeoPoint, time: Date) -> Double { weight }
}

private nonisolated struct RainBetween: RainForecast {
    let start: Date
    let end: Date
    func weight(at point: GeoPoint, time: Date) -> Double { time >= start && time < end ? 1 : 0 }
}
