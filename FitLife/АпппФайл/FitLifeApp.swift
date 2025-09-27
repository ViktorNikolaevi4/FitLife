import SwiftUI
import SwiftData

@main
struct FitLifeApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            UserData.self,
            FoodEntry.self,
            Product.self,
            CustomProduct.self,
            WaterIntake.self
        ])

        #if DEBUG
        let inMemory = false   // можно временно поставить true, чтобы не накапливать «битые» стора во время разработки
        #else
        let inMemory = false
        #endif

        do {
            // Основной вариант — с CloudKit
            let ck = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: inMemory ? .none : .automatic
            )
            return try ModelContainer(for: schema, configurations: ck)
        } catch {
            print("⚠️ CloudKit ModelContainer failed:", error)

            // Фолбэк — локальный store без CloudKit (чтобы приложение жило)
            let local = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            return try! ModelContainer(for: schema, configurations: local)
        }
    }()

    var body: some Scene {
        WindowGroup {  RootView() }
            .modelContainer(modelContainer)
    }
}
