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
                        .foregroundStyle(.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .background(
                    Color(.secondarySystemBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(colorScheme == .dark ? 0.35 : 0.18), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            Spacer()
        }
        .padding(.top, 10)
        .sheet(isPresented: $isDatePickerVisible) {
            VStack(spacing: 0) {
                DatePicker(
                    AppLocalizer.string("common.select_date"),
                    selection: $tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, AppLocalizer.currentLanguage.locale)
                .tint(.blue)
                .padding(.top, 20)

                Button(AppLocalizer.string("common.ok")) {
                    selectedDate = tempDate
                    isDatePickerVisible = false
                }
             //   .frame(maxWidth: .infinity, minHeight: 44)
               
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(colorScheme == .dark ? 0.9 : 1.0))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalizer.currentLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter.string(from: date)
    }
}
