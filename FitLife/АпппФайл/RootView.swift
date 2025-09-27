import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    var body: some View {
        if didOnboard, users.isEmpty == false {
            MainTabView()
        } else {
            OnboardingView { payload in
                // 1) калории по твоей формуле
                let calories = MacrosCalculator.calculateCaloriesMifflin(
                    gender: payload.gender,
                    weight: payload.weight,
                    height: payload.height,
                    age: payload.age,
                    activityLevel: payload.activity,
                    goal: payload.goal
                )
                // 2) БЖУ по твоим процентам
                let m = MacrosCalculator.calculateMacros(
                    calories: calories,
                    goal: payload.goal
                )

                // 3) создаём пользователя
                let user = UserData(
                    weight: payload.weight,
                    height: payload.height,
                    age: payload.age,
                    activityLevel: payload.activity,
                    goal: payload.goal,
                    gender: payload.gender,
                    calories: calories,
                    proteins: m.proteins,
                    fats: m.fats,
                    carbs: m.carbs
                )
                modelContext.insert(user)
                try? modelContext.save()

                activeGenderRaw = payload.gender.rawValue
                didOnboard = true
            }
        }
    }
}
