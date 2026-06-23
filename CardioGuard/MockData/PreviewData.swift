//
//  PreviewData.swift
//  CardioGuard
//
//  Deterministic fixtures for SwiftUI previews.
//

import Foundation

/// Namespaced sample objects used throughout `#Preview` blocks.
public enum PreviewData {

    public static let healthyVitals = VitalSigns(
        heartRate: HeartRateReading(beatsPerMinute: 72, source: .simulated),
        oxygen: OxygenReading(percentage: 98, source: .simulated),
        previousHeartRate: HeartRateReading(beatsPerMinute: 70, source: .simulated)
    )

    public static let criticalVitals = VitalSigns(
        heartRate: HeartRateReading(beatsPerMinute: 168, source: .simulated),
        oxygen: OxygenReading(percentage: 86, source: .simulated),
        previousHeartRate: HeartRateReading(beatsPerMinute: 120, source: .simulated)
    )

    public static let engine = RiskAssessmentEngine(configuration: .default)

    public static let healthyAssessment = engine.assess(healthyVitals)
    public static let criticalAssessment = engine.assess(criticalVitals)

    public static let hospital = Hospital(
        name: "St. Mary's Medical Center",
        location: .sample,
        distanceMeters: 1_840,
        estimatedTravelTime: 165,
        phoneNumber: "+1-555-0142"
    )

    public static var dispatchedEvent: EmergencyEvent {
        var event = EmergencyEvent(triggeringAssessment: criticalAssessment, status: .dispatched)
        event.location = .sample
        event.nearestHospital = hospital
        event.dispatch = DispatchConfirmation(
            referenceCode: "CG-A1B2C3",
            dispatchedAt: Date(),
            estimatedArrival: Date().addingTimeInterval(165),
            respondingUnit: "Ambulance Unit 7"
        )
        return event
    }
}
