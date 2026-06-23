//
//  VitalSource.swift
//  CardioGuard
//
//  Provenance of a vital-sign sample.
//

import Foundation

/// Describes where a vital-sign sample originated.
///
/// Tracking provenance lets us (a) inject deterministic data in tests via
/// `.simulated`, and (b) reason about trust / freshness at runtime.
public enum VitalSource: String, Codable, Hashable, Sendable {
    case appleWatch
    case iPhone
    case simulated
    case healthKitQuery
}
