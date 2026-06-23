# CardioGuard ❤️‍🩹

> Continuous cardiac-safety monitoring for iPhone + Apple Watch.
> A portfolio / interview demonstration of production-grade iOS architecture.

CardioGuard streams live **heart rate** and **blood-oxygen (SpO₂)** from an Apple
Watch to an iPhone, runs the data through a configurable **risk-scoring engine**,
and — when the risk crosses a critical threshold — escalates through a full
**emergency protocol**: a 20-second alert, GPS capture, nearest-hospital lookup,
and a simulated dispatch with a complete incident report.

> ⚠️ **Disclaimer:** This is a demonstration project. It does **not** provide
> medical advice and must never replace professional emergency services. The
> hospital-locator and dispatch layers are deliberately mocked behind protocols.

---

## ✨ Highlights

- **Swift 6 / strict concurrency** — value types are `Sendable`; framework
  reference types are isolated behind protocol seams.
- **Clean MVVM + protocol-oriented DI** — every service is an interface; the
  whole app runs against mocks for previews, tests, and on-device demos.
- **Pure, explainable risk engine** — deterministic scoring with a human-readable
  reason attached to every point.
- **End-to-end emergency state machine** — alert → countdown → location → hospital
  → dispatch, fully unit-tested with fakes (no real timers, GPS, or network).
- **Shared code across iOS + watchOS** — one wire format, zero drift.

---

## 🏗 Architecture

```
            ┌──────────────┐  WatchConnectivity   ┌─────────────────┐
            │ Apple Watch  │ ───────────────────► │     iPhone      │
            │ (sensor tier)│   VitalSigns (JSON)   │ (analysis tier) │
            └──────┬───────┘                       └────────┬────────┘
                   │ HealthKit                              │
                   ▼                                        ▼
            HeartRate / SpO₂                        MonitoringPipeline
                                                            │
                                                  RiskAssessmentEngine (pure)
                                                            │  critical?
                                                            ▼
                                                  EmergencyCoordinator
                                          (countdown → location → hospital → dispatch)
```

The Watch is the **sensor tier** (read + relay); the iPhone is the **analysis
tier** (score + escalate). Keeping analysis on the phone conserves Watch battery
and centralizes the life-safety logic.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design rationale,
interview-ready explanations, and scalability notes.

### Layers

| Layer | Responsibility | Key types |
|-------|----------------|-----------|
| `Models/` | Immutable `Sendable` value types | `VitalSigns`, `RiskAssessment`, `EmergencyEvent` |
| `Core/` | Protocols, configuration, errors | `HealthMonitoring`, `RiskConfiguration` |
| `Services/` `HealthKit/` `WatchConnectivity/` | Framework adapters behind protocols | `HealthKitManager`, `WatchConnectivityManager` |
| `Emergency/` | The emergency state machine + mocks | `EmergencyCoordinator`, `HospitalLocatorMock` |
| `App/` | Composition root + reactive pipeline | `DependencyContainer`, `MonitoringPipeline` |
| `ViewModels/` | Presentation logic | `DashboardViewModel`, `RiskMonitoringViewModel` |
| `Views/` | SwiftUI screens | `DashboardView`, `EmergencyAlertView` |
| `MockData/` | Fakes + scripted scenarios | `SimulatedVitalsProvider`, `Mocks` |
| `Tests/` | Swift Testing suites | `RiskAssessmentEngineTests`, … |

---

## 🩺 Risk Scoring

Scoring policy lives entirely in `RiskConfiguration` (Open/Closed principle):

| Signal | Default points |
|--------|---------------:|
| Heart rate ≥ 140 bpm | +40 |
| Heart rate ≤ 40 bpm | +40 |
| SpO₂ < 90% (critical) | +50 |
| SpO₂ < 94% (low) | +20 |
| Rapid HR change (≥ 30 bpm) | +25 |
| Compound cardiac **and** respiratory abnormality | +20 bonus |

**Score ≥ 80 → Critical → Emergency Alert.** Every point carries a `RiskFactor`
with a plain-language explanation, so the UI and the incident report always show
*why* an alert fired.

---

## 🧪 Running

Open `CardioGuard.xcodeproj` in Xcode 16+ and run the `CardioGuard` scheme
(iOS 17+) or the `CardioGuardWatch` scheme (watchOS 10+).

No paired Watch? Flip the composition root to the self-driving demo:

```swift
// CardioGuardApp.swift
@StateObject private var container = DependencyContainer.simulated(scenario: .escalating)
```

This streams a scripted "escalating emergency" scenario through the full
pipeline — engine, alert, countdown, and dispatch — entirely on the Simulator.

### Tests

```bash
xcodebuild test -scheme CardioGuard -destination 'platform=iOS Simulator,name=iPhone 16'
```

The suites cover the risk engine (boundaries, compound logic, determinism), the
emergency coordinator (happy path + resilience), the reactive pipeline, and the
Watch↔phone Codable wire format.

---

## 🚀 Future Scalability

- Persist incident history (SwiftData / Core Data) and sync via CloudKit.
- Replace `HospitalLocatorMock` / `EmergencyDispatchMock` with live integrations
  — **no coordinator changes required** thanks to the protocol seams.
- On-device ML (Core ML) for personalized baselines and arrhythmia detection.
- Remote-config the `RiskConfiguration` for A/B-tested sensitivity.
- Background delivery via `HKObserverQuery` + background tasks for always-on
  monitoring.

---

## 📄 License

MIT — see [`LICENSE`](LICENSE).
