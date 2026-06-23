//
//  RiskAssessmentEngine.swift
//  CardioGuard
//
//  The deterministic, configurable scoring engine at the core of the product.
//

import Foundation

/// Evaluates a `VitalSigns` snapshot into a `RiskAssessment`.
///
/// ## Design
/// The engine is a **pure value type**: it holds only configuration and has no
/// mutable state, no I/O, and no framework dependencies. This yields three wins:
///
/// 1. **Testability** — identical input always yields identical output, so unit
///    tests need no mocks or async waiting.
/// 2. **Thread-safety** — being immutable and `Sendable`, it can be called from
///    any actor without synchronization.
/// 3. **Explainability** — every point is attached to a `RiskFactor` carrying a
///    human-readable reason, so the UI and emergency report can justify alerts.
///
/// Scoring policy lives in `RiskConfiguration`, honoring the Open/Closed
/// principle: tune thresholds without editing this file.
public struct RiskAssessmentEngine: RiskAssessing {

    public let configuration: RiskConfiguration

    public init(configuration: RiskConfiguration = .default) {
        self.configuration = configuration
    }

    public func assess(_ vitals: VitalSigns, referenceDate: Date = Date()) -> RiskAssessment {
        var factors: [RiskFactor] = []

        evaluateHeartRate(vitals.heartRate, into: &factors)
        evaluateOxygen(vitals.oxygen, into: &factors)
        evaluateRapidChange(vitals, into: &factors)
        evaluateStaleness(vitals, referenceDate: referenceDate, into: &factors)

        // Compound abnormality: two or more *independent* abnormal vital signals
        // raise concern beyond the linear sum. We count distinct physiological
        // systems (cardiac vs. respiratory), not raw factor count.
        let abnormalSignals = countDistinctAbnormalSignals(in: factors)
        if abnormalSignals >= 2 {
            factors.append(
                RiskFactor(
                    code: .compoundAbnormalSignals,
                    points: configuration.compoundAbnormalityBonus,
                    explanation: "\(abnormalSignals) abnormal vital signs detected simultaneously"
                )
            )
        }

        let score = factors.reduce(0) { $0 + $1.points }
        let level = configuration.level(for: score)

        let assessment = RiskAssessment(
            score: score,
            level: level,
            triggeredFactors: factors,
            evaluatedVitals: vitals,
            evaluatedAt: referenceDate
        )

        AppLogger.risk.debug("Assessed risk \(score, privacy: .public) -> \(level.displayName, privacy: .public)")
        return assessment
    }

    // MARK: - Individual rules

    private func evaluateHeartRate(_ reading: HeartRateReading?, into factors: inout [RiskFactor]) {
        guard let bpm = reading?.beatsPerMinute else { return }

        if bpm >= configuration.highHeartRateThreshold {
            factors.append(
                RiskFactor(
                    code: .heartRateHigh,
                    points: configuration.highHeartRatePoints,
                    explanation: "Heart rate \(Int(bpm)) bpm exceeds \(Int(configuration.highHeartRateThreshold)) bpm"
                )
            )
        } else if bpm <= configuration.lowHeartRateThreshold {
            factors.append(
                RiskFactor(
                    code: .heartRateLow,
                    points: configuration.lowHeartRatePoints,
                    explanation: "Heart rate \(Int(bpm)) bpm below \(Int(configuration.lowHeartRateThreshold)) bpm"
                )
            )
        }
    }

    private func evaluateOxygen(_ reading: OxygenReading?, into factors: inout [RiskFactor]) {
        guard let spo2 = reading?.percentage else { return }

        if spo2 < configuration.criticalOxygenThreshold {
            factors.append(
                RiskFactor(
                    code: .oxygenCritical,
                    points: configuration.criticalOxygenPoints,
                    explanation: "Blood oxygen \(Int(spo2))% critically low (< \(Int(configuration.criticalOxygenThreshold))%)"
                )
            )
        } else if spo2 < configuration.lowOxygenThreshold {
            factors.append(
                RiskFactor(
                    code: .oxygenLow,
                    points: configuration.lowOxygenPoints,
                    explanation: "Blood oxygen \(Int(spo2))% below normal (< \(Int(configuration.lowOxygenThreshold))%)"
                )
            )
        }
    }

    private func evaluateRapidChange(_ vitals: VitalSigns, into factors: inout [RiskFactor]) {
        guard let delta = vitals.heartRateDelta, delta >= configuration.rapidHeartRateDelta else { return }
        factors.append(
            RiskFactor(
                code: .rapidHeartRateChange,
                points: configuration.rapidChangePoints,
                explanation: "Heart rate changed \(Int(delta)) bpm between readings"
            )
        )
    }

    private func evaluateStaleness(_ vitals: VitalSigns, referenceDate: Date, into factors: inout [RiskFactor]) {
        guard let age = vitals.heartRateAge(referenceDate: referenceDate),
              age > configuration.stalenessThreshold else { return }
        // Stale data is a *quality* signal, not a clinical one. We surface it for
        // transparency but assign zero points so it never triggers an alert alone.
        factors.append(
            RiskFactor(
                code: .staleData,
                points: 0,
                explanation: "Vitals are \(Int(age))s old"
            )
        )
    }

    /// Counts distinct physiological systems flagged, so two cardiac factors
    /// (e.g. high HR + rapid change) don't double-count as "compound".
    private func countDistinctAbnormalSignals(in factors: [RiskFactor]) -> Int {
        var systems = Set<String>()
        for factor in factors {
            switch factor.code {
            case .heartRateHigh, .heartRateLow, .rapidHeartRateChange:
                systems.insert("cardiac")
            case .oxygenCritical, .oxygenLow:
                systems.insert("respiratory")
            case .compoundAbnormalSignals, .staleData:
                break
            }
        }
        return systems.count
    }
}
