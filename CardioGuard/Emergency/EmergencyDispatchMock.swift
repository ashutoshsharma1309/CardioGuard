//
//  EmergencyDispatchMock.swift
//  CardioGuard
//
//  A deterministic stand-in for a real emergency-dispatch integration.
//

import Foundation

/// Simulates contacting emergency services and receiving a dispatch confirmation.
///
/// A real implementation might integrate with a regional PSAP / telematics
/// provider. We keep the same async signature so the coordinator is agnostic to
/// whether dispatch is real or simulated.
public struct EmergencyDispatchMock: EmergencyDispatching {

    private let simulatedLatency: Duration

    public init(simulatedLatency: Duration = .milliseconds(800)) {
        self.simulatedLatency = simulatedLatency
    }

    public func dispatch(for event: EmergencyEvent) async throws -> DispatchConfirmation {
        if simulatedLatency > .zero {
            try await Task.sleep(for: simulatedLatency)
        }

        guard let hospital = event.nearestHospital else {
            throw CardioGuardError.dispatchFailed("No receiving hospital resolved")
        }

        let now = Date()
        let confirmation = DispatchConfirmation(
            referenceCode: Self.makeReferenceCode(for: event),
            dispatchedAt: now,
            estimatedArrival: now.addingTimeInterval(hospital.estimatedTravelTime),
            respondingUnit: "Ambulance Unit 7"
        )
        AppLogger.emergency.notice("Dispatch confirmed: \(confirmation.referenceCode, privacy: .public)")
        return confirmation
    }

    /// Builds a stable, human-readable reference from the event id.
    private static func makeReferenceCode(for event: EmergencyEvent) -> String {
        let suffix = event.id.uuidString.prefix(6).uppercased()
        return "CG-\(suffix)"
    }
}
