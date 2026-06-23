//
//  MonitoringPipeline.swift
//  CardioGuard
//
//  Wires the vitals stream through the risk engine into the emergency flow.
//

import Foundation
import Combine

/// The reactive backbone of the app on the iPhone side.
///
/// It merges vitals from **both** sources — direct HealthKit on the phone and
/// data relayed from the Watch — runs each snapshot through the (pure) risk
/// engine, and forwards critical assessments to the `EmergencyCoordinator`.
///
/// Keeping this orchestration in one small, observable type means ViewModels can
/// simply read `latestVitals` / `latestAssessment` rather than each re-subscribing
/// to raw streams (DRY + single source of truth).
@MainActor
public final class MonitoringPipeline: ObservableObject {

    @Published public private(set) var latestVitals: VitalSigns = .empty
    @Published public private(set) var latestAssessment: RiskAssessment = .baseline()
    @Published public private(set) var connectionState: ConnectivityState = .notActivated

    private let health: HealthMonitoring
    private let connectivity: DeviceConnectivity
    private let engine: RiskAssessing
    private let coordinator: EmergencyCoordinator

    private var cancellables = Set<AnyCancellable>()

    public init(
        health: HealthMonitoring,
        connectivity: DeviceConnectivity,
        engine: RiskAssessing,
        coordinator: EmergencyCoordinator
    ) {
        self.health = health
        self.connectivity = connectivity
        self.engine = engine
        self.coordinator = coordinator
    }

    /// Begins authorization, activation, and the reactive evaluation pipeline.
    public func start() {
        connectivity.activate()

        // Merge both vitals sources into a single evaluated stream.
        Publishers.Merge(health.vitalsPublisher, connectivity.receivedVitalsPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vitals in
                self?.process(vitals)
            }
            .store(in: &cancellables)

        connectivity.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        Task { [weak self] in
            guard let self else { return }
            try? await self.health.requestAuthorization()
            try? await self.health.startMonitoring()
        }
    }

    public func stop() {
        health.stopMonitoring()
        cancellables.removeAll()
    }

    /// Evaluates one snapshot and escalates if the assessment is critical.
    private func process(_ vitals: VitalSigns) {
        latestVitals = vitals
        let assessment = engine.assess(vitals)
        latestAssessment = assessment

        if assessment.level.requiresEmergencyAlert {
            coordinator.handleCriticalAssessment(assessment)
        }
    }
}
