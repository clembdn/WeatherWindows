import Foundation
import WeatherWindowCore

/// The time spent at one errand: arrival, possible wait for opening, then the task itself.
public struct Visit: Hashable, Sendable {
    public let stop: Stop
    public let arrival: Date
    public let serviceStart: Date
    public let departure: Date

    public var waiting: TimeInterval { serviceStart.timeIntervalSince(arrival) }
}

/// One walk between two nodes, with the rain it crosses in each scenario.
public struct Leg: Hashable, Sendable {
    public let from: Node
    public let to: Node
    public let departure: Date
    public let arrival: Date
    /// Minutes of rain weight crossed, one value per scenario, in the order the scenarios were given.
    public let exposureByScenario: [Double]
}

/// A complete day plan with its duration and robust rain exposure.
public struct ScoredSchedule: Hashable, Sendable, Identifiable {
    public let departure: Date
    public let returnTime: Date
    public let visits: [Visit]
    public let legs: [Leg]
    /// Total rain exposure (weight × minutes), one value per scenario.
    public let exposureByScenario: [Double]
    /// Time from the start of the departure window until the return.
    public let duration: TimeInterval

    /// The worst exposure over all scenarios: the plan must stay good if the rain is early or late.
    public var robustExposure: Double { exposureByScenario.max() ?? 0 }

    public var order: [Stop] { visits.map(\.stop) }

    public var id: String {
        "\(departure.timeIntervalSince1970)-" + order.map(\.id.uuidString).joined(separator: ",")
    }
}
