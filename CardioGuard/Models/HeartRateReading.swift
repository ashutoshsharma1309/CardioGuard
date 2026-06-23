//
//  HeartRateReading.swift
//  CardioGuard
//
//  A single immutable heart-rate sample produced by the Apple Watch.
//

import Foundation

/// Represents a single heart-rate measurement captured at a point in time.
///
/// Readings are intentionally `Sendable` value types so they can be safely
/// passed across actor / concurrency boundaries (Watch → iPhone → engine).
public struct HeartRateReading: Codable, Hashable, Sendable, Identifiable {

    /// Stable identity for SwiftUI diffing and de-duplication.
    public let id: UUID

    /// Beats per minute.
    public let beatsPerMinute: Double

    /// The moment the sample was recorded on the source device.
    public let timestamp: Date

    /// Origin of the reading. Useful for auditing and for unit-test injection.
    public let source: VitalSource

    public init(
        id: UUID = UUID(),
        beatsPerMinute: Double,
        timestamp: Date = Date(),
        source: VitalSource = .appleWatch
    ) {
        self.id = id
        self.beatsPerMinute = beatsPerMinute
        self.timestamp = timestamp
        self.source = source
    }
}

public extension HeartRateReading {
    /// Convenience classification used by UI badges and the risk engine.
    var classification: HeartRateClassification {
        switch beatsPerMinute {
        case ..<40:     return .criticallyLow
        case 40..<60:   return .low
        case 60...100:  return .normal
        case 100...140: return .elevated
        default:        return .criticallyHigh
        }
    }
}

/// Coarse heart-rate bucket for display and quick risk reasoning.
public enum HeartRateClassification: String, Sendable {
    case criticallyLow
    case low
    case normal
    case elevated
    case criticallyHigh
}
