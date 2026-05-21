import SwiftUI
import Observation

struct BMISection: View {
    @Bindable var userData: UserData
    @State private var showBMISheet = false

    var body: some View {
        Button { showBMISheet = true } label: {
            BMICardView(userData: userData)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .sheet(isPresented: $showBMISheet) {
            BMIPopupView(userData: userData)
        }
    }
}

private struct BMICardView: View {
    @Bindable var userData: UserData
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        let value = bmi(for: userData)
        let color = bmiColor(value)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalizer.string("bmi.title"))
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    Text(AppLocalizer.string("bmi.caption"))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(value.isFinite ? String(format: "%.1f", value) : "—")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(color)

                    Text(AppLocalizer.string("bmi.short"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(bmiMessage(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)

                Spacer()

                Text(bmiRangeText(value))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            VStack(spacing: 8) {
                BMIGauge(value: value, minValue: 12, maxValue: 40, tint: color)
                    .frame(height: 12)

                HStack {
                    Text("18.5")
                    Spacer()
                    Text("24.9")
                    Spacer()
                    Text("30")
                }
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
    }
}

private struct BMIGauge: View {
    let value: Double
    let minValue: Double
    let maxValue: Double
    let tint: Color

    var fraction: CGFloat {
        let range = (maxValue - minValue).safeFinite
        guard range > 0 else { return 0 }
        let clamped = value.clamped(to: minValue...maxValue)
        return CGFloat((clamped - minValue) / range).clamped(to: 0...1)
    }

    var body: some View {
        GeometryReader { geo in
            let w = safeDimension(geo.size.width, minimum: 1)
            let markerX = (w * fraction).clamped(to: 8...(Swift.max(w - 8, 8))) - 8

            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Capsule().fill(Color.blue.opacity(0.18))
                    Capsule().fill(Color.green.opacity(0.18))
                    Capsule().fill(Color.orange.opacity(0.18))
                    Capsule().fill(Color.red.opacity(0.18))
                }

                Circle()
                    .fill(tint)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 3)
                    )
                    .offset(x: markerX)
                    .shadow(radius: 1, y: 0.5)
            }
        }
        .frame(height: 12)
    }
}

private func bmi(for user: UserData) -> Double {
    let height = user.height.safeFinite
    let weight = user.weight.safeFinite
    guard height > 0, weight > 0 else { return .infinity }
    let h = height / 100
    return (weight / (h * h)).safeFinite
}

private func bmiMessage(_ bmi: Double) -> String {
    switch bmi {
    case ..<18.5: return AppLocalizer.string("bmi.status.underweight")
    case 18.5..<25: return AppLocalizer.string("bmi.status.normal")
    case 25..<30: return AppLocalizer.string("bmi.status.overweight")
    case .infinity: return AppLocalizer.string("bmi.status.fill_data")
    default: return AppLocalizer.string("bmi.status.obesity")
    }
}

private func bmiColor(_ bmi: Double) -> Color {
    switch bmi {
    case ..<18.5: return .blue
    case 18.5..<25: return .green
    case 25..<30: return .orange
    default: return .red
    }
}

private func bmiRangeText(_ bmi: Double) -> String {
    switch bmi {
    case ..<18.5: return AppLocalizer.string("bmi.range.short.underweight")
    case 18.5..<25: return AppLocalizer.string("bmi.range.short.normal")
    case 25..<30: return AppLocalizer.string("bmi.range.short.overweight")
    case .infinity: return AppLocalizer.string("bmi.range.short.empty")
    default: return AppLocalizer.string("bmi.range.short.obesity")
    }
}
