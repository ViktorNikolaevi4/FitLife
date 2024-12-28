//
//  WaterIntake.swift
//  FitLife
//
//  Created by Виктор Корольков on 28.12.2024.
//

import SwiftData
import Foundation

@Model
class WaterIntake {
    @Attribute(.unique) var id: UUID = UUID() // Уникальный идентификатор
    var date: Date // Дата записи
    var intake: Double // Количество выпитой воды в литрах

    init(date: Date, intake: Double) {
        self.date = date
        self.intake = intake
    }
}
