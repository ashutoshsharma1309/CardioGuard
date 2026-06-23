//
//  MetricCard.swift
//  CardioGuard
//
//  A reusable card showing a single metric with an SF Symbol and accent color.
//

import SwiftUI

/// A compact, reusable metric tile used across the dashboard and metrics screens.
/// Extracting it keeps screens declarative and guarantees visual consistency.
public struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let accent: Color

    public init(title: String, value: String, unit: String, systemImage: String, accent: Color) {
        self.title = title
        self.value = value
        self.unit = unit
        self.systemImage = systemImage
        self.accent = accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

/// A labeled status row with a colored indicator dot.
public struct StatusRow: View {
    let title: String
    let value: String
    let color: Color

    public init(title: String, value: String, color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }

    public var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    VStack(spacing: 16) {
        MetricCard(title: "Heart Rate", value: "72", unit: "bpm", systemImage: "heart.fill", accent: .green)
        StatusRow(title: "Watch", value: "Connected", color: .green)
    }
    .padding()
}
