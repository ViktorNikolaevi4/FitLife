import SwiftUI
import SwiftData
import Foundation
import FirebaseCore

@main
struct FitLifeApp: App {
    @UIApplicationDelegateAdaptor(FitLifeAppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @StateObject private var sessionStore: AppSessionStore
    @StateObject private var productCatalogStore: ProductCatalogStore
    @StateObject private var notificationsStore: AppNotificationsStore
    @StateObject private var pushNotificationsManager: AppPushNotificationsManager

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

        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            (!inMemory && hasICloudAccount) ? .automatic : .none

        let primaryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: cloudKitDatabase
        )

        if let container = try? ModelContainer(for: schema, configurations: primaryConfiguration) {
            return container
        }

        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(for: schema, configurations: localConfiguration) {
            return container
        }

        let inMemoryFallback = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(for: schema, configurations: inMemoryFallback) {
            return container
        }

        fatalError("Failed to initialize SwiftData ModelContainer for FitLifeApp.")
    }()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        UserDefaults.standard.register(defaults: [
            LocalReminderScheduler.mealRemindersEnabledKey: true,
            LocalReminderScheduler.workoutReminderEnabledKey: true,
            LocalReminderScheduler.unfinishedWorkoutReminderEnabledKey: true
        ])

        _sessionStore = StateObject(wrappedValue: AppSessionStore())
        _productCatalogStore = StateObject(wrappedValue: ProductCatalogStore())
        _notificationsStore = StateObject(wrappedValue: AppNotificationsStore())
        _pushNotificationsManager = StateObject(wrappedValue: AppPushNotificationsManager.shared)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(appLanguageRaw)
                .environment(\.locale, AppLanguage.from(rawValue: appLanguageRaw).locale)
                .environmentObject(sessionStore)
                .environmentObject(productCatalogStore)
                .environmentObject(notificationsStore)
                .environmentObject(pushNotificationsManager)
        }
            .modelContainer(modelContainer)
    }
}
