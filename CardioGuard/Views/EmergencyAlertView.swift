//
//  EmergencyAlertView.swift
//  CardioGuard
//
//  The full-screen, high-urgency alert with a 20-second countdown.
//

import SwiftUI

/// A deliberately alarming full-screen alert.
///
/// Reads the shared `EmergencyCoordinator` from the environment. While visible
/// it pulses red, plays a repeating alarm haptic, and counts down. Two large,
/// unmistakable buttons let the user cancel; silence escalates.
public struct EmergencyAlertView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var pulse = false
    @State private var hapticTimer: Timer?

    public init() {}

    private var coordinator: EmergencyCoordinator { container.coordinator }

    public var body: some View {
        ZStack {
            Color.red
                .opacity(pulse ? 0.95 : 0.7)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                VStack(spacing: 8) {
                    Text("CARDIAC EMERGENCY")
                        .font(.largeTitle.bold())
                    Text("Abnormal vitals detected")
                        .font(.title3)
                    if let event = coordinator.activeEvent {
                        Text(event.triggeringAssessment.summary)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .foregroundStyle(.white)

                countdownRing

                Spacer()

                actionButtons
            }
            .padding()
        }
        .onAppear(perform: startEffects)
        .onDisappear(perform: stopEffects)
    }

    private var countdownRing: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.3), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0, coordinator.countdownRemaining / 20))
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: coordinator.countdownRemaining)
            Text("\(Int(coordinator.countdownRemaining.rounded()))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(width: 160, height: 160)
        .accessibilityLabel("\(Int(coordinator.countdownRemaining.rounded())) seconds until emergency dispatch")
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button {
                coordinator.userMarkedSafe()
            } label: {
                Text("I'M FINE")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.red)
            }

            Button {
                coordinator.userMarkedSafe()
            } label: {
                Text("Dismiss Alert")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 2))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Alarm effects

    private func startEffects() {
        pulse = true
        // Repeating haptic to demand attention even if the phone is in a pocket.
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            #if canImport(UIKit) && !os(watchOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
        }
    }

    private func stopEffects() {
        pulse = false
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
}

#Preview {
    let container = DependencyContainer.simulated()
    container.coordinator.handleCriticalAssessment(PreviewData.criticalAssessment)
    return EmergencyAlertView().environmentObject(container)
}
