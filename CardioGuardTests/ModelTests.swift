//
//  ModelTests.swift
//  CardioGuardTests
//
//  Tests for value-type model behavior and Codable round-trips (the wire format).
//

import Testing
import Foundation
@testable import CardioGuard

@Suite("Models")
struct ModelTests {

    @Test("VitalSigns encodes and decodes losslessly (Watch ↔ phone wire format)")
    func vitalsCodableRoundTrip() throws {
        let original = PreviewData.criticalVitals
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VitalSigns.self, from: data)
        #expect(decoded == original)
    }

    @Test("Heart-rate classification buckets are correct", arguments: [
        (bpm: 35.0, expected: HeartRateClassification.criticallyLow),
        (bpm: 55.0, expected: .low),
        (bpm: 72.0, expected: .normal),
        (bpm: 120.0, expected: .elevated),
        (bpm: 165.0, expected: .criticallyHigh)
    ])
    func heartRateClassification(bpm: Double, expected: HeartRateClassification) {
        #expect(HeartRateReading(beatsPerMinute: bpm).classification == expected)
    }

    @Test("Oxygen classification buckets are correct", arguments: [
        (spo2: 88.0, expected: OxygenClassification.critical),
        (spo2: 92.0, expected: .low),
        (spo2: 98.0, expected: .normal)
    ])
    func oxygenClassification(spo2: Double, expected: OxygenClassification) {
        #expect(OxygenReading(percentage: spo2).classification == expected)
    }

    @Test("Heart-rate delta is the absolute difference")
    func heartRateDelta() {
        let v = VitalSigns(
            heartRate: HeartRateReading(beatsPerMinute: 70),
            previousHeartRate: HeartRateReading(beatsPerMinute: 110)
        )
        #expect(v.heartRateDelta == 40)
    }

    @Test("LocationData distance is symmetric and non-negative")
    func locationDistance() {
        let a = LocationData(latitude: 37.0, longitude: -122.0)
        let b = LocationData(latitude: 37.1, longitude: -122.1)
        #expect(a.distance(to: b) > 0)
        #expect(abs(a.distance(to: b) - b.distance(to: a)) < 0.001)
    }
}
