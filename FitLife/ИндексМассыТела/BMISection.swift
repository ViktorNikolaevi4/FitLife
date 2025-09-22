import SwiftUI
import Observation   // если ругается на @Bindable, добавьте этот импорт

// Секция "Индекс массы тела" для профиля
struct BMISection: View {
    @Bindable var userData: UserData
    @State private var showBMISheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Индекс массы тела")
                .font(.headline)

            Button { showBMISheet = true } label: {
                BMICardView(userData: userData)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showBMISheet) {
            BMIPopupView(userData: userData)    // ваш поп-ап (ниже — как его слегка причесать)
        }
    }
}

// Небольшая карточка со значением ИМТ
private struct BMICardView: View {
    @Bindable var userData: UserData

    var body: some View {
        let value = bmi(for: userData)
        let color = bmiColor(value)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ИМТ", systemImage: "figure.arms.open")
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text(value.isFinite ? String(format: "%.1f", value) : "—")
                    .font(.title2).bold()
                    .foregroundStyle(color)
            }

            Text(bmiMessage(value))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            BMIGauge(value: value, minValue: 12, maxValue: 40, tint: color)
                .frame(height: 10)
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

// Простейшая «линейка» с маркером
private struct BMIGauge: View {
    let value: Double
    let minValue: Double
    let maxValue: Double
    let tint: Color

    var fraction: CGFloat {
        guard value.isFinite else { return 0 }
        let clamped = Swift.min(Swift.max(value, minValue), maxValue)
        return CGFloat((clamped - minValue) / (maxValue - minValue))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color(UIColor.systemGray5))
                Capsule().fill(tint.opacity(0.25))
                    .frame(width: w * fraction)

                Circle().fill(tint)
                    .frame(width: 12, height: 12)
                    .offset(x: w * fraction - 6)
                    .shadow(radius: 1, y: 0.5)
            }
        }
        .frame(height: 10)
    }
}


// Подсчёт и тексты такие же, как у вашего поп-апа
private func bmi(for user: UserData) -> Double {
    guard user.height > 0, user.weight > 0 else { return .infinity }
    let h = user.height / 100
    return user.weight / (h * h)
}
private func bmiMessage(_ bmi: Double) -> String {
    switch bmi {
    case ..<18.5: return "Дефицит массы тела"
    case 18.5..<25: return "Нормальная масса"
    case 25..<30: return "Избыточный вес"
    case .infinity: return "Заполните вес и рост"
    default: return "Ожирение"
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
