
import SwiftUI

struct RoundedTextView: View {
    var text: String // Текст, который будет передаваться в View

    var body: some View {
        ZStack {
            // Закругленный прямоугольник
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#FFFF9E")) // Используем расширение для HEX-цветов
                .frame(width: 200, height: 100) // Размер прямоугольника
                .overlay( // Добавляем обводку
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 2) // Черная обводка
                )
                .shadow(radius: 8) // Добавляем тень

            // Текст поверх прямоугольника
            Text(text)
                .font(.title2) // Устанавливаем стиль шрифта
                .foregroundColor(.black) // Цвет текста
        }
    }
}

#Preview {
    RoundedTextView(text: "1300 Ккалорий")
}

// Расширение для работы с HEX-цветами
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        scanner.currentIndex = hex.hasPrefix("#") ? hex.index(after: hex.startIndex) : hex.startIndex

        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
