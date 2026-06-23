//
//  AppLogger.swift
//  CardioGuard
//
//  Thin, categorized wrapper over os.Logger for structured, privacy-aware logs.
//

import Foundation
import os

/// Centralized logging facade.
///
/// Using `os.Logger` (rather than `print`) gives us categories, log levels, and
/// privacy redaction for free, and integrates with Instruments / Console.app.
/// Health data is `.private` by default to avoid leaking PII into device logs.
public enum AppLogger {

    private static let subsystem = "com.cardioguard.app"

    public static let health      = Logger(subsystem: subsystem, category: "HealthKit")
    public static let connectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
    public static let risk        = Logger(subsystem: subsystem, category: "RiskEngine")
    public static let emergency   = Logger(subsystem: subsystem, category: "Emergency")
    public static let location    = Logger(subsystem: subsystem, category: "Location")
    public static let ui          = Logger(subsystem: subsystem, category: "UI")
}
