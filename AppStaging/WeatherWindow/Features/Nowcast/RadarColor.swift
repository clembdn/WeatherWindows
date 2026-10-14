import SwiftUI

// Colours for radar reflectivity (dBZ), from light drizzle (pale blue) to storms (red).
enum RadarColor {
    // 0 for clear air, then 1 (drizzle) to 5 (storm).
    static func level(dBZ: Float) -> Int {
        switch dBZ {
        case ..<10: 0
        case ..<20: 1
        case ..<30: 2
        case ..<40: 3
        case ..<50: 4
        default: 5
        }
    }

    // Nil for clear air, which is not drawn.
    static func color(level: Int) -> Color? {
        switch level {
        case 1: Color(red: 0.53, green: 0.87, blue: 0.93).opacity(0.55)
        case 2: Color(red: 0, green: 0.64, blue: 0.88).opacity(0.75)
        case 3: Color(red: 0, green: 0.33, blue: 0.53).opacity(0.86)
        case 4: Color(red: 1, green: 0.67, blue: 0).opacity(0.9)
        case 5: Color(red: 0.78, green: 0, blue: 0).opacity(0.94)
        default: nil
        }
    }

    static func color(dBZ: Float) -> Color? {
        color(level: level(dBZ: dBZ))
    }

    // Plain words for the rain at a point, for VoiceOver.
    static func description(dBZ: Float) -> String {
        switch dBZ {
        case ..<20: "dry"
        case ..<30: "light rain"
        case ..<40: "moderate rain"
        default: "heavy rain"
        }
    }
}
