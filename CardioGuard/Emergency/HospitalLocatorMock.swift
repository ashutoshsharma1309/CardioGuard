//
//  HospitalLocatorMock.swift
//  CardioGuard
//
//  A deterministic stand-in for a real places/hospital API.
//

import Foundation

/// Simulates locating the nearest emergency-capable hospital.
///
/// In production this would query a maps/places provider. The protocol seam
/// (`HospitalLocating`) means swapping in a live implementation requires **no**
/// changes to `EmergencyCoordinator`. The mock derives plausible facilities by
/// offsetting the user's coordinates, so results are stable and testable.
public struct HospitalLocatorMock: HospitalLocating {

    /// Artificial latency to mimic a network round-trip (skipped in tests via `0`).
    private let simulatedLatency: Duration

    public init(simulatedLatency: Duration = .milliseconds(600)) {
        self.simulatedLatency = simulatedLatency
    }

    public func nearestHospital(to location: LocationData) async throws -> Hospital {
        if simulatedLatency > .zero {
            try await Task.sleep(for: simulatedLatency)
        }

        let candidates = Self.makeCandidates(around: location)
        guard let nearest = candidates.min(by: { $0.distanceMeters < $1.distanceMeters }) else {
            throw CardioGuardError.hospitalLookupFailed("No facilities found nearby")
        }
        AppLogger.emergency.info("Nearest hospital: \(nearest.name, privacy: .public)")
        return nearest
    }

    /// Generates three deterministic facilities around the user.
    private static func makeCandidates(around origin: LocationData) -> [Hospital] {
        let offsets: [(name: String, dLat: Double, dLon: Double, phone: String)] = [
            ("St. Mary's Medical Center", 0.012, -0.008, "+1-555-0142"),
            ("Bayview Emergency Hospital", -0.020, 0.015, "+1-555-0177"),
            ("General Regional Hospital", 0.030, 0.025, "+1-555-0199")
        ]

        return offsets.map { offset in
            let loc = LocationData(
                latitude: origin.latitude + offset.dLat,
                longitude: origin.longitude + offset.dLon,
                horizontalAccuracy: 10
            )
            let distance = origin.distance(to: loc)
            // Assume ~40 km/h average urban emergency-response speed.
            let travel = distance / (40_000.0 / 3_600.0)
            return Hospital(
                name: offset.name,
                location: loc,
                distanceMeters: distance,
                estimatedTravelTime: travel,
                phoneNumber: offset.phone
            )
        }
    }
}
