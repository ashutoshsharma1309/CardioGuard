//
//  RiskAssessment.swift
//  CardioGuard
//
//  The output of the RiskAssessmentEngine: a score, a level, and the reasons.
//

import Foundation

/// The result of evaluating a `VitalSigns` snapshot.
///
/// Carries not just a number but the *explanation* (`triggeredFactors`) so the
/// UI and the eventual emergency report can show **why** an alert fired. This
/// is critical for a medical-adjacent product: opaque scores erode trust.
public struct RiskAssessment: Codable, Hashable, Sendable, Identifiable {

    public let id: UUID

    /// Total accumulated score across all triggered factors.
    public let score: Int

    /// Bucketed severity derived from `score`.
    public let level: RiskLevel

    /// The individual rules that contributed to the score.
    public let triggeredFactors: [RiskFactor]

    /// The vitals that produced this assessment (for audit / reporting).
    public let evaluatedVitals: VitalSigns

    public let evaluatedAt: Date

    public init(
        id: UUID = UUID(),
        score: Int,
        level: RiskLevel,
        triggeredFactors: [RiskFactor],
        evaluatedVitals: VitalSigns,
        evaluatedAt: Date = Date()
    ) {
        self.id = id
        self.score = score
        self.level = level
        self.triggeredFactors = triggeredFactors
        self.evaluatedVitals = evaluatedVitals
        self.evaluatedAt = evaluatedAt
    }
}

public extension RiskAssessment {
    /// A neutral, low-risk assessment used as an initial UI state.
    static func baseline(_ vitals: VitalSigns = .empty) -> RiskAssessment {
        RiskAssessment(score: 0, level: .normal, triggeredFactors: [], evaluatedVitals: vitals)
    }

    /// Human-readable summary suitable for logs and emergency reports.
    var summary: String {
        guard !triggeredFactors.isEmpty else { return "All vitals within normal range." }
        let reasons = triggeredFactors.map(\.explanation).joined(separator: "; ")
        return "Risk \(score) (\(level.displayName)): \(reasons)"
    }
}

/// Bucketed severity. Thresholds are owned by `RiskConfiguration`.
public enum RiskLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case normal
    case elevated
    case high
    case critical

    public var displayName: String {
        switch self {
        case .normal:   return "Normal"
        case .elevated: return "Elevated"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }

    /// Whether this level should escalate into the emergency alert flow.
    public var requiresEmergencyAlert: Bool {
        self == .critical
    }
}

/// A single rule that fired during assessment, with its point contribution and
/// a human explanation. Identified by a stable `code` for analytics/testing.
public struct RiskFactor: Codable, Hashable, Sendable {
    public let code: Code
    public let points: Int
    public let explanation: String

    public init(code: Code, points: Int, explanation: String) {
        self.code = code
        self.points = points
        self.explanation = explanation
    }

    public enum Code: String, Codable, Hashable, Sendable {
        case heartRateHigh
        case heartRateLow
        case oxygenCritical
        case oxygenLow
        case rapidHeartRateChange
        case compoundAbnormalSignals
        case staleData
    }
}
