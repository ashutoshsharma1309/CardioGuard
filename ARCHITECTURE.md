# CardioGuard — Architecture & Design Rationale

This document is the "interview-ready" companion to the codebase. It explains
*why* the app is structured the way it is, the trade-offs considered, and how
each decision maps to a software-engineering principle.

---

## 1. Layered, dependency-inverted design

The app is organized into layers where **dependencies point inward toward
abstractions**, never outward toward frameworks:

```
Views → ViewModels → Pipeline/Coordinator → Protocols ← Framework adapters
                                  ▲
                              Models (pure)
```

- **Models** are pure, immutable, `Sendable` value types with zero framework
  imports. They can cross any concurrency boundary safely.
- **Core/Protocols.swift** defines a seam for every capability:
  `HealthMonitoring`, `DeviceConnectivity`, `RiskAssessing`, `LocationProviding`,
  `NotificationScheduling`, `HospitalLocating`, `EmergencyDispatching`,
  `CountdownTiming`.
- **Adapters** (`HealthKitManager`, `WatchConnectivityManager`, …) are the *only*
  types that import HealthKit / WatchConnectivity / CoreLocation. Nothing else in
  the app knows those frameworks exist.

**Why:** The Dependency Inversion Principle. High-level policy (the risk engine,
the emergency flow) never depends on low-level framework details. We can run the
entire app — including the emergency escalation — on the Simulator with mocks.

---

## 2. The composition root

`DependencyContainer` is the single place the object graph is assembled. It
offers `.live()` (real framework services) and `.simulated()` (scripted demo).
Every other type uses **constructor injection** and depends only on protocols.

**Why:** No hidden singletons, no service locators. The wiring is explicit and
reviewable in one file, and tests build their own graph with fakes.

---

## 3. A pure, explainable risk engine

`RiskAssessmentEngine` is a `struct` with no mutable state, no I/O, and no
framework dependencies. Given the same `VitalSigns` + `RiskConfiguration` it
**always** returns the same `RiskAssessment`.

Three consequences:

1. **Testability** — no mocks, no async, no flakiness. Pure input → output.
2. **Thread-safety** — immutable + `Sendable`, callable from any actor.
3. **Explainability** — every point is attached to a `RiskFactor` with a
   human-readable reason. Opaque scores erode trust in a medical-adjacent product.

Scoring policy lives in `RiskConfiguration`, honoring the **Open/Closed
Principle**: we re-tune thresholds (or remote-config / A-B test them) without
editing the engine.

A subtle design point: the "compound abnormality" bonus counts **distinct
physiological systems** (cardiac vs. respiratory), not raw factor count — so two
cardiac factors don't falsely inflate into a compound emergency.

---

## 4. The emergency state machine

`EmergencyCoordinator` is a `@MainActor ObservableObject` that owns the lifecycle:

```
critical → .alert ──(20s, no response)──► .dispatch
   │                                          │
   └──(user taps "I'm Fine")──► reset    locate → hospital → dispatch → notify
```

- It is **idempotent**: duplicate critical triggers are ignored while active.
- Slow work (`location`, `hospital`, `dispatch`) is `await`ed off the actor inside
  injected services; state mutations stay serialized on the main actor for safe
  SwiftUI updates.
- It is **resilient**: a location failure degrades gracefully to a best-effort
  report rather than crashing the flow.

Because every dependency — including the **countdown timer** — is injected via
protocol, the whole 20-second flow is unit-tested in milliseconds using
`ImmediateCountdown.fireExpiry()` instead of waiting in real time.

---

## 5. Swift Concurrency posture

- Domain models are `Sendable` value types → safe to pass Watch → phone → engine.
- Framework adapters are `final class … @unchecked Sendable` with internal
  serialization (a dedicated `DispatchQueue` or `NSLock`), because the underlying
  Apple APIs are callback-based and not themselves `Sendable`. The unsafety is
  *contained* to one file each.
- CoreLocation's delegate callbacks are bridged to `async/await` via
  `CheckedContinuation`, so callers write `try await currentLocation()`.
- UI-driving orchestrators (`EmergencyCoordinator`, `MonitoringPipeline`,
  view models) are `@MainActor`.

---

## 6. Reactive data flow

`MonitoringPipeline` merges **both** vitals sources — direct HealthKit on the
phone and data relayed from the Watch — into one Combine stream, scores each
snapshot, and forwards critical assessments to the coordinator. View models read
the pipeline's published state rather than each re-subscribing to raw streams
(single source of truth, DRY).

---

## 7. Shared code across targets

`HealthKitManager` and `WatchConnectivityManager` compile for **both** iOS and
watchOS. The Watch reuses them to read and relay; the phone reuses them to
receive. One `Codable` wire format (`VitalSigns`) means no serialization drift
between devices.

---

## 8. Testing strategy

| Suite | What it proves |
|-------|----------------|
| `RiskAssessmentEngineTests` | Boundary thresholds, compound logic, staleness, determinism, config overrides |
| `EmergencyCoordinatorTests` | Alert presentation, user cancellation, idempotency, full protocol on expiry, location-failure resilience |
| `MonitoringPipelineTests` | Watch vitals are scored; critical input escalates |
| `ModelTests` | Codable round-trip (wire format), classification buckets, geo math |

The highest-value tests target the **pure engine** and the **state machine** —
the two places where a bug would have real-world consequences.

---

## 9. Trade-offs & what I'd add next

- **No persistence yet.** Intentional for a focused demo. Production would add
  SwiftData for incident history + CloudKit sync.
- **Mocked emergency tier.** The protocol seams (`HospitalLocating`,
  `EmergencyDispatching`) mean swapping in live integrations requires zero changes
  to the coordinator — the entire point of the abstraction.
- **Single configuration source.** Ready to be remote-config-driven for A/B-tested
  sensitivity without a code change.
- **Background monitoring.** Would add `HKObserverQuery` + background delivery so
  detection continues when the app is suspended.
