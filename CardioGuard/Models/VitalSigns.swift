//
//  VitalSigns.swift
//  CardioGuard
//
//  An aggregated, point-in-time snapshot of the user's monitored vitals.
//

import Foundation

/// A consolidated snapshot of the most recent vitals.
///
/// `VitalSigns` is the unit of data that flows from the Watch to the phone and
/// into the `RiskAssessmentEngine`. Optional fields model the reality that the
/// two sensors sample at different cadences — we may have a fresh heart rate
/// before the next SpO2 reading lands.
public struct VitalSigns: Codable, Hashable, Sendable, Identifiable {

    public let id: UUID

    public let heartRate: HeartRateReading?

    public let oxygen: OxygenReading?

    /// The previous heart-rate reading, retained so the engine can detect
    /// *rapid* changes without holding global history.
    public let previousHeartRate: HeartRateReading?

    /// When this snapshot was assembled (not when the sensors fired).
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        heartRate: HeartRateReading? = nil,
        oxygen: OxygenReading? = nil,
        previousHeartRate: HeartRateReading? = nil,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.heartRate = heartRate
        self.oxygen = oxygen
        self.previousHeartRate = previousHeartRate
        self.capturedAt = capturedAt
    }
}

public extension VitalSigns {

    /// Absolute beats-per-minute delta vs. the previous reading, if both exist.
    var heartRateDelta: Double? {
        guard let current = heartRate, let previous = previousHeartRate else { return nil }
        return abs(current.beatsPerMinute - previous.beatsPerMinute)
    }

    /// Seconds elapsed since the heart-rate sample was taken. Used to decide
    /// whether the data is stale enough to distrust.
    func heartRateAge(referenceDate: Date = Date()) -> TimeInterval? {
        guard let hr = heartRate else { return nil }
        return referenceDate.timeIntervalSince(hr.timestamp)
    }

    /// A placeholder snapshot used before any data has arrived.
    static let empty = VitalSigns()
}
