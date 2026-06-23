//
//  EmergencyEvent.swift
//  CardioGuard
//
//  The canonical record of an emergency from detection through dispatch.
//

import Foundation

/// A complete, auditable record of one emergency episode.
///
/// This is the artifact a clinician or responder would actually consume. It is
/// assembled incrementally by `EmergencyCoordinator` as the protocol advances,
/// which is why most fields are optional until their stage completes.
public struct EmergencyEvent: Codable, Hashable, Sendable, Identifiable {

    public let id: UUID

    /// The assessment that triggered the emergency.
    public let triggeringAssessment: RiskAssessment

    /// When the emergency protocol began.
    public let initiatedAt: Date

    /// Captured GPS fix (stage 1). Nil until location resolves.
    public var location: LocationData?

    /// Nearest facility (stage 3). Nil until lookup completes.
    public var nearestHospital: Hospital?

    /// Result of the simulated dispatch (stage 4).
    public var dispatch: DispatchConfirmation?

    /// Current lifecycle stage.
    public var status: Status

    public init(
        id: UUID = UUID(),
        triggeringAssessment: RiskAssessment,
        initiatedAt: Date = Date(),
        location: LocationData? = nil,
        nearestHospital: Hospital? = nil,
        dispatch: DispatchConfirmation? = nil,
        status: Status = .initiated
    ) {
        self.id = id
        self.triggeringAssessment = triggeringAssessment
        self.initiatedAt = initiatedAt
        self.location = location
        self.nearestHospital = nearestHospital
        self.dispatch = dispatch
        self.status = status
    }

    /// Lifecycle of an emergency episode.
    public enum Status: String, Codable, Hashable, Sendable {
        case initiated          // alert fired, user did not respond in time
        case locating           // acquiring GPS
        case locatingHospital   // finding nearest facility
        case dispatching        // contacting emergency services (mock)
        case dispatched         // responders en route (mock)
        case resolvedByUser     // user tapped "I'm Fine" before timeout
        case failed             // a stage errored irrecoverably
    }
}

/// Confirmation returned by the (mock) dispatch service.
public struct DispatchConfirmation: Codable, Hashable, Sendable {
    public let referenceCode: String
    public let dispatchedAt: Date
    public let estimatedArrival: Date
    public let respondingUnit: String

    public init(
        referenceCode: String,
        dispatchedAt: Date,
        estimatedArrival: Date,
        respondingUnit: String
    ) {
        self.referenceCode = referenceCode
        self.dispatchedAt = dispatchedAt
        self.estimatedArrival = estimatedArrival
        self.respondingUnit = respondingUnit
    }
}
