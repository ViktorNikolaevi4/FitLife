
import SwiftUI
import Charts

struct PieChartView: View {
    let data: [(category: String, value: Double)] = [
        ("Белки", 20),
        ("Жиры", 30),
        ("Углеводы", 50)
    ]

    var body: some View {
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


#Preview {
    PieChartView()
}
