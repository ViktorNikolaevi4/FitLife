import SwiftUI
import Observation

struct HeaderView: View {
    @Binding var selectedDate: Date // Текущая дата по умолчанию
    @State private var isDatePickerVisible = false // Флаг для отображения календаря

    var body: some View {
        ZStack {
            // Основной интерфейс
            VStack(alignment: .center) {
                HStack {
                    Text(selectedDate, style: .date) // Отображение выбранной даты
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center) // Выровнять по центру

                    Spacer()

                    Button(action: {
                        isDatePickerVisible.toggle() // Показать/скрыть календарь
                    }) {
                        Image(systemName: "calendar")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .padding()

                Spacer() // Остальная часть интерфейса
            }
            .overlay(
                // Календарь как наложение
                isDatePickerVisible ? ZStack {
                    Color.black.opacity(0.4) // Полупрозрачный фон
                        .ignoresSafeArea()
                        .onTapGesture {
                            isDatePickerVisible = false // Закрыть календарь при нажатии на фон
                        }

                    VStack {
                        DatePicker(
                            "Выберите дату",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(radius: 8)
                        )
                        .padding()

                        Button("OK") {
                            isDatePickerVisible = false // Закрыть календарь
                        }
                        .font(.headline)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                        .foregroundColor(.white)
                    }
                    .frame(maxWidth: 300) // Фиксированная ширина для DatePicker
                    .padding()
                    .offset(y: 40)
                }
                .zIndex(1) // Устанавливаем zIndex, чтобы календарь был поверх
                .transition(.opacity) // Анимация появления
                .animation(.easeInOut, value: isDatePickerVisible) // Анимация
                : nil
            )
        }.zIndex(1)
            .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}
