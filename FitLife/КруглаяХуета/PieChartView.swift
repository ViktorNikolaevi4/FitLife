
import SwiftUI
import Charts

struct PieChartView: View {
    @Bindable var userData: UserData

    var body: some View {
        if dataIsEmpty {
            VStack {
                Text("Данные ещё не введены")
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chart.pie")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)
            }
            .frame(height: 125)
        } else {
            Chart(data, id: \.category) { item in
                SectorMark(
                    angle: .value("Value", item.value),
                    innerRadius: .ratio(0.5),
                    outerRadius: .ratio(1.0)
                )
                .foregroundStyle(by: .value("Category", item.category))
            }
            .frame(height: 125)
        }
    }

    // Проверка на пустые значения
    private var dataIsEmpty: Bool {
        let macros = userData.macros
        return macros.proteins == 0 && macros.fats == 0 && macros.carbs == 0
    }

    // Генерация данных для диаграммы
    private var data: [(category: String, value: Double)] {
        let macros = userData.macros
        return [
            ("Белки", Double(macros.proteins)),
            ("Жиры", Double(macros.fats)),
            ("Углеводы", Double(macros.carbs))
        ]
    }
}
