
import SwiftUI
import Charts

struct PieChartView: View {
    var proteins: Int
    var fats: Int
    var carbs: Int

    var body: some View {
        let total = Double(proteins + fats + carbs)
        let data: [(category: String, value: Double)] = [
            ("Белки", Double(proteins) / total * 100),
            ("Жиры", Double(fats) / total * 100),
            ("Углеводы", Double(carbs) / total * 100)
        ]

        return Chart(data, id: \.category) { item in
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

#Preview {
    PieChartView(proteins: 30, fats: 20, carbs: 50)
}
