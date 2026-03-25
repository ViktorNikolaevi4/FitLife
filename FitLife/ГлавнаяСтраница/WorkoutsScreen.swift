import SwiftUI
import SwiftData

struct WorkoutsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var workouts: [WorkoutSession]
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @State private var selectedWorkout: WorkoutSession?

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var relevantWorkouts: [WorkoutSession] {
        workouts.filter { $0.gender == selectedGender }
    }
    private var activeWorkout: WorkoutSession? {
        relevantWorkouts
            .filter { $0.endedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    private var lastWorkout: WorkoutSession? {
        relevantWorkouts
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppLocalizer.string("workouts.diary.title"))
                        .font(.largeTitle.bold())
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        WorkoutsShortcutCard(
                            title: AppLocalizer.string("workouts.history"),
                            systemImage: "clock.arrow.circlepath",
                            theme: theme,
                            action: {}
                        )

                        WorkoutsShortcutCard(
                            title: AppLocalizer.string("workouts.templates"),
                            systemImage: "square.grid.2x2.fill",
                            theme: theme,
                            action: {}
                        )
                    }
                    .padding(.horizontal)

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.last"),
                        subtitle: lastWorkoutSubtitle,
                        systemImage: "figure.strengthtraining.traditional",
                        tint: .orange,
                        theme: theme,
                        action: {}
                    )

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.new"),
                        subtitle: activeWorkout == nil
                            ? AppLocalizer.string("workouts.new.subtitle")
                            : AppLocalizer.string("workouts.new.resume"),
                        systemImage: "dumbbell.fill",
                        tint: .blue,
                        theme: theme,
                        action: openActiveWorkout
                    )

                    Button(action: {}) {
                        HStack {
                            Text(AppLocalizer.string("workouts.weekly.activity"))
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.black))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 6)
                }
                .padding(.vertical, 16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedWorkout) { workout in
                ActiveWorkoutScreen(workout: workout)
            }
        }
    }

    private var lastWorkoutSubtitle: String {
        guard let lastWorkout else { return AppLocalizer.string("workouts.last.subtitle") }
        let exercisesCount = lastWorkout.exercises.count
        let completedSets = lastWorkout.exercises.flatMap(\.sets).filter(\.isCompleted).count
        return AppLocalizer.format("workouts.last.summary", exercisesCount, completedSets)
    }

    private func openActiveWorkout() {
        if let activeWorkout {
            selectedWorkout = activeWorkout
            return
        }

        let workout = WorkoutSession(
            title: AppLocalizer.string("workout.active.title"),
            gender: selectedGender
        )

        modelContext.insert(workout)
        try? modelContext.save()
        selectedWorkout = workout
    }
}

private struct WorkoutsShortcutCard: View {
    let title: String
    let systemImage: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(theme.subtleFill))

                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18).fill(theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.border))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutsFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(tint.opacity(0.14))

                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(theme.border))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
