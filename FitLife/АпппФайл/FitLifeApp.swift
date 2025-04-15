
import SwiftUI
import SwiftData

@main
struct FitLifeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserData.self,
                              FoodEntry.self,
                              Product.self,
                              CustomProduct.self,
                              WaterIntake.self
                             ])
    }
}

