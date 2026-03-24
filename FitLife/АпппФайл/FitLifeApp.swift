import SwiftUI
import SwiftData
import Foundation

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
            BodyMeasurements.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            CustomWorkoutExerciseTemplate.self
        ])

        #if DEBUG
        let inMemory = ProcessInfo.processInfo.arguments.contains("--in-memory-store")
        #else
        let inMemory = false
        #endif

        let hasICloudAccount = FileManager.default.ubiquityIdentityToken != nil

        do {
            let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
                (!inMemory && hasICloudAccount) ? .automatic : .none
            let ck = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: cloudKitDatabase
            )
            return try ModelContainer(for: schema, configurations: ck)
        } catch {
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
