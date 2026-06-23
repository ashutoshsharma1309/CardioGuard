//
//  LocationManager.swift
//  CardioGuard
//
//  CoreLocation wrapper exposing a one-shot async location fix.
//

import Foundation
import CoreLocation

/// Provides the user's location for the emergency protocol.
///
/// CoreLocation is delegate-based; here we bridge it to async/await with a
/// `CheckedContinuation`, so the emergency coordinator can simply
/// `try await locationProvider.currentLocation()`.
public final class LocationManager: NSObject, LocationProviding, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let lock = NSLock()

    /// Continuations awaiting the next fix. Guarded by `lock`.
    private var pendingContinuations: [CheckedContinuation<LocationData, Error>] = []

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Requests a single fresh location fix.
    ///
    /// - Throws: `CardioGuardError.locationAuthorizationDenied` if access is
    ///   denied, or `.locationUnavailable` on underlying failure.
    public func currentLocation() async throws -> LocationData {
        let status = manager.authorizationStatus
        guard status != .denied, status != .restricted else {
            throw CardioGuardError.locationAuthorizationDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingContinuations.append(continuation)
            lock.unlock()
            manager.requestLocation()
        }
    }

    private func resume(with result: Result<LocationData, Error>) {
        lock.lock()
        let waiting = pendingContinuations
        pendingContinuations.removeAll()
        lock.unlock()
        for continuation in waiting {
            continuation.resume(with: result)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            resume(with: .failure(CardioGuardError.locationUnavailable))
            return
        }
        AppLogger.location.info("Acquired location fix")
        resume(with: .success(LocationData(location)))
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.location.error("Location failed: \(error.localizedDescription, privacy: .public)")
        resume(with: .failure(CardioGuardError.locationUnavailable))
    }
}
