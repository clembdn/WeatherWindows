import Foundation

/// Converts radar reflectivity into rain rate with the Marshall–Palmer relation Z = 200 R^1.6.
public enum ReflectivityConverter {
    /// Rain rate in mm/h for a reflectivity in dBZ.
    public static func rainRate(dBZ: Double) -> Double {
        let z = pow(10, dBZ / 10)
        return pow(z / 200, 1 / 1.6)
    }

    /// Rain weight in 0...1, saturating at 1 mm/h like the hourly forecast; no echo is dry.
    public static func rainWeight(dBZ: Double) -> Double {
        guard dBZ > Double(ReflectivityPalette.noEchoDBZ) else { return 0 }
        return min(1, rainRate(dBZ: dBZ))
    }
}
