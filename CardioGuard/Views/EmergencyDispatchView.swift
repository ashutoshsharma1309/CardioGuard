//
//  EmergencyDispatchView.swift
//  CardioGuard
//
//  Shows the emergency protocol progressing and the final dispatch report.
//

import SwiftUI
import MapKit

/// Visualizes the emergency protocol as it executes and renders the final
/// report: coordinates, estimated hospital, timestamp, risk score, and the
/// dispatch reference. Observes the coordinator's `activeEvent`, which the
/// protocol mutates stage-by-stage.
public struct EmergencyDispatchView: View {
    @EnvironmentObject private var container: DependencyContainer

    public init() {}

    private var coordinator: EmergencyCoordinator { container.coordinator }

    public var body: some View {
        NavigationStack {
            ScrollView {
                if let event = coordinator.activeEvent {
                    VStack(spacing: 20) {
                        statusHeader(event)
                        if let location = event.location { mapCard(location) }
                        reportCard(event)
                        if event.status == .dispatched || event.status == .failed {
                            acknowledgeButton
                        }
                    }
                    .padding()
                } else {
                    ProgressView("Preparing report…")
                }
            }
            .navigationTitle("Emergency Dispatch")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func statusHeader(_ event: EmergencyEvent) -> some View {
        VStack(spacing: 12) {
            Image(systemName: iconName(for: event.status))
                .font(.system(size: 56))
                .foregroundStyle(event.status == .failed ? .orange : .red)
                .symbolEffect(.pulse, isActive: event.status != .dispatched && event.status != .failed)
            Text(statusText(for: event.status))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func mapCard(_ location: LocationData) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))) {
            Marker("You", coordinate: location.coordinate)
                .tint(.red)
            if let hospital = coordinator.activeEvent?.nearestHospital {
                Marker(hospital.name, coordinate: hospital.location.coordinate)
                    .tint(.blue)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func reportCard(_ event: EmergencyEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emergency Report").font(.headline)

            reportRow("Risk Score", "\(event.triggeringAssessment.score) (\(event.triggeringAssessment.level.displayName))")
            reportRow("Triggered", Formatters.timestamp.string(from: event.initiatedAt))

            if let location = event.location {
                reportRow("Coordinates", Formatters.coordinateString(location))
            } else {
                reportRow("Coordinates", "Unavailable")
            }

            if let hospital = event.nearestHospital {
                reportRow("Nearest Hospital", hospital.name)
                reportRow("Distance", Formatters.distanceString(meters: hospital.distanceMeters))
                reportRow("Est. Arrival", "\(hospital.estimatedTravelMinutes) min")
                reportRow("Contact", hospital.phoneNumber)
            }

            if let dispatch = event.dispatch {
                Divider()
                reportRow("Reference", dispatch.referenceCode)
                reportRow("Responding Unit", dispatch.respondingUnit)
                reportRow("ETA", Formatters.clock.string(from: dispatch.estimatedArrival))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var acknowledgeButton: some View {
        Button {
            coordinator.acknowledgeDispatch()
        } label: {
            Text("Acknowledge")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Status presentation

    private func iconName(for status: EmergencyEvent.Status) -> String {
        switch status {
        case .initiated, .locating:    return "location.magnifyingglass"
        case .locatingHospital:        return "cross.case.fill"
        case .dispatching:             return "antenna.radiowaves.left.and.right"
        case .dispatched:              return "checkmark.seal.fill"
        case .failed:                  return "exclamationmark.triangle.fill"
        case .resolvedByUser:          return "checkmark.circle.fill"
        }
    }

    private func statusText(for status: EmergencyEvent.Status) -> String {
        switch status {
        case .initiated, .locating:    return "Acquiring your location…"
        case .locatingHospital:        return "Locating nearest hospital…"
        case .dispatching:             return "Contacting emergency services…"
        case .dispatched:              return "Help is on the way"
        case .failed:                  return "Dispatch incomplete — call emergency services"
        case .resolvedByUser:          return "Resolved"
        }
    }
}

#Preview {
    let container = DependencyContainer.simulated()
    return EmergencyDispatchView().environmentObject(container)
}
