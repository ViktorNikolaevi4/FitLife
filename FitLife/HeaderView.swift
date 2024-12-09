

import SwiftUI
import SwiftData

struct HeaderView: View {
    @State private var selectedDate = Date() // Текущая дата по умолчанию
    @State private var isDatePickerVisible = false // Флаг для отображения календаря

    var body: some View {
        ZStack {
            // Основной интерфейс
            VStack {
                HStack {
                    Text(selectedDate, style: .date) // Отображение выбранной даты
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center) // Выровнять по правому краю

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

            // Календарь
            if isDatePickerVisible {
                ZStack {
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
                        .datePickerStyle(.graphical)
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
                    .padding()
                }
                .transition(.opacity) // Анимация появления
                .animation(.easeInOut, value: isDatePickerVisible) // Анимация
            }
        }
    }
}

#Preview {
    HeaderView()
}
