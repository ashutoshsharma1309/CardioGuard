//
//  CardioGuardError.swift
//  CardioGuard
//
//  A unified, typed error domain for the whole app.
//

import Foundation

/// Typed errors surfaced by CardioGuard services.
///
/// A single error enum (rather than scattered `NSError`s) gives us exhaustive
/// `switch` handling at call sites and localizable, user-facing messages.
public enum CardioGuardError: LocalizedError, Equatable, Sendable {

    case healthDataUnavailable
    case healthAuthorizationDenied
    case healthQueryFailed(String)

    case locationUnavailable
    case locationAuthorizationDenied
    case locationTimedOut

    case notificationAuthorizationDenied

    case hospitalLookupFailed(String)
    case dispatchFailed(String)

    case watchUnreachable

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .healthAuthorizationDenied:
            return "CardioGuard needs permission to read your heart rate and blood oxygen."
        case .healthQueryFailed(let reason):
            return "Could not read health data: \(reason)"
        case .locationUnavailable:
            return "Your location could not be determined."
        case .locationAuthorizationDenied:
            return "Location access is required to dispatch emergency help."
        case .locationTimedOut:
            return "Timed out while acquiring your location."
        case .notificationAuthorizationDenied:
            return "Notification permission is required for critical alerts."
        case .hospitalLookupFailed(let reason):
            return "Could not locate a nearby hospital: \(reason)"
        case .dispatchFailed(let reason):
            return "Emergency dispatch failed: \(reason)"
        case .watchUnreachable:
            return "The Apple Watch is not currently reachable."
        }
    }
}
