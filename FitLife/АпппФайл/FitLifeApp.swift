//
//  FitLifeApp.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import SwiftData

@main
struct FitLifeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserData.self, FoodEntry.self, Product.self]) // Используем модификатор
    }
}

