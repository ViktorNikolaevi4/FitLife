import SwiftUI
import SwiftData

@main
struct FitLifeApp: App {
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            UserData.self,
            FoodEntry.self,
            Product.self,
            CustomProduct.self,
            WaterIntake.self,
            BodyMeasurements.self
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
        WindowGroup {
            RootView()
                .id(appLanguageRaw)
                .environment(\.locale, AppLanguage.from(rawValue: appLanguageRaw).locale)
        }
            .modelContainer(modelContainer)
    }
}
