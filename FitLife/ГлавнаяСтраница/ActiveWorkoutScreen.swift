import SwiftUI
import SwiftData
import FirebaseFirestore

private let activeWorkoutCardBackground = Color(.secondarySystemBackground)
private let activeWorkoutInsetBackground = Color(.tertiarySystemBackground)
private let activeWorkoutCardBorder = Color(.separator).opacity(0.40)

private func localizedWorkoutSessionTitle(_ title: String) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedTitle.isEmpty ||
        trimmedTitle == "Активная тренировка" ||
        trimmedTitle == "Active Workout" {
        return AppLocalizer.string("workout.active.title")
    }
    return trimmedTitle
}

struct ActiveWorkoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var users: [UserData]

    let workout: WorkoutSession
    @State private var isShowingExercisePicker = false
    @State private var isShowingBlockEditor = false
    @State private var exerciseTargetBlock: WorkoutBlock?
    @State private var editingSet: WorkoutSet?
    @State private var editingExerciseNote: WorkoutExercise?
    @State private var isEditingWorkoutTitle = false
    @State private var isEditingWorkoutNote = false
    @State private var showFinishConfirmation = false
    private let firestore = Firestore.firestore()

    private var sortedExercises: [WorkoutExercise] {
        workout.exerciseItems.sorted { $0.orderIndex < $1.orderIndex }
    }
    private var sortedBlockGroups: [WorkoutBlockExerciseGroup] {
        let blocks = workout.blockItems.sorted { $0.orderIndex < $1.orderIndex }
        var groups = blocks.map { block in
            WorkoutBlockExerciseGroup(
                id: block.id.uuidString,
                block: block,
                title: displayTitle(for: block),
                subtitle: subtitle(for: block),
                exercises: block.exerciseItems.sorted { $0.orderIndex < $1.orderIndex }
            )
        }

        let groupedExerciseIds = Set(groups.flatMap { $0.exercises.map(\.id) })
        let ungroupedExercises = sortedExercises.filter { groupedExerciseIds.contains($0.id) == false }
        if ungroupedExercises.isEmpty == false {
            groups.insert(
                WorkoutBlockExerciseGroup(
                    id: "legacy-strength",
                    block: nil,
                    title: AppLocalizer.string("workout.block.strength.title"),
                    subtitle: AppLocalizer.format("workout.block.exercise_count", ungroupedExercises.count),
                    exercises: ungroupedExercises
                ),
                at: 0
            )
        }

        return groups.filter { $0.exercises.isEmpty == false }
    }
    private var activeWorkoutCardShadow: Color { colorScheme == .dark ? .clear : .black.opacity(0.08) }
    private var workoutTitle: String {
        localizedWorkoutSessionTitle(workout.title)
    }
    private var currentUserWeight: Double {
        users.first { $0.ownerId == workout.ownerId && $0.gender == workout.gender }?.weight
            ?? users.first { $0.gender == workout.gender }?.weight
            ?? 70
    }
    private var currentEstimatedCalories: Int {
        WorkoutCalorieEstimator.estimateWorkoutCalories(
            workout: workout,
            userWeightKg: currentUserWeight
        )
    }
    private var shouldShowEmptyState: Bool {
        sortedExercises.isEmpty && workout.blockItems.count <= 1
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                activeWorkoutHeader
                workoutControlsCard

                if shouldShowEmptyState {
                    emptyStateCard
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(sortedBlockGroups) { group in
                            WorkoutBlockSectionHeader(
                                title: group.title,
                                subtitle: group.subtitle,
                                onAddExercise: group.block.map { block in
                                    {
                                        exerciseTargetBlock = block
                                        isShowingExercisePicker = true
                                    }
                                }
                            )

                            ForEach(group.exercises, id: \.id) { exercise in
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
            HStack(spacing: 10) {
                Button(action: {
                    exerciseTargetBlock = defaultStrengthBlock()
                    isShowingExercisePicker = true
                }) {
                    Text(AppLocalizer.string("workout.add.exercise"))
                        .fontWeight(.semibold)
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
                }
                .buttonStyle(.plain)

                Button(action: { isShowingBlockEditor = true }) {
                    Label(AppLocalizer.string("workout.add.block"), systemImage: "square.stack.3d.up.fill")
                        .labelStyle(.iconOnly)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 58, height: 58)
                        .background(RoundedRectangle(cornerRadius: 20).fill(activeWorkoutCardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(activeWorkoutCardBorder))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.string("workout.add.block"))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            stopLegacyTimerIfNeeded()
            ensureWorkoutBlocksIfNeeded()
            collapseExercisesIfNeeded()
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            AddWorkoutExerciseScreen(
                templates: workoutTemplates(),
                onAddExercise: { draft in
                    addExercise(draft: draft, to: exerciseTargetBlock)
                    exerciseTargetBlock = nil
                    isShowingExercisePicker = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isShowingBlockEditor) {
            AddWorkoutBlockScreen { draft in
                addBlock(draft)
                isShowingBlockEditor = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingWorkoutTitle) {
            EditWorkoutSessionTitleScreen(
                workout: workout,
                fallbackTitle: AppLocalizer.string("workout.active.title"),
                onSave: { title in
                    updateWorkoutTitle(title)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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

            Button(action: { isEditingWorkoutTitle = true }) {
                HStack(spacing: 6) {
                    Text(workoutTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
        HStack(spacing: 10) {
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
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Capsule().fill(activeWorkoutInsetBackground))
            }
            .buttonStyle(.plain)

            HStack(spacing: 7) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(formattedWorkoutCalories(currentEstimatedCalories))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().fill(activeWorkoutInsetBackground))
            .accessibilityLabel(AppLocalizer.string("workout.last.calories"))
            .accessibilityValue(formattedWorkoutCalories(currentEstimatedCalories))
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
        for exercise in workout.exerciseItems where exercise.isExpanded {
            exercise.isExpanded = false
            hasChanges = true
        }
        if hasChanges {
            try? modelContext.save()
        }
    }

    private func stopLegacyTimerIfNeeded() {
        guard workout.isTimerRunning else { return }
        workout.isTimerRunning = false
        try? modelContext.save()
    }

    private func ensureWorkoutBlocksIfNeeded() {
        let strengthBlock = defaultStrengthBlock()
        var didMutate = false

        for exercise in workout.exerciseItems where exercise.block == nil {
            exercise.block = strengthBlock
            if strengthBlock.exerciseItems.contains(where: { $0.id == exercise.id }) == false {
                strengthBlock.exerciseItems.append(exercise)
            }
            didMutate = true
        }

        if didMutate {
            try? modelContext.save()
        }
    }

    private func toggleSet(_ set: WorkoutSet) {
        set.isCompleted.toggle()
        try? modelContext.save()
    }

    private func addSet(to exercise: WorkoutExercise) {
        let nextIndex = exercise.setItems.count
        let lastSet = exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }.last
        let set = WorkoutSet(
            orderIndex: nextIndex,
            weight: lastSet?.weight ?? 20,
            reps: lastSet?.reps ?? 10,
            durationSeconds: lastSet?.durationSeconds ?? 30,
            metricType: lastSet?.metricType ?? .reps
        )
        set.exercise = exercise
        exercise.setItems.append(set)
        try? modelContext.save()
    }

    private func deleteSet(_ set: WorkoutSet, from exercise: WorkoutExercise) {
        exercise.setItems.removeAll { $0.id == set.id }
        modelContext.delete(set)
        reindexSets(in: exercise)
        try? modelContext.save()
    }

    private func deleteExercise(_ exercise: WorkoutExercise) {
        workout.exerciseItems.removeAll { $0.id == exercise.id }
        exercise.block?.exerciseItems.removeAll { $0.id == exercise.id }
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

    private func updateWorkoutTitle(_ title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.title = trimmedTitle.isEmpty ? AppLocalizer.string("workout.active.title") : trimmedTitle
        try? modelContext.save()
    }

    private func addExercise(draft: WorkoutExerciseDraft) {
        addExercise(draft: draft, to: defaultStrengthBlock())
    }

    private func addExercise(draft: WorkoutExerciseDraft, to targetBlock: WorkoutBlock?) {
        let block = targetBlock ?? defaultStrengthBlock()
        let index = workout.exerciseItems.count
        let exercise = WorkoutExercise(
            name: draft.name,
            systemImage: draft.systemImage,
            accentName: draft.accentName,
            orderIndex: index,
            activityType: draft.activityType,
            metValue: draft.metValue
        )
        exercise.session = workout
        exercise.block = block

        for (setIndex, setPreset) in draft.sets.enumerated() {
            let set = WorkoutSet(
                orderIndex: setIndex,
                weight: setPreset.weight,
                reps: setPreset.reps,
                durationSeconds: setPreset.durationSeconds,
                metricType: setPreset.metricType
            )
            set.exercise = exercise
            exercise.setItems.append(set)
        }

        workout.exerciseItems.append(exercise)
        block.exerciseItems.append(exercise)
        try? modelContext.save()
    }

    private func addBlock(_ draft: WorkoutBlockDraft) {
        let block = WorkoutBlock(
            title: draft.resolvedTitle,
            type: draft.type,
            orderIndex: workout.blockItems.count,
            rounds: draft.rounds,
            restBetweenRoundsSeconds: draft.restBetweenRoundsSeconds
        )
        block.session = workout
        modelContext.insert(block)
        workout.blockItems.append(block)
        try? modelContext.save()
    }

    private func defaultStrengthBlock() -> WorkoutBlock {
        if let existing = workout.blockItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .first(where: { $0.type == .strength }) {
            return existing
        }

        let block = WorkoutBlock(
            title: AppLocalizer.string("workout.block.strength.title"),
            type: .strength,
            orderIndex: workout.blockItems.count
        )
        block.session = workout
        modelContext.insert(block)
        workout.blockItems.append(block)
        try? modelContext.save()
        return block
    }

    private func displayTitle(for block: WorkoutBlock) -> String {
        let trimmedTitle = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return block.type.title
        }
        return trimmedTitle
    }

    private func subtitle(for block: WorkoutBlock) -> String {
        switch block.type {
        case .circuit:
            return AppLocalizer.format(
                "workout.block.circuit.summary",
                block.rounds,
                block.exerciseItems.count,
                block.restBetweenRoundsSeconds
            )
        default:
            return AppLocalizer.format("workout.block.exercise_count", block.exerciseItems.count)
        }
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

    private func reindexExercises() {
        for (index, exercise) in workout.exerciseItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            exercise.orderIndex = index
        }
    }

    private func reindexSets(in exercise: WorkoutExercise) {
        for (index, item) in exercise.setItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            item.orderIndex = index
        }
    }

    private func finishWorkout() {
        workout.isTimerRunning = false
        workout.estimatedCalories = WorkoutCalorieEstimator.estimateWorkoutCalories(
            workout: workout,
            userWeightKg: currentUserWeight
        )
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

private struct WorkoutBlockExerciseGroup: Identifiable {
    let id: String
    let block: WorkoutBlock?
    let title: String
    let subtitle: String
    let exercises: [WorkoutExercise]
}

private struct WorkoutBlockSectionHeader: View {
    let title: String
    let subtitle: String
    var onAddExercise: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.14))

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onAddExercise {
                Button(action: onAddExercise) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.string("workout.add.exercise"))
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
}

private struct WorkoutBlockDraft {
    var title: String
    var type: WorkoutBlockType
    var rounds: Int
    var restBetweenRoundsSeconds: Int

    var resolvedTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return type.title
        }
        return trimmedTitle
    }
}

private struct AddWorkoutBlockScreen: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (WorkoutBlockDraft) -> Void

    @State private var type: WorkoutBlockType = .circuit
    @State private var title = ""
    @State private var rounds = 3
    @State private var restBetweenRoundsSeconds = 60

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(AppLocalizer.string("workout.block.type"), selection: $type) {
                        ForEach(WorkoutBlockType.templateCases, id: \.self) { blockType in
                            Text(blockType.title).tag(blockType)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(AppLocalizer.string("workout.block.title.placeholder"), text: $title)
                }

                if type == .circuit {
                    Section(AppLocalizer.string("workout.block.circuit.settings")) {
                        Stepper(
                            AppLocalizer.format("workout.block.rounds.value", rounds),
                            value: $rounds,
                            in: 1...20
                        )
                        Stepper(
                            AppLocalizer.format("workout.block.round_rest.value", restBetweenRoundsSeconds),
                            value: $restBetweenRoundsSeconds,
                            in: 0...600,
                            step: 5
                        )
                    }
                }
            }
            .navigationTitle(AppLocalizer.string("workout.block.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.save")) {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        onSave(
            WorkoutBlockDraft(
                title: title,
                type: type,
                rounds: type == .circuit ? rounds : 1,
                restBetweenRoundsSeconds: type == .circuit ? restBetweenRoundsSeconds : 0
            )
        )
        dismiss()
    }
}

private struct EditWorkoutSessionTitleScreen: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutSession
    let fallbackTitle: String
    let onSave: (String) -> Void

    @State private var title: String
    @FocusState private var isTitleFocused: Bool

    init(workout: WorkoutSession, fallbackTitle: String, onSave: @escaping (String) -> Void) {
        self.workout = workout
        self.fallbackTitle = fallbackTitle
        self.onSave = onSave
        _title = State(initialValue: localizedWorkoutSessionTitle(workout.title))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppLocalizer.string("workout.title.edit"))
                    .font(.title3.weight(.semibold))

                TextField(
                    AppLocalizer.string("workout.title.placeholder"),
                    text: $title
                )
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($isTitleFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(activeWorkoutInsetBackground))
                .onSubmit(save)

                Button(action: save) {
                    Text(AppLocalizer.string("workout.title.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
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
                    isTitleFocused = true
                }
            }
        }
    }

    private func save() {
        onSave(title)
        dismiss()
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
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
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
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
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
                            .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
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
