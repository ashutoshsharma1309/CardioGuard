//
//  Hospital.swift
//  CardioGuard
//
//  A medical facility candidate returned by the (mock) hospital locator.
//

import Foundation

/// Represents a hospital / emergency facility.
///
/// In production this would be hydrated from a real places API; here it is
/// supplied by `HospitalLocatorMock`. The shape, however, is production-ready.
public struct Hospital: Codable, Hashable, Sendable, Identifiable {

    public let id: UUID
    public let name: String
    public let location: LocationData

    /// Straight-line distance from the user, in meters, at time of lookup.
    public let distanceMeters: Double

    /// Estimated travel time for emergency services, in seconds.
    public let estimatedTravelTime: TimeInterval

    public let phoneNumber: String

    /// Whether the facility has an emergency department.
    public let hasEmergencyDepartment: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        location: LocationData,
        distanceMeters: Double,
        estimatedTravelTime: TimeInterval,
        phoneNumber: String,
        hasEmergencyDepartment: Bool = true
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.distanceMeters = distanceMeters
        self.estimatedTravelTime = estimatedTravelTime
        self.phoneNumber = phoneNumber
        self.hasEmergencyDepartment = hasEmergencyDepartment
    }
}

public extension Hospital {
    var distanceKilometers: Double { distanceMeters / 1_000 }

    var estimatedTravelMinutes: Int { Int((estimatedTravelTime / 60).rounded()) }
}
