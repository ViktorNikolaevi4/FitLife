import SwiftUI
import SwiftData
import FirebaseFirestore

private let activeWorkoutCardBackground = Color(.secondarySystemBackground)
private let activeWorkoutInsetBackground = Color(.tertiarySystemBackground)
private let activeWorkoutCardBorder = Color(.separator).opacity(0.40)

struct ActiveWorkoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let workout: WorkoutSession
    @State private var isShowingExercisePicker = false
    @State private var editingSet: WorkoutSet?
    @State private var editingExerciseNote: WorkoutExercise?
    @State private var isEditingWorkoutNote = false
    @State private var showFinishConfirmation = false
    private let firestore = Firestore.firestore()

    private var sortedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
    private var activeWorkoutCardShadow: Color { colorScheme == .dark ? .clear : .black.opacity(0.08) }

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
                workoutControlsCard

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
                                onEditNote: { editingExerciseNote = exercise },
                                onToggleSet: { set in toggleSet(set) },
                                onEditSet: { set in editingSet = set },
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
                Text(AppLocalizer.string("workout.add.exercise"))
                    .fontWeight(.semibold)
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.primary))
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
        .onAppear {
            collapseExercisesIfNeeded()
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            AddWorkoutExerciseScreen(
                templates: workoutTemplates(),
                onAddExercise: { draft in
                    addExercise(draft: draft)
                    isShowingExercisePicker = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(item: $editingSet) { set in
            EditWorkoutSetScreen(
                set: set,
                onSave: { weight, reps, durationSeconds, metricType in
                    updateSet(
                        set,
                        weight: weight,
                        reps: reps,
                        durationSeconds: durationSeconds,
                        metricType: metricType
                    )
                },
                onDelete: {
                    if let exercise = set.exercise {
                        deleteSet(set, from: exercise)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingExerciseNote) { exercise in
            EditWorkoutExerciseNoteScreen(
                exercise: exercise,
                onSave: { note in
                    updateExerciseNote(exercise, note: note)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingWorkoutNote) {
            EditWorkoutSessionNoteScreen(
                workout: workout,
                onSave: { note in
                    updateWorkoutNote(note)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            AppLocalizer.string("workout.finish.confirm.title"),
            isPresented: $showFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("workout.finish.confirm.action"), role: .destructive) {
                finishWorkout()
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalizer.string("workout.finish.confirm.message"))
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(activeWorkoutInsetBackground)

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
        .background(RoundedRectangle(cornerRadius: 28).fill(activeWorkoutCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(activeWorkoutCardBorder)
        )
        .shadow(color: activeWorkoutCardShadow, radius: 16, x: 0, y: 6)
    }

    private var activeWorkoutHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(activeWorkoutCardBackground))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(AppLocalizer.string("workout.active.title"))
                .font(.headline.weight(.semibold))

            Spacer()

            Button(action: { showFinishConfirmation = true }) {
                Label(AppLocalizer.string("workout.finish"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.green))
            }
            .buttonStyle(.plain)
        }
    }

    private var workoutControlsCard: some View {
        HStack(spacing: 12) {
            Button(action: toggleTimer) {
                Image(systemName: workout.isTimerRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalizer.string("workout.timer"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(elapsedString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            Button(action: { isEditingWorkoutNote = true }) {
                HStack(spacing: 8) {
                    Image(systemName: workout.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "note.text" : "note.text.badge.plus")
                        .font(.system(size: 15, weight: .semibold))

                    Text(
                        workout.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AppLocalizer.string("workout.note.compact.add")
                        : AppLocalizer.string("workout.note.compact.added")
                    )
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Capsule().fill(activeWorkoutInsetBackground))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 22).fill(activeWorkoutCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(activeWorkoutCardBorder)
        )
        .shadow(color: activeWorkoutCardShadow.opacity(0.9), radius: 12, x: 0, y: 4)
    }

    private func toggleExpanded(_ exercise: WorkoutExercise) {
        withAnimation(.easeInOut(duration: 0.22)) {
            exercise.isExpanded.toggle()
        }
        try? modelContext.save()
    }

    private func collapseExercisesIfNeeded() {
        var hasChanges = false
        for exercise in workout.exercises where exercise.isExpanded {
            exercise.isExpanded = false
            hasChanges = true
        }
        if hasChanges {
            try? modelContext.save()
        }
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
            reps: lastSet?.reps ?? 10,
            durationSeconds: lastSet?.durationSeconds ?? 30,
            metricType: lastSet?.metricType ?? .reps
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

    private func updateExerciseNote(_ exercise: WorkoutExercise, note: String) {
        exercise.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    private func updateWorkoutNote(_ note: String) {
        workout.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let set = WorkoutSet(
                orderIndex: setIndex,
                weight: setPreset.weight,
                reps: setPreset.reps,
                durationSeconds: setPreset.durationSeconds,
                metricType: setPreset.metricType
            )
            set.exercise = exercise
            exercise.sets.append(set)
        }

        workout.exercises.append(exercise)
        try? modelContext.save()
    }

    private func updateSet(
        _ set: WorkoutSet,
        weight: Double,
        reps: Int,
        durationSeconds: Int,
        metricType: WorkoutSetMetricType
    ) {
        set.weight = weight
        set.metricType = metricType
        set.reps = reps
        set.durationSeconds = durationSeconds
        try? modelContext.save()
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
        LocalReminderScheduler.rescheduleWorkoutRemindersIfEnabled(
            modelContext: modelContext,
            ownerId: workout.ownerId,
            gender: workout.gender
        )
        syncCompletedAssignmentIfNeeded()
        dismiss()
    }

    private func syncCompletedAssignmentIfNeeded() {
        guard let assignmentId = workout.remoteAssignmentId else { return }

        Task {
            try? await firestore
                .collection("workout_assignments")
                .document(assignmentId)
                .setData(["status": WorkoutAssignmentStatus.completed.rawValue], merge: true)
        }
    }
}

private struct EditWorkoutExerciseNoteScreen: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: WorkoutExercise
    let onSave: (String) -> Void

    @State private var note: String
    @FocusState private var isNoteFocused: Bool

    init(exercise: WorkoutExercise, onSave: @escaping (String) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _note = State(initialValue: exercise.note)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppLocalizer.string("workout.exercise.note.title"))
                    .font(.title3.weight(.semibold))

                TextField(
                    AppLocalizer.string("workout.exercise.note.placeholder"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($isNoteFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(activeWorkoutInsetBackground))

                Button(action: save) {
                    Text(AppLocalizer.string("workout.exercise.note.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNoteFocused = true
                }
            }
        }
    }

    private func save() {
        onSave(note)
        dismiss()
    }
}

private struct EditWorkoutSessionNoteScreen: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutSession
    let onSave: (String) -> Void

    @State private var note: String
    @FocusState private var isNoteFocused: Bool

    init(workout: WorkoutSession, onSave: @escaping (String) -> Void) {
        self.workout = workout
        self.onSave = onSave
        _note = State(initialValue: workout.note)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppLocalizer.string("workout.note.title"))
                    .font(.title3.weight(.semibold))

                TextField(
                    AppLocalizer.string("workout.note.placeholder"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($isNoteFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(activeWorkoutInsetBackground))

                Button(action: save) {
                    Text(AppLocalizer.string("workout.note.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNoteFocused = true
                }
            }
        }
    }

    private func save() {
        onSave(note)
        dismiss()
    }
}

private struct EditWorkoutSetScreen: View {
    @Environment(\.dismiss) private var dismiss

    let set: WorkoutSet
    let onSave: (Double, Int, Int, WorkoutSetMetricType) -> Void
    let onDelete: () -> Void

    @State private var draftSet: WorkoutDraftSet
    @State private var showDeleteConfirmation = false

    init(
        set: WorkoutSet,
        onSave: @escaping (Double, Int, Int, WorkoutSetMetricType) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.set = set
        self.onSave = onSave
        self.onDelete = onDelete
        _draftSet = State(
            initialValue: WorkoutDraftSet(
                weight: set.weight,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: set.metricType
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalizer.string("workout.set.edit.title"))
                            .font(.title3.weight(.semibold))
                        Text(AppLocalizer.string("workout.set.edit.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    WorkoutDraftSetEditorRow(
                        title: AppLocalizer.format("workout.setup.set.title", set.orderIndex + 1),
                        set: draftSet,
                        onChange: { draftSet = $0 },
                        onDelete: {},
                        canDelete: false
                    )

                    Button(action: save) {
                        Text(AppLocalizer.string("workout.set.edit.save"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(AppLocalizer.string("workout.set.delete"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(activeWorkoutInsetBackground))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                AppLocalizer.string("workout.set.delete.title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(AppLocalizer.string("workout.set.delete"), role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
            } message: {
                Text(AppLocalizer.string("workout.set.delete.message"))
            }
        }
    }

    private func save() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        DispatchQueue.main.async {
            onSave(draftSet.weight, draftSet.reps, draftSet.durationSeconds, draftSet.metricType)
            dismiss()
        }
    }
}
