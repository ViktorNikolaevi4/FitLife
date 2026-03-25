import SwiftUI
import SwiftData

struct ActiveWorkoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workout: WorkoutSession
    @State private var isShowingExercisePicker = false

    private var sortedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var elapsedString: String {
        let interval = max(0, workout.elapsedSeconds)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                activeWorkoutHeader
                timerCard

                if sortedExercises.isEmpty {
                    emptyStateCard
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(sortedExercises, id: \.id) { exercise in
                            WorkoutExerciseCard(
                                exercise: exercise,
                                onToggleExpanded: { toggleExpanded(exercise) },
                                onToggleSet: { set in toggleSet(set) },
                                onAddSet: { addSet(to: exercise) },
                                onDeleteSet: { set in deleteSet(set, from: exercise) },
                                onDeleteExercise: { deleteExercise(exercise) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button(action: { isShowingExercisePicker = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                    Text(AppLocalizer.string("workout.add.exercise"))
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(.black))
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
            }
            .buttonStyle(.plain)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard workout.isTimerRunning else { return }
            workout.elapsedSeconds += 1
            try? modelContext.save()
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            AddWorkoutExerciseScreen(
                templates: exerciseTemplates(),
                onAddExercise: { draft in
                    addExercise(draft: draft)
                    isShowingExercisePicker = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.systemGray6))

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(.systemGray))
            }
            .frame(width: 72, height: 72)

            Text(AppLocalizer.string("workout.empty.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(AppLocalizer.string("workout.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white))
    }

    private var activeWorkoutHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(AppLocalizer.string("workout.active.title"))
                .font(.headline.weight(.semibold))

            Spacer()

            Button(action: finishWorkout) {
                Text(AppLocalizer.string("workout.finish"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
    }

    private var timerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))

                Image(systemName: "clock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalizer.string("workout.timer"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(elapsedString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Spacer()

            Button(action: toggleTimer) {
                Image(systemName: workout.isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
    }

    private func toggleExpanded(_ exercise: WorkoutExercise) {
        withAnimation(.easeInOut(duration: 0.22)) {
            exercise.isExpanded.toggle()
        }
        try? modelContext.save()
    }

    private func toggleSet(_ set: WorkoutSet) {
        set.isCompleted.toggle()
        try? modelContext.save()
    }

    private func addSet(to exercise: WorkoutExercise) {
        let nextIndex = exercise.sets.count
        let lastSet = exercise.sets.sorted { $0.orderIndex < $1.orderIndex }.last
        let set = WorkoutSet(
            orderIndex: nextIndex,
            weight: lastSet?.weight ?? 20,
            reps: lastSet?.reps ?? 10
        )
        set.exercise = exercise
        exercise.sets.append(set)
        try? modelContext.save()
    }

    private func deleteSet(_ set: WorkoutSet, from exercise: WorkoutExercise) {
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        reindexSets(in: exercise)
        try? modelContext.save()
    }

    private func deleteExercise(_ exercise: WorkoutExercise) {
        workout.exercises.removeAll { $0.id == exercise.id }
        modelContext.delete(exercise)
        reindexExercises()
        try? modelContext.save()
    }

    private func addExercise(draft: WorkoutExerciseDraft) {
        let index = workout.exercises.count
        let exercise = WorkoutExercise(
            name: draft.name,
            systemImage: draft.systemImage,
            accentName: draft.accentName,
            orderIndex: index
        )
        exercise.session = workout

        for (setIndex, setPreset) in draft.sets.enumerated() {
            let set = WorkoutSet(orderIndex: setIndex, weight: setPreset.weight, reps: setPreset.reps)
            set.exercise = exercise
            exercise.sets.append(set)
        }

        workout.exercises.append(exercise)
        try? modelContext.save()
    }

    private func exerciseTemplates() -> [WorkoutExerciseTemplate] {
        [
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.bench"),
                systemImage: "figure.strengthtraining.traditional",
                accentName: "blue",
                defaultSets: [(60, 12), (65, 10), (70, 8)]
            ),
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.row"),
                systemImage: "dumbbell.fill",
                accentName: "orange",
                defaultSets: [(40, 12), (45, 10), (50, 8)]
            ),
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.press"),
                systemImage: "figure.arms.open",
                accentName: "purple",
                defaultSets: [(18, 12), (18, 10), (20, 8)]
            ),
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.lat"),
                systemImage: "figure.mixed.cardio",
                accentName: "green",
                defaultSets: [(35, 12), (40, 10), (45, 8)]
            ),
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.legs"),
                systemImage: "figure.run.square.stack",
                accentName: "orange",
                defaultSets: [(80, 12), (90, 10), (100, 8)]
            ),
            WorkoutExerciseTemplate(
                name: AppLocalizer.string("workout.exercise.core"),
                systemImage: "figure.core.training",
                accentName: "blue",
                defaultSets: [(0, 20), (0, 18), (0, 15)]
            )
        ]
    }

    private func toggleTimer() {
        workout.isTimerRunning.toggle()
        try? modelContext.save()
    }

    private func reindexExercises() {
        for (index, exercise) in workout.exercises
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            exercise.orderIndex = index
        }
    }

    private func reindexSets(in exercise: WorkoutExercise) {
        for (index, item) in exercise.sets
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            item.orderIndex = index
        }
    }

    private func finishWorkout() {
        workout.isTimerRunning = false
        workout.endedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
