import SwiftUI
import Observation

struct HeaderView: View {
    @Binding var selectedDate: Date
    @State private var isDatePickerVisible = false
    @State private var tempDate: Date = Date()
    @Environment(\.colorScheme) private var colorScheme // Определение текущей темы

    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                tempDate = selectedDate // Сохраняем временно
                isDatePickerVisible = true
            }) {
                HStack(spacing: 8) {
                    Text(formattedDate(selectedDate))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .background(
                    Color.white.opacity(colorScheme == .dark ? 0.25 : 0.15)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(colorScheme == .dark ? 0.4 : 0.2), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            Spacer()
        }
        .padding(.top, 10)
        .sheet(isPresented: $isDatePickerVisible) {
            VStack(spacing: 0) {
                DatePicker(
                    "Выберите дату",
                    selection: $tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .padding(.top, 20)

                Button("OK") {
                    selectedDate = tempDate
                    isDatePickerVisible = false
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(colorScheme == .dark ? 0.9 : 1.0))
                .foregroundColor(.black)
                .cornerRadius(12)
                .padding([.leading, .trailing, .bottom])
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter.string(from: date)
    }
}
