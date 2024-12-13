//
//  BMIPopupView.swift
//  FitLife
//
//  Created by Виктор Корольков on 12.12.2024.
//

import SwiftUI

struct BMIPopupView: View {

    @Bindable var userData: UserData // Bindable данные пользователя
    @Environment(\.dismiss) private var dismiss // Для закрытия окна

    var body: some View {
        VStack(spacing: 16) {
            Text("Индекс массы тела")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ваш индекс")
                .font(.headline)
                .foregroundColor(.gray)

            let bmi = calculateBMI()

            Text(String(format: "%.1f", bmi))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(colorForBMI(bmi))

            Text(bmiMessage(for: bmi))
                .font(.body)
                .foregroundColor(colorForBMI(bmi))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("<18.5 — Дефицит массы тела")
                Text("18.5 - 24.9 — Нормальная масса тела")
                Text("25 - 29.9 — Избыточная масса тела")
                Text(">30 — Ожирение")
            }
            .font(.footnote)
            .foregroundColor(.gray)

            Spacer()

            Button("OK") {
                dismiss() // Закрыть окно
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .presentationDetents([.medium])
    }

    // Функция для расчёта ИМТ
    private func calculateBMI() -> Double {
        guard userData.weight > 0, userData.height > 0 else { return 0.0 }
        let heightInMeters = userData.height / 100
        return userData.weight / (heightInMeters * heightInMeters)
    }

    // Сообщение в зависимости от ИМТ
    private func bmiMessage(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "У вас дефицит массы тела"
        case 18.5..<25: return "Нормальная масса тела"
        case 25..<30: return "У вас избыточный вес"
        default: return "Ожирение"
        }
    }

    // Цвет в зависимости от ИМТ
    private func colorForBMI(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
}


