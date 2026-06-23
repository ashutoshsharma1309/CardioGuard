//
//  MonitoringPipelineTests.swift
//  CardioGuardTests
//
//  Verifies the reactive pipeline scores vitals and escalates correctly.
//

import Testing
import Foundation
@testable import CardioGuard

@MainActor
@Suite("MonitoringPipeline")
struct MonitoringPipelineTests {

    private func makeSUT() -> (MonitoringPipeline, MockConnectivityManager, EmergencyCoordinator) {
        let connectivity = MockConnectivityManager()
        let coordinator = EmergencyCoordinator(
            countdown: ImmediateCountdown(),
            locationProvider: MockLocationProvider(),
            hospitalLocator: HospitalLocatorMock(simulatedLatency: .zero),
            dispatcher: EmergencyDispatchMock(simulatedLatency: .zero),
            notifications: MockNotificationManager()
        )
        let pipeline = MonitoringPipeline(
            health: SimulatedVitalsProvider(scenario: .stableHealthy),
            connectivity: connectivity,
            engine: RiskAssessmentEngine(),
            coordinator: coordinator
        )
        pipeline.start()
        return (pipeline, connectivity, coordinator)
    }

    @Test("Vitals relayed from the Watch are scored")
    func scoresWatchVitals() {
        let (pipeline, connectivity, _) = makeSUT()
        connectivity.simulateReceive(PreviewData.healthyVitals)

        #expect(pipeline.latestVitals.heartRate?.beatsPerMinute == 72)
        #expect(pipeline.latestAssessment.level == .normal)
    }

    @Test("A critical snapshot escalates to the coordinator")
    func criticalEscalates() {
        let (pipeline, connectivity, coordinator) = makeSUT()
        connectivity.simulateReceive(PreviewData.criticalVitals)

        #expect(pipeline.latestAssessment.level == .critical)
        #expect(coordinator.presentation == .alert)
    }
}
