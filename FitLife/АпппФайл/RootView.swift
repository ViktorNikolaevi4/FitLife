import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    var body: some View {
        if sessionStore.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else if sessionStore.firebaseUser == nil {
            AuthScreen()
        } else {
            if didOnboard, users.isEmpty == false {
                MainTabView()
            } else {
                OnboardingView { payload in
                    let calories = MacrosCalculator.calculateCaloriesMifflin(
                        gender: payload.gender,
                        weight: payload.weight,
                        height: payload.height,
                        age: payload.age,
                        activityLevel: payload.activity,
                        goal: payload.goal
                    )
                    let m = MacrosCalculator.calculateMacros(
                        calories: calories,
                        goal: payload.goal
                    )

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
}
