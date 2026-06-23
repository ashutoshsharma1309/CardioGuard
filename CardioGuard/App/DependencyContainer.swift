//
//  DependencyContainer.swift
//  CardioGuard
//
//  The composition root. The ONLY place concrete services are constructed.
//

import Foundation

/// Composition root for the iPhone app.
///
/// This is where the object graph is assembled. Every other type receives its
/// collaborators through `init` (constructor injection) and depends only on
/// protocols. Centralizing construction here means:
///
/// - There is exactly one place to swap a real service for a mock.
/// - The wiring is explicit and reviewable, with no hidden singletons.
/// - Tests build their own graph with fakes, never importing this container.
///
/// `@MainActor` because it vends UI-bound objects (`EmergencyCoordinator`,
/// `MonitoringPipeline`).
@MainActor
public final class DependencyContainer: ObservableObject {

    // Long-lived services
    public let health: HealthMonitoring
    public let connectivity: DeviceConnectivity
    public let engine: RiskAssessing
    public let locationProvider: LocationProviding
    public let notifications: NotificationScheduling

    // Orchestrators (observed by SwiftUI)
    public let coordinator: EmergencyCoordinator
    public let pipeline: MonitoringPipeline

    /// Designated initializer used by both production and tests.
    public init(
        health: HealthMonitoring,
        connectivity: DeviceConnectivity,
        engine: RiskAssessing,
        locationProvider: LocationProviding,
        notifications: NotificationScheduling,
        hospitalLocator: HospitalLocating,
        dispatcher: EmergencyDispatching,
        countdown: CountdownTiming
    ) {
        self.health = health
        self.connectivity = connectivity
        self.engine = engine
        self.locationProvider = locationProvider
        self.notifications = notifications

        let coordinator = EmergencyCoordinator(
            countdown: countdown,
            locationProvider: locationProvider,
            hospitalLocator: hospitalLocator,
            dispatcher: dispatcher,
            notifications: notifications
        )
        self.coordinator = coordinator

        self.pipeline = MonitoringPipeline(
            health: health,
            connectivity: connectivity,
            engine: engine,
            coordinator: coordinator
        )
    }

    /// Production graph wired with real framework-backed services and the
    /// (mock) emergency sub-services as specified.
    public static func live() -> DependencyContainer {
        DependencyContainer(
            health: HealthKitManager(),
            connectivity: WatchConnectivityManager(),
            engine: RiskAssessmentEngine(configuration: .default),
            locationProvider: LocationManager(),
            notifications: NotificationManager(),
            hospitalLocator: HospitalLocatorMock(),
            dispatcher: EmergencyDispatchMock(),
            countdown: AlertTimerManager()
        )
    }

    /// Preview/demo graph driven by a deterministic simulated data stream.
    /// Useful for SwiftUI previews and on-device demos without a paired Watch.
    public static func simulated(scenario: SimulatedVitalsProvider.Scenario = .escalating) -> DependencyContainer {
        DependencyContainer(
            health: SimulatedVitalsProvider(scenario: scenario),
            connectivity: MockConnectivityManager(),
            engine: RiskAssessmentEngine(configuration: .default),
            locationProvider: MockLocationProvider(),
            notifications: MockNotificationManager(),
            hospitalLocator: HospitalLocatorMock(simulatedLatency: .milliseconds(300)),
            dispatcher: EmergencyDispatchMock(simulatedLatency: .milliseconds(300)),
            countdown: AlertTimerManager()
        )
    }

    public func startMonitoring() {
        pipeline.start()
    }
}
