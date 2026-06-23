//
//  HealthKitManager.swift
//  CardioGuard
//
//  Concrete HealthKit integration, isolated behind the `HealthMonitoring` seam.
//

import Foundation
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

/// Streams live heart-rate and SpO2 samples from HealthKit and consolidates
/// them into `VitalSigns`.
///
/// ## Why an actor-isolated `final class` behind a protocol?
/// HealthKit's APIs are callback-based and not `Sendable`. We confine all
/// HealthKit interaction to this one type and expose only value types
/// (`VitalSigns`) through a Combine publisher. The rest of the app depends on
/// `HealthMonitoring`, so it can run against `MockHealthKitManager` in previews,
/// tests, and on the Simulator (where HealthKit sampling is unavailable).
public final class HealthKitManager: HealthMonitoring, @unchecked Sendable {

    private let subject = CurrentValueSubject<VitalSigns, Never>(.empty)
    public var vitalsPublisher: AnyPublisher<VitalSigns, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Guards mutable state (`latestVitals`, query handles) under serial access.
    private let stateQueue = DispatchQueue(label: "com.cardioguard.healthkit.state")
    private var latestVitals = VitalSigns.empty

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var activeQueries: [HKQuery] = []

    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    private var oxygenType: HKQuantityType { HKQuantityType(.oxygenSaturation) }
    #endif

    public init() {}

    // MARK: - Authorization

    public func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CardioGuardError.healthDataUnavailable
        }
        let readTypes: Set<HKObjectType> = [heartRateType, oxygenType]
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            AppLogger.health.info("HealthKit authorization request completed")
        } catch {
            throw CardioGuardError.healthQueryFailed(error.localizedDescription)
        }
        #else
        throw CardioGuardError.healthDataUnavailable
        #endif
    }

    // MARK: - Monitoring

    public func startMonitoring() async throws {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CardioGuardError.healthDataUnavailable
        }
        startAnchoredQuery(for: heartRateType, unit: .count().unitDivided(by: .minute())) { [weak self] value, date in
            self?.ingestHeartRate(value, at: date)
        }
        startAnchoredQuery(for: oxygenType, unit: .percent()) { [weak self] value, date in
            // HealthKit reports SpO2 in the 0...1 range; convert to a percentage.
            self?.ingestOxygen(value * 100, at: date)
        }
        AppLogger.health.info("Started HealthKit monitoring")
        #else
        throw CardioGuardError.healthDataUnavailable
        #endif
    }

    public func stopMonitoring() {
        #if canImport(HealthKit)
        stateQueue.sync {
            activeQueries.forEach { store.stop($0) }
            activeQueries.removeAll()
        }
        AppLogger.health.info("Stopped HealthKit monitoring")
        #endif
    }

    // MARK: - Ingestion (publishes consolidated snapshots)

    private func ingestHeartRate(_ bpm: Double, at date: Date) {
        let reading = HeartRateReading(beatsPerMinute: bpm, timestamp: date, source: .healthKitQuery)
        stateQueue.async { [weak self] in
            guard let self else { return }
            let previous = self.latestVitals.heartRate
            self.latestVitals = VitalSigns(
                heartRate: reading,
                oxygen: self.latestVitals.oxygen,
                previousHeartRate: previous,
                capturedAt: Date()
            )
            self.subject.send(self.latestVitals)
        }
    }

    private func ingestOxygen(_ percentage: Double, at date: Date) {
        let reading = OxygenReading(percentage: percentage, timestamp: date, source: .healthKitQuery)
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.latestVitals = VitalSigns(
                heartRate: self.latestVitals.heartRate,
                oxygen: reading,
                previousHeartRate: self.latestVitals.previousHeartRate,
                capturedAt: Date()
            )
            self.subject.send(self.latestVitals)
        }
    }

    // MARK: - Query plumbing

    #if canImport(HealthKit)
    /// Installs an anchored object query with a long-running update handler so we
    /// receive new samples as the Watch produces them.
    private func startAnchoredQuery(
        for type: HKQuantityType,
        unit: HKUnit,
        onSample: @escaping (Double, Date) -> Void
    ) {
        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { _, samples, _, _, error in
            if let error {
                AppLogger.health.error("Query failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let quantitySamples = samples as? [HKQuantitySample] else { return }
            for sample in quantitySamples {
                onSample(sample.quantity.doubleValue(for: unit), sample.endDate)
            }
        }

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        store.execute(query)
        stateQueue.sync { activeQueries.append(query) }
    }
    #endif
}
