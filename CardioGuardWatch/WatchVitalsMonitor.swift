//
//  WatchVitalsMonitor.swift
//  CardioGuardWatch
//
//  Reads vitals on the Watch and relays them to the iPhone.
//

import Foundation
import Combine

/// Bridges the shared `HealthMonitoring` stream to the shared
/// `DeviceConnectivity` transport on the Watch.
///
/// Because both the HealthKit and WatchConnectivity managers are defined in code
/// shared with the iPhone target (same protocols, same models), the Watch reuses
/// them directly — no duplicated wire format, no drift between devices.
@MainActor
final class WatchVitalsMonitor: ObservableObject {

    @Published private(set) var latestHeartRate: Int = 0
    @Published private(set) var latestOxygen: Int = 0
    @Published private(set) var isStreaming = false

    private let health: HealthMonitoring
    private let connectivity: DeviceConnectivity
    private var cancellables = Set<AnyCancellable>()

    init(
        health: HealthMonitoring = HealthKitManager(),
        connectivity: DeviceConnectivity = WatchConnectivityManager()
    ) {
        self.health = health
        self.connectivity = connectivity
    }

    func start() async {
        connectivity.activate()

        health.vitalsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vitals in
                guard let self else { return }
                if let hr = vitals.heartRate { self.latestHeartRate = Int(hr.beatsPerMinute) }
                if let ox = vitals.oxygen { self.latestOxygen = Int(ox.percentage) }
                // Relay every consolidated snapshot to the phone for scoring.
                self.connectivity.send(vitals: vitals)
            }
            .store(in: &cancellables)

        do {
            try await health.requestAuthorization()
            try await health.startMonitoring()
            isStreaming = true
        } catch {
            AppLogger.health.error("Watch monitoring failed: \(error.localizedDescription, privacy: .public)")
            isStreaming = false
        }
    }

    func stop() {
        health.stopMonitoring()
        isStreaming = false
    }
}
