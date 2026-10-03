import Foundation

/// Rain weight in 0...1 at a place and time.
public protocol RainField: Sendable {
    func weight(at point: GeoPoint, time: Date) -> Double
}
