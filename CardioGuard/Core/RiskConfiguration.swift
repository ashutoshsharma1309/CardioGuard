//
//  RiskConfiguration.swift
//  CardioGuard
//
//  The single source of truth for all risk-scoring thresholds and weights.
//

import Foundation

/// All tunable parameters for the `RiskAssessmentEngine`.
///
/// Externalizing the policy from the engine is a deliberate Open/Closed-principle
/// decision: we can re-tune scoring (or load it from a remote config / A-B test)
/// **without touching the engine's logic**, and tests can inject extreme values
/// to exercise specific branches deterministically.
public struct RiskConfiguration: Codable, Hashable, Sendable {

    // MARK: Heart-rate thresholds (bpm)

    public var highHeartRateThreshold: Double
    public var lowHeartRateThreshold: Double
    public var criticalHighHeartRateThreshold: Double
    public var criticalLowHeartRateThreshold: Double

    /// Absolute bpm delta between consecutive readings considered "rapid".
    public var rapidHeartRateDelta: Double

    // MARK: Oxygen thresholds (%)

    public var lowOxygenThreshold: Double
    public var criticalOxygenThreshold: Double

    // MARK: Point weights

    public var highHeartRatePoints: Int
    public var lowHeartRatePoints: Int
    public var criticalOxygenPoints: Int
    public var lowOxygenPoints: Int
    public var rapidChangePoints: Int

    /// Extra points when two or more independent abnormal signals coincide.
    /// Compound abnormalities are clinically more concerning than the sum of
    /// their parts, so we add a bonus to bias toward escalation.
    public var compoundAbnormalityBonus: Int

    // MARK: Data-quality

    /// Readings older than this (seconds) are treated as stale.
    public var stalenessThreshold: TimeInterval

    // MARK: Level cutoffs (score → level)

    public var elevatedScoreCutoff: Int
    public var highScoreCutoff: Int
    public var criticalScoreCutoff: Int

    public init(
        highHeartRateThreshold: Double = 140,
        lowHeartRateThreshold: Double = 50,
        criticalHighHeartRateThreshold: Double = 160,
        criticalLowHeartRateThreshold: Double = 40,
        rapidHeartRateDelta: Double = 30,
        lowOxygenThreshold: Double = 94,
        criticalOxygenThreshold: Double = 90,
        highHeartRatePoints: Int = 40,
        lowHeartRatePoints: Int = 40,
        criticalOxygenPoints: Int = 50,
        lowOxygenPoints: Int = 20,
        rapidChangePoints: Int = 25,
        compoundAbnormalityBonus: Int = 20,
        stalenessThreshold: TimeInterval = 30,
        elevatedScoreCutoff: Int = 30,
        highScoreCutoff: Int = 60,
        criticalScoreCutoff: Int = 80
    ) {
        self.highHeartRateThreshold = highHeartRateThreshold
        self.lowHeartRateThreshold = lowHeartRateThreshold
        self.criticalHighHeartRateThreshold = criticalHighHeartRateThreshold
        self.criticalLowHeartRateThreshold = criticalLowHeartRateThreshold
        self.rapidHeartRateDelta = rapidHeartRateDelta
        self.lowOxygenThreshold = lowOxygenThreshold
        self.criticalOxygenThreshold = criticalOxygenThreshold
        self.highHeartRatePoints = highHeartRatePoints
        self.lowHeartRatePoints = lowHeartRatePoints
        self.criticalOxygenPoints = criticalOxygenPoints
        self.lowOxygenPoints = lowOxygenPoints
        self.rapidChangePoints = rapidChangePoints
        self.compoundAbnormalityBonus = compoundAbnormalityBonus
        self.stalenessThreshold = stalenessThreshold
        self.elevatedScoreCutoff = elevatedScoreCutoff
        self.highScoreCutoff = highScoreCutoff
        self.criticalScoreCutoff = criticalScoreCutoff
    }

    /// The default, clinically-inspired configuration shipped with the app.
    public static let `default` = RiskConfiguration()

    /// Maps a numeric score to a `RiskLevel` using the configured cutoffs.
    public func level(for score: Int) -> RiskLevel {
        switch score {
        case criticalScoreCutoff...:            return .critical
        case highScoreCutoff..<criticalScoreCutoff: return .high
        case elevatedScoreCutoff..<highScoreCutoff: return .elevated
        default:                                return .normal
        }
    }
}
