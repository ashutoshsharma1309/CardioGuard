//
//  RiskAssessmentEngineTests.swift
//  CardioGuardTests
//
//  Unit tests for the pure scoring engine — the highest-value tests in the app.
//

import Testing
import Foundation
@testable import CardioGuard

@Suite("RiskAssessmentEngine")
struct RiskAssessmentEngineTests {

    private let engine = RiskAssessmentEngine(configuration: .default)

    // Fixed reference date so staleness logic is deterministic.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func vitals(hr: Double?, spo2: Double?, previousHR: Double? = nil) -> VitalSigns {
        VitalSigns(
            heartRate: hr.map { HeartRateReading(beatsPerMinute: $0, timestamp: now, source: .simulated) },
            oxygen: spo2.map { OxygenReading(percentage: $0, timestamp: now, source: .simulated) },
            previousHeartRate: previousHR.map { HeartRateReading(beatsPerMinute: $0, timestamp: now, source: .simulated) },
            capturedAt: now
        )
    }

    @Test("Normal vitals produce a zero score")
    func normalVitals() {
        let result = engine.assess(vitals(hr: 72, spo2: 98), referenceDate: now)
        #expect(result.score == 0)
        #expect(result.level == .normal)
        #expect(result.triggeredFactors.filter { $0.points > 0 }.isEmpty)
    }

    @Test("High heart rate adds the configured points")
    func highHeartRate() {
        let result = engine.assess(vitals(hr: 145, spo2: 98), referenceDate: now)
        #expect(result.score == 40)
        #expect(result.triggeredFactors.contains { $0.code == .heartRateHigh })
    }

    @Test("Low heart rate adds the configured points")
    func lowHeartRate() {
        let result = engine.assess(vitals(hr: 38, spo2: 98), referenceDate: now)
        #expect(result.score == 40)
        #expect(result.triggeredFactors.contains { $0.code == .heartRateLow })
    }

    @Test("Critically low oxygen adds 50 points")
    func criticalOxygen() {
        let result = engine.assess(vitals(hr: 72, spo2: 88), referenceDate: now)
        #expect(result.score == 50)
        #expect(result.triggeredFactors.contains { $0.code == .oxygenCritical })
    }

    @Test("Rapid heart-rate change is detected")
    func rapidChange() {
        let result = engine.assess(vitals(hr: 110, spo2: 98, previousHR: 70), referenceDate: now)
        #expect(result.triggeredFactors.contains { $0.code == .rapidHeartRateChange })
        #expect(result.score == 25)
    }

    @Test("Compound cardiac + respiratory abnormality crosses the critical threshold")
    func compoundAbnormality() {
        // High HR (40) + critical SpO2 (50) + compound bonus (20) = 110 → critical.
        let result = engine.assess(vitals(hr: 150, spo2: 86), referenceDate: now)
        #expect(result.triggeredFactors.contains { $0.code == .compoundAbnormalSignals })
        #expect(result.score >= 80)
        #expect(result.level == .critical)
        #expect(result.level.requiresEmergencyAlert)
    }

    @Test("Two cardiac factors do NOT count as compound (same physiological system)")
    func noFalseCompound() {
        // High HR + rapid change are both cardiac → no compound bonus.
        let result = engine.assess(vitals(hr: 150, spo2: 98, previousHR: 100), referenceDate: now)
        #expect(!result.triggeredFactors.contains { $0.code == .compoundAbnormalSignals })
    }

    @Test("Stale data is flagged but contributes zero points")
    func staleData() {
        let stale = VitalSigns(
            heartRate: HeartRateReading(beatsPerMinute: 72, timestamp: now.addingTimeInterval(-120), source: .simulated),
            oxygen: OxygenReading(percentage: 98, timestamp: now, source: .simulated),
            capturedAt: now
        )
        let result = engine.assess(stale, referenceDate: now)
        #expect(result.triggeredFactors.contains { $0.code == .staleData })
        #expect(result.score == 0)
    }

    @Test("Custom configuration changes scoring", arguments: [
        (threshold: 120.0, hr: 130.0, expectsHigh: true),
        (threshold: 120.0, hr: 110.0, expectsHigh: false)
    ])
    func customConfiguration(threshold: Double, hr: Double, expectsHigh: Bool) {
        let config = RiskConfiguration(highHeartRateThreshold: threshold)
        let customEngine = RiskAssessmentEngine(configuration: config)
        let result = customEngine.assess(vitals(hr: hr, spo2: 98), referenceDate: now)
        #expect(result.triggeredFactors.contains { $0.code == .heartRateHigh } == expectsHigh)
    }

    @Test("The engine is deterministic for identical input")
    func determinism() {
        let v = vitals(hr: 150, spo2: 86)
        let a = engine.assess(v, referenceDate: now)
        let b = engine.assess(v, referenceDate: now)
        #expect(a.score == b.score)
        #expect(a.level == b.level)
    }
}
