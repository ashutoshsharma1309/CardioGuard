//
//  Formatters.swift
//  CardioGuard
//
//  Shared, cached formatters. Formatters are expensive to allocate, so we keep
//  singletons rather than constructing them inside SwiftUI body re-evaluations.
//

import Foundation

public enum Formatters {

    public static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    public static let clock: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f
    }()

    /// Formats a coordinate pair to 5 decimal places (~1.1 m precision).
    public static func coordinateString(_ location: LocationData) -> String {
        String(format: "%.5f, %.5f", location.latitude, location.longitude)
    }

    /// "1.2 km" / "850 m"
    public static func distanceString(meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.1f km", meters / 1_000)
        }
        return String(format: "%.0f m", meters)
    }
}
