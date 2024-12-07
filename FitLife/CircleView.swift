//
//  CircleView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI

struct CircleView: View {
     var imageName: String

    var body: some View {
        Image(imageName) // Замените "exampleImage" на имя вашего изображения
            .resizable() // Делаем изображение изменяемого размера
            .scaledToFill() // Масштабируем изображение для полного заполнения круга
            .frame(width: 150, height: 150) // Устанавливаем размеры круга
            .clipShape(Circle()) // Обрезаем изображение по форме круга
            .overlay( // Добавляем очертание
                Circle()
                    .stroke(Color.white, lineWidth: 5) // Цвет и толщина рамки
            )
            .shadow(color: .gray, radius: 10, x: 5, y: 5) // Добавляем тень для объёма
    }
}
