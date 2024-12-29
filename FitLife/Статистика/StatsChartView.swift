
import SwiftUI
import Charts

struct StatsChartView: View {
    let data: [ChartData]
 //   let title: String
    let unit: Calendar.Component
    let chartHeight: CGFloat

    var body: some View {
        VStack {
            Chart(data) { item in
                LineMark(
                    x: .value("Date", item.date, unit: unit),
                    y: .value("Value", item.value)
                )
                .symbol(Circle())
                .foregroundStyle(item.color)
            }
            .frame(height: chartHeight)
            .padding(.horizontal)

//            // Подпись к графику
//            Text(title)
//                .font(.caption)
//                .foregroundStyle(.white)
        }
    }
}
// Получение данных для графика
func getData(for timeFrame: TimeFrame) -> [ChartData] {
    let calendar = Calendar.current
    let today = Date()
    var data: [ChartData] = []

    switch timeFrame {
    case .week:
        if let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) {
            for dayOffset in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                    data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                }
            }
        }
    case .month:
        if let range = calendar.range(of: .day, in: .month, for: today) {
            for day in range {
                if let date = calendar.date(bySetting: .day, value: day, of: today) {
                    data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                }
            }
        }
    case .halfYear:
        for monthOffset in -5...0 {
            if let date = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
            }
        }
    case .year:
        for monthOffset in -11...0 {
            if let date = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
            }
        }
    }
    return data
}
