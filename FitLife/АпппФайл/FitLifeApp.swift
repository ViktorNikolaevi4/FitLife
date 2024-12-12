//
//  FitLifeApp.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import OpenFoodFactsSDK

@main
struct FitLifeApp: App {
    init() {
        // Конфигурация OpenFoodFactsSDK
        OFFConfig.shared.apiEnv = .production // Production окружение
        OFFConfig.shared.productsLanguage = .RUSSIAN // Язык продуктов
        OFFConfig.shared.userAgent = UserAgent(name: "YourAppName", version: "1.0", system: "iOS", comment: "YourAppComment")

        // Установите глобального пользователя, если необходима авторизация
  //      OFFConfig.shared.globalUser = User(userId: "yourUsername", password: "yourPassword")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
