
import SwiftUI

// Модель пользователя
struct User: Identifiable {
    var id = UUID()
    var weight: Double
    var height: Double
    var age: Int
}

struct UserStatsView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 80, height: 80)


                HStack(spacing: 20) {
                    VStack {
                        Text("ВЕС, КГ")
                        Text("0")
                    }
                    VStack {
                        Text("РОСТ, СМ")
                        Text("0")
                    }
                    VStack {
                        Text("ВОЗРАСТ")
                        Text("0")
                    }
                }
                .font(.headline)
            }
            .padding()

            ActivitySelectorView()
        }
    }
}

struct ActivitySelectorView: View {
    @State private var selectedActivity = 0
    let activityLevels = ["Нет", "1-2 раза", "3-5 раза", "PRO"]

    var body: some View {
        Picker("Физическая активность", selection: $selectedActivity) {
            ForEach(activityLevels.indices, id: \.self) { index in
                Text(activityLevels[index])
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
}


#Preview {
    UserStatsView()
}
