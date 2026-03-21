
import SwiftUI

struct BottomNavigationView: View {
    @Binding var selectedDate: Date
    var userData: UserData

    @Binding var dailyConsumedCalories: Int
    let loadDailyConsumedCalories: (Date, Gender) -> Void

    @State private var showWaterTracker = false
    @State private var showBMIPopup = false
    @State private var rationPopupView = false

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        rationPopupView = true
                    }) {
                        VStack {
                            Image(systemName: "fork.knife")
                            Text("Рацион")
                        }.foregroundStyle(.white)
                    }
                    .sheet(isPresented: $rationPopupView) {
                        RationPopupView(
                            gender: userData.gender,
                            selectedDate: $selectedDate
                        ) {
                            // onMealAdded колбэк!
                            // Когда юзер добавил продукт в RationPopupView,
                            // сразу обновляем калории
                            loadDailyConsumedCalories(selectedDate, userData.gender)
                        }
                        .presentationDetents([.fraction(0.66), .large])
                        .presentationDragIndicator(.visible)
                    }
                    Spacer()
                    Button(action: {
                        showWaterTracker = true
                    }) {
                        VStack {
                            Image(systemName: "drop")
                            Text("Вода")
                        }.foregroundStyle(.white)
                    }
                    .sheet(isPresented: $showWaterTracker) {
                        WaterTrackerView(userData: userData)
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    Spacer()
                    Button(action: {
                        showBMIPopup = true
                    }) {
                        VStack {
                            Image(systemName: "scalemass")
                            Text("ИМТ")
                        }
                        .foregroundStyle(.white)
                    }
                    .sheet(isPresented: $showBMIPopup) {
                        BMIPopupView(userData: userData)
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    Spacer()
                    NavigationLink(destination: MenuView()) { // Переход на новое представление
                                       VStack {
                                           Image(systemName: "book")
                                           Text("Меню")
                                       }.foregroundStyle(.white)
                                   }
                    Spacer()
                }
                .padding()
                .cornerRadius(20)
                .shadow(radius: 5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
