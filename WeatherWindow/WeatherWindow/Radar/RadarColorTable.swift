//
//  RadarColorTable.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RadarColorTable {
    static let noEchoDBZ: Float = -32

    private let dBZByColor: [UInt32: Float]

    init(csv: String, scheme: String = "Universal Blue") throws {
        var lines = csv.split(whereSeparator: \.isNewline).makeIterator()
        guard let header = lines.next()?.split(separator: ","),
              let column = header.firstIndex(where: { $0 == scheme }) else {
            throw ColorTableError.missingScheme(scheme)
        }

        var table: [UInt32: Float] = [:]
        var previousDBZ: Float?
        while let line = lines.next() {
            let fields = line.split(separator: ",")
            guard fields.count > column, let dBZ = Float(fields[0]) else { continue }
            if let previousDBZ, dBZ < previousDBZ { break }
            previousDBZ = dBZ

            guard let color = UInt32(fields[column].dropFirst(), radix: 16) else {
                throw ColorTableError.invalidColor(String(fields[column]))
            }
            if color & 0xFF != 0, table[color] == nil {
                table[color] = dBZ
            }
        }
        dBZByColor = table
    }

    static func universalBlue() throws -> RadarColorTable {
        guard let url = Bundle.main.url(forResource: "rainviewer_colors", withExtension: "csv") else {
            throw ColorTableError.missingFile
        }
        return try RadarColorTable(csv: String(contentsOf: url, encoding: .utf8))
    }

    func dBZ(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> Float? {
        if alpha == 0 { return Self.noEchoDBZ }
        return dBZByColor[Self.pack(red, green, blue, alpha)]
    }

    func nearestDBZ(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> Float {
        let target = [red, green, blue, alpha].map(Int.init)
        let closest = dBZByColor.min { first, second in
            Self.distance(first.key, target) < Self.distance(second.key, target)
        }
        return closest?.value ?? Self.noEchoDBZ
    }

    private static func pack(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8) -> UInt32 {
        UInt32(red) << 24 | UInt32(green) << 16 | UInt32(blue) << 8 | UInt32(alpha)
    }

    private static func distance(_ color: UInt32, _ target: [Int]) -> Int {
        let channels = [24, 16, 8, 0].map { Int((color >> UInt32($0)) & 0xFF) }
        return zip(channels, target).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
    }
}

nonisolated enum ColorTableError: Error, Equatable {
    case missingFile
    case missingScheme(String)
    case invalidColor(String)
}
