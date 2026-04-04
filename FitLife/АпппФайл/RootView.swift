import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]
    @State private var preparedOwnerId: String?
    @State private var isPreparingLocalData = false

    private var currentOwnerId: String? {
        sessionStore.firebaseUser?.uid
    }

    private var currentUserData: [UserData] {
        guard let currentOwnerId else { return [] }
        return users.filter { $0.ownerId == currentOwnerId }
    }

    var body: some View {
        Group {
            if sessionStore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if sessionStore.firebaseUser == nil {
                AuthScreen()
            } else if isPreparingLocalData {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                if didOnboard, currentUserData.isEmpty == false {
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
                            ownerId: currentOwnerId ?? "",
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
        .onAppear {
            prepareLocalDataIfNeeded()
        }
        .onChange(of: currentOwnerId) { _, _ in
            prepareLocalDataIfNeeded()
        }
    }

    private func prepareLocalDataIfNeeded() {
        guard let currentOwnerId, preparedOwnerId != currentOwnerId else { return }
        isPreparingLocalData = true
        migrateLegacyLocalDataIfNeeded(to: currentOwnerId)
        preparedOwnerId = currentOwnerId
        isPreparingLocalData = false
    }

    private func migrateLegacyLocalDataIfNeeded(to ownerId: String) {
        do {
            let localUsers = try modelContext.fetch(FetchDescriptor<UserData>())
            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
            let waterEntries = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            let measurements = try modelContext.fetch(FetchDescriptor<BodyMeasurements>())
            let workouts = try modelContext.fetch(FetchDescriptor<WorkoutSession>())

            var didMutate = false

            for item in localUsers where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in foodEntries where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in waterEntries where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in measurements where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in workouts where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }

            if didMutate {
                try? modelContext.save()
            }
        } catch {}
    }
}
