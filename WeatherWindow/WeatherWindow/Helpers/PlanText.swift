//
//  PlanText.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

enum PlanText {
    static func isDry(_ exposure: Double) -> Bool {
        exposure < 0.5
    }

    static func rain(_ exposure: Double) -> String {
        if isDry(exposure) {
            return "Dry"
        }
        return "Up to ~\(max(1, Int(exposure.rounded()))) min of rain"
    }

    /// What VoiceOver reads instead of `rain`: words, not "~" and "min".
    static func spokenRain(_ exposure: Double) -> String {
        if isDry(exposure) {
            return "Dry"
        }
        let minutes = max(1, Int(exposure.rounded()))
        return "Up to about \(minutes) \(minutes == 1 ? "minute" : "minutes") of rain"
    }

    static func confidence(_ level: Int) -> String {
        switch level {
        case 3:
            "High confidence · 3/3"
        case 2:
            "Medium confidence · 2/3"
        default:
            "Low confidence · 1/3"
        }
    }

    /// What VoiceOver reads instead of `confidence`, which could read "3/3" as a date.
    static func spokenConfidence(_ level: Int) -> String {
        switch level {
        case 3:
            "High confidence, 3 out of 3"
        case 2:
            "Medium confidence, 2 out of 3"
        default:
            "Low confidence, 1 out of 3"
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 {
            return "\(minutes) min"
        }
        return String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    static func reason(_ reason: NoPlanReason) -> String {
        switch reason {
        case .closesTooEarly(let name, let closingMinute):
            "\(name) closes at \(Melbourne.time(minute: closingMinute)), so it can't fit in this window. "
                + "Try an earlier window or a shorter errand."
        case .missingWalkingTime:
            "A walking time between two of your places is missing. Try again."
        case .noDepartureTimes:
            "The departure window is empty."
        }
    }
}
