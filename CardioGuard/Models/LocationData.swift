//
//  LocationData.swift
//  CardioGuard
//
//  A lightweight, Codable, Sendable representation of a geographic location.
//

import Foundation
import CoreLocation

/// A serializable snapshot of the user's location.
///
/// We deliberately avoid passing `CLLocation` around the app: it is a reference
/// type and not `Codable`. `LocationData` is a value type that crosses
/// concurrency boundaries cleanly and serializes into emergency reports.
public struct LocationData: Codable, Hashable, Sendable {

    public let latitude: Double
    public let longitude: Double

    /// Horizontal accuracy in meters (negative means invalid, per CoreLocation).
    public let horizontalAccuracy: Double

    /// Altitude in meters, when available.
    public let altitude: Double?

    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double = -1,
        altitude: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.altitude = altitude
        self.timestamp = timestamp
    }
}

public extension LocationData {

    /// Bridges from CoreLocation's reference type at the framework boundary.
    init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            timestamp: location.timestamp
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Great-circle distance in meters to another location.
    func distance(to other: LocationData) -> CLLocationDistance {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b)
    }

    /// Apple Park — a deterministic fixture for previews and tests.
    static let sample = LocationData(
        latitude: 37.334_900,
        longitude: -122.009_020,
        horizontalAccuracy: 5,
        altitude: 23
    )
}
