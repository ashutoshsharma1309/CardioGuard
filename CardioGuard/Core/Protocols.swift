//
//  Protocols.swift
//  CardioGuard
//
//  Protocol-oriented seams for every service. These abstractions are the
//  backbone of the app's testability and dependency injection: ViewModels and
//  coordinators depend on these protocols, never on concrete framework classes.
//

import Foundation
import Combine

// MARK: - Health Monitoring

/// Abstracts HealthKit so the rest of the app never imports HealthKit directly.
/// A `MockHealthKitManager` conforms to the same protocol for previews/tests.
public protocol HealthMonitoring: AnyObject, Sendable {
    /// Continuous stream of consolidated vitals.
    var vitalsPublisher: AnyPublisher<VitalSigns, Never> { get }

    /// Requests the user's authorization to read the required sample types.
    func requestAuthorization() async throws

    /// Begins streaming live heart-rate and SpO2 samples.
    func startMonitoring() async throws

    /// Stops all active queries.
    func stopMonitoring()
}

// MARK: - Watch ↔ Phone Connectivity

/// Abstracts `WatchConnectivity`. The phone consumes `receivedVitalsPublisher`;
/// the Watch app uses `send(_:)`.
public protocol DeviceConnectivity: AnyObject, Sendable {
    var receivedVitalsPublisher: AnyPublisher<VitalSigns, Never> { get }
    var connectionStatePublisher: AnyPublisher<ConnectivityState, Never> { get }

    func activate()
    func send(vitals: VitalSigns)
}

/// Reachability/activation state of the paired device.
public enum ConnectivityState: String, Sendable, Hashable {
    case notActivated
    case inactive
    case activated
    case reachable
    case unreachable

    public var isConnected: Bool { self == .reachable || self == .activated }
}

// MARK: - Risk Assessment

/// The pure, deterministic scoring engine. Has no side effects — given the same
/// vitals and configuration it always returns the same assessment, which makes
/// it trivially unit-testable.
public protocol RiskAssessing: Sendable {
    var configuration: RiskConfiguration { get }
    func assess(_ vitals: VitalSigns, referenceDate: Date) -> RiskAssessment
}

public extension RiskAssessing {
    /// Convenience overload defaulting the reference date to now.
    func assess(_ vitals: VitalSigns) -> RiskAssessment {
        assess(vitals, referenceDate: Date())
    }
}

// MARK: - Location

public protocol LocationProviding: AnyObject, Sendable {
    func requestAuthorization()
    /// One-shot async location fix used by the emergency protocol.
    func currentLocation() async throws -> LocationData
}

// MARK: - Notifications

public protocol NotificationScheduling: AnyObject, Sendable {
    func requestAuthorization() async throws
    func presentCriticalAlert(title: String, body: String) async
    func presentEmergencyDispatched(_ event: EmergencyEvent) async
}

// MARK: - Emergency sub-services (mocked, but protocol-first)

public protocol HospitalLocating: Sendable {
    /// Finds the nearest emergency-capable facility to a location.
    func nearestHospital(to location: LocationData) async throws -> Hospital
}

public protocol EmergencyDispatching: Sendable {
    /// Simulates contacting emergency services and returns a confirmation.
    func dispatch(for event: EmergencyEvent) async throws -> DispatchConfirmation
}

// MARK: - Countdown timer

/// Drives the 20-second "are you OK?" countdown. Abstracted so tests can run it
/// on a controllable clock instead of waiting in real time.
public protocol CountdownTiming: AnyObject, Sendable {
    var remainingPublisher: AnyPublisher<TimeInterval, Never> { get }
    func start(duration: TimeInterval, onExpire: @escaping @Sendable () -> Void)
    func cancel()
}
