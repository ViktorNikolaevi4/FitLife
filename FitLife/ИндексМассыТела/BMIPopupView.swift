import SwiftUI

struct BMIPopupView: View {
    @Bindable var userData: UserData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Заголовок теперь в navigation bar, поэтому здесь не дублируем

                    Text(AppLocalizer.string("bmi.your_index"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    let bmi = calculateBMI()

                    Text(String(format: "%.1f", bmi))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(colorForBMI(bmi))

                    Text(bmiMessage(for: bmi))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colorForBMI(bmi))

                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalizer.string("bmi.range.underweight"))
                        Text(AppLocalizer.string("bmi.range.normal"))
                        Text(AppLocalizer.string("bmi.range.overweight"))
                        Text(AppLocalizer.string("bmi.range.obesity"))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle(AppLocalizer.string("bmi.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])             // как и раньше
        .presentationDragIndicator(.visible)
    }

    // MARK: - Расчёты и оформление
    private func calculateBMI() -> Double {
        guard userData.weight > 0, userData.height > 0 else { return 0.0 }
        let h = userData.height / 100
        return userData.weight / (h * h)
    }

    private func bmiMessage(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return AppLocalizer.string("bmi.message.underweight")
        case 18.5..<25: return AppLocalizer.string("bmi.message.normal")
        case 25..<30: return AppLocalizer.string("bmi.message.overweight")
        default: return AppLocalizer.string("bmi.message.obesity")
        }
    }

    private func colorForBMI(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
}


