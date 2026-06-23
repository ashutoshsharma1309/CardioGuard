//
//  Mocks.swift
//  CardioGuard
//
//  Lightweight protocol conformances for previews and unit tests.
//

import Foundation
import Combine

// MARK: - Connectivity

/// In-memory connectivity that can be told to "receive" vitals and flip state.
public final class MockConnectivityManager: DeviceConnectivity, @unchecked Sendable {
    private let vitalsSubject = PassthroughSubject<VitalSigns, Never>()
    private let stateSubject = CurrentValueSubject<ConnectivityState, Never>(.reachable)

    public var receivedVitalsPublisher: AnyPublisher<VitalSigns, Never> { vitalsSubject.eraseToAnyPublisher() }
    public var connectionStatePublisher: AnyPublisher<ConnectivityState, Never> { stateSubject.eraseToAnyPublisher() }

    public private(set) var sentVitals: [VitalSigns] = []

    public init() {}

    public func activate() { stateSubject.send(.activated) }
    public func send(vitals: VitalSigns) { sentVitals.append(vitals) }

    /// Test hook: simulate the Watch pushing a snapshot to the phone.
    public func simulateReceive(_ vitals: VitalSigns) { vitalsSubject.send(vitals) }
    public func simulateState(_ state: ConnectivityState) { stateSubject.send(state) }
}

// MARK: - Location

public final class MockLocationProvider: LocationProviding, @unchecked Sendable {
    public var stubbedLocation: LocationData
    public var error: CardioGuardError?

    public init(stubbedLocation: LocationData = .sample, error: CardioGuardError? = nil) {
        self.stubbedLocation = stubbedLocation
        self.error = error
    }

    public func requestAuthorization() {}
    public func currentLocation() async throws -> LocationData {
        if let error { throw error }
        return stubbedLocation
    }
}

// MARK: - Notifications

public final class MockNotificationManager: NotificationScheduling, @unchecked Sendable {
    public private(set) var criticalAlerts: [(title: String, body: String)] = []
    public private(set) var dispatchedEvents: [EmergencyEvent] = []

    public init() {}

    public func requestAuthorization() async throws {}
    public func presentCriticalAlert(title: String, body: String) async {
        criticalAlerts.append((title, body))
    }
    public func presentEmergencyDispatched(_ event: EmergencyEvent) async {
        dispatchedEvents.append(event)
    }
}

// MARK: - Countdown

/// A countdown with no real timer; the test/caller fires expiry manually.
public final class ImmediateCountdown: CountdownTiming, @unchecked Sendable {
    private let subject = CurrentValueSubject<TimeInterval, Never>(0)
    public var remainingPublisher: AnyPublisher<TimeInterval, Never> { subject.eraseToAnyPublisher() }

    private var onExpire: (@Sendable () -> Void)?
    public private(set) var startCount = 0
    public private(set) var cancelCount = 0

    public init() {}

    public func start(duration: TimeInterval, onExpire: @escaping @Sendable () -> Void) {
        startCount += 1
        self.onExpire = onExpire
        subject.send(duration)
    }

    public func cancel() {
        cancelCount += 1
        onExpire = nil
    }

    /// Test hook: fire the expiry callback synchronously.
    public func fireExpiry() {
        let callback = onExpire
        onExpire = nil
        subject.send(0)
        callback?()
    }
}
