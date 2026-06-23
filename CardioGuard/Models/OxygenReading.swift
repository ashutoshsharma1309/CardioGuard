//
//  OxygenReading.swift
//  CardioGuard
//
//  A single immutable blood-oxygen (SpO2) sample produced by the Apple Watch.
//

import Foundation

/// Represents a single blood-oxygen saturation measurement.
///
/// SpO2 is stored as a percentage in the range `0...100`.
public struct OxygenReading: Codable, Hashable, Sendable, Identifiable {

    public let id: UUID

    /// Blood-oxygen saturation as a percentage (e.g. `97.0`).
    public let percentage: Double

    public let timestamp: Date

    public let source: VitalSource

    public init(
        id: UUID = UUID(),
        percentage: Double,
        timestamp: Date = Date(),
        source: VitalSource = .appleWatch
    ) {
        self.id = id
        self.percentage = percentage
        self.timestamp = timestamp
        self.source = source
    }
}

public extension OxygenReading {
    /// Clinical-style classification for UI and risk reasoning.
    var classification: OxygenClassification {
        switch percentage {
        case ..<90:    return .critical
        case 90..<95:  return .low
        default:       return .normal
        }
    }
}

/// Coarse SpO2 bucket. 95–100% is generally considered normal.
public enum OxygenClassification: String, Sendable {
    case critical
    case low
    case normal
}
