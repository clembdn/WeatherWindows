//
//  ServiceError.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import MapKit

nonisolated enum ServiceError: LocalizedError, Equatable {
    case offline
    case timedOut
    case invalidResponse
    case httpStatus(Int)
    case rateLimited
    case mapsThrottled
    case noWalkingRoute
    case placeNotFound
    case locationDenied
    case locationUnavailable
    case cancelled
    case other(String)

    init(_ error: Error) {
        switch error {
        case let serviceError as ServiceError:
            self = serviceError
        case is CancellationError:
            self = .cancelled
        case is DecodingError:
            self = .invalidResponse
        case let urlError as URLError:
            switch urlError.code {
            case .cancelled:
                self = .cancelled
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost:
                self = .offline
            case .timedOut:
                self = .timedOut
            default:
                self = .other(urlError.localizedDescription)
            }
        case let mapError as MKError:
            switch mapError.code {
            case .loadingThrottled:
                self = .mapsThrottled
            case .directionsNotFound:
                self = .noWalkingRoute
            case .placemarkNotFound:
                self = .placeNotFound
            case .serverFailure:
                self = .offline
            default:
                self = .other(mapError.localizedDescription)
            }
        default:
            self = .other(error.localizedDescription)
        }
    }

    static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        if http.statusCode == 429 {
            throw ServiceError.rateLimited
        }
        if !(200...299).contains(http.statusCode) {
            throw ServiceError.httpStatus(http.statusCode)
        }
    }

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. Check your connection and try again."
        case .timedOut:
            "The request took too long. Try again."
        case .invalidResponse:
            "The service sent an unexpected answer."
        case .httpStatus(let code) where code >= 500:
            "Weather service unavailable, try again in a minute."
        case .httpStatus(let code):
            "The service returned an error (HTTP \(code))."
        case .rateLimited:
            "Too many requests. Wait a minute and try again."
        case .mapsThrottled:
            "Apple Maps is limiting requests. Wait a moment and try again."
        case .noWalkingRoute:
            "No walking route was found between two of your places."
        case .placeNotFound:
            "That place couldn't be found. Try another search."
        case .locationDenied:
            "Location access is off. Choose a start place instead, or allow access in Settings."
        case .locationUnavailable:
            "Your location isn't available right now. Choose a start place instead."
        case .cancelled:
            "Cancelled."
        case .other(let message):
            message
        }
    }
}
