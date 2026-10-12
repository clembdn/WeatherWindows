import SwiftUI

// Colours for radar reflectivity (dBZ), from light drizzle (pale blue) to storms (red).
enum RadarColor {
    // Nil for clear air, which is not drawn.
    static func color(dBZ: Float) -> Color? {
        switch dBZ {
        case ..<10: nil
        case ..<20: Color(red: 0.53, green: 0.87, blue: 0.93).opacity(0.55)
        case ..<30: Color(red: 0, green: 0.64, blue: 0.88).opacity(0.75)
        case ..<40: Color(red: 0, green: 0.33, blue: 0.53).opacity(0.86)
        case ..<50: Color(red: 1, green: 0.67, blue: 0).opacity(0.9)
        default: Color(red: 0.78, green: 0, blue: 0).opacity(0.94)
        }
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
