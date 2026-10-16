//
//  RainColor.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 12/10/2026.
//

import SwiftUI

enum RainColor {
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

    static func description(dBZ: Float) -> String {
        switch dBZ {
        case ..<20: "dry"
        case ..<30: "light rain"
        case ..<40: "moderate rain"
        default: "heavy rain"
        }
    }
}
