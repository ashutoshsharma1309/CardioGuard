//
//  SimulatedVitalsProvider.swift
//  CardioGuard
//
//  A scripted vitals source conforming to `HealthMonitoring` for demos/previews.
//

import Foundation
import Combine

/// Emits a scripted stream of `VitalSigns` on a timer.
///
/// Because it conforms to the same `HealthMonitoring` protocol as the real
/// `HealthKitManager`, the entire app (engine, pipeline, emergency flow) can be
/// driven end-to-end on a Simulator with no Watch and no HealthKit — invaluable
/// for demos, UI previews, and recording a deterministic "emergency" scenario.
public final class SimulatedVitalsProvider: HealthMonitoring, @unchecked Sendable {

    /// Predefined clinical narratives.
    public enum Scenario: Sendable {
        case stableHealthy
        case escalating       // gradually climbs into a critical heart rate + low SpO2
        case suddenCritical   // jumps straight to a dangerous reading
    }

    private let subject = CurrentValueSubject<VitalSigns, Never>(.empty)
    public var vitalsPublisher: AnyPublisher<VitalSigns, Never> { subject.eraseToAnyPublisher() }

    private let scenario: Scenario
    private let interval: TimeInterval
    private var timerCancellable: AnyCancellable?
    private var tick = 0
    private var previousHeartRate: HeartRateReading?

    public init(scenario: Scenario = .stableHealthy, interval: TimeInterval = 2.0) {
        self.scenario = scenario
        self.interval = interval
    }

    public func requestAuthorization() async throws { /* always authorized */ }

    public func startMonitoring() async throws {
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.emitNext() }
        emitNext()
    }

    public func stopMonitoring() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func emitNext() {
        let (bpm, spo2) = nextSample()
        let hr = HeartRateReading(beatsPerMinute: bpm, source: .simulated)
        let ox = OxygenReading(percentage: spo2, source: .simulated)
        let vitals = VitalSigns(
            heartRate: hr,
            oxygen: ox,
            previousHeartRate: previousHeartRate,
            capturedAt: Date()
        )
        previousHeartRate = hr
        tick += 1
        subject.send(vitals)
    }

    /// Returns the next (heartRate, spo2) pair for the active scenario.
    private func nextSample() -> (Double, Double) {
        switch scenario {
        case .stableHealthy:
            return (72 + Double(tick % 5), 98)

        case .escalating:
            // Ramp the heart rate ~12 bpm per tick toward a critical level while
            // SpO2 sags, so the engine crosses the threshold around tick 7–8.
            let bpm = min(170, 90 + Double(tick) * 12)
            let spo2 = max(86, 97 - Double(tick))
            return (bpm, spo2)

        case .suddenCritical:
            return tick == 0 ? (75, 98) : (175, 84)
        }
    }
}
