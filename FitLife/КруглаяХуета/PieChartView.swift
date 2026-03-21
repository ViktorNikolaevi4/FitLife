
import SwiftUI
import Charts

struct PieChartView: View {
    @Bindable var userData: UserData

    var body: some View {
        if dataIsEmpty {
            VStack {
                Text(AppLocalizer.string("chart.no_data"))
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
                    outerRadius: .ratio(1.0),
                    angularInset: 1.5
                )
                .cornerRadius(8)
                .foregroundStyle(by: .value("Category", item.category)) // привязываем к масштабу
            }
            .chartForegroundStyleScale([
                AppLocalizer.string("macro.protein"): .blue,
                AppLocalizer.string("macro.fat"): .red,
                AppLocalizer.string("macro.carbs"): .green
            ])
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
            (AppLocalizer.string("macro.protein"), Double(macros.proteins)),
            (AppLocalizer.string("macro.fat"), Double(macros.fats)),
            (AppLocalizer.string("macro.carbs"), Double(macros.carbs))
        ]
    }
}
