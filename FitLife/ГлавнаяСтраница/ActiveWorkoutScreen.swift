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
    @State private var isAddingBlock = false
    @State private var processedBlockSubmissionIDs: Set<UUID> = []
    @State private var isShowingAIGenerator = false
    @State private var isShowingAddMenu = false
    @State private var collapsedBlockIds: Set<String> = []
    @State private var exerciseTargetBlock: WorkoutBlock?
    @State private var pendingDeleteBlock: WorkoutBlock?
    @State private var pendingDeleteExercise: WorkoutExercise?
    @State private var isEditingWorkoutTitle = false
    @State private var isEditingWorkoutNote = false
    @State private var showFinishConfirmation = false
    @State private var isShowingEffortPicker = false
    @State private var shouldShowCompletionAfterEffortPicker = false
    @State private var isShowingCompletionSummary = false
    @State private var exerciseTemplates: [WorkoutExerciseTemplate] = []
    @State private var selectedExercise: WorkoutExercise?
    @State private var selectedBlock: WorkoutBlock?
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
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

        // Empty blocks are useful while composing an active workout: the user
        // must be able to see a newly created block and add exercises to it.
        return groups
    }
    private var activeWorkoutCardShadow: Color { colorScheme == .dark ? .clear : .black.opacity(0.08) }
    private var workoutTitle: String {
        localizedWorkoutSessionTitle(workout.title)
    }
    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
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
        sortedExercises.isEmpty && workout.blockItems.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                                iconName: blockIconName(for: group.block),
                                onStart: runnerAction(for: group.block),
                                isCompleted: group.block?.isFinished == true,
                                onAddExercise: group.block.map { block in
                                    {
                                        exerciseTargetBlock = block
                                        isShowingExercisePicker = true
                                    }
                                },
                                isExpanded: collapsedBlockIds.contains(group.id) == false,
                                onToggleExpanded: { toggleBlock(group.id) },
                                onDelete: group.block.map { block in
                                    { pendingDeleteBlock = block }
                                }
                            )

                            if collapsedBlockIds.contains(group.id) == false {
                                ForEach(group.exercises, id: \.id) { exercise in
                                    Button {
                                        selectedExercise = exercise
                                    } label: {
                                        WorkoutExerciseCard(exercise: exercise)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Удалить упражнение", systemImage: "trash", role: .destructive) {
                                            pendingDeleteExercise = exercise
                                        }
                                    }
                                }
                            }
                        }

                        Button(action: { showFinishConfirmation = true }) {
                            Label(
                                AppLocalizer.string("workout.finish"),
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            if isShowingAddMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.2)) {
                            isShowingAddMenu = false
                        }
                    }

                addActionsMenu
                    .padding(.top, 70)
                    .padding(.trailing, 18)
                    .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedExercise) { exercise in
            WorkoutExerciseDetailScreen(
                exercise: exercise,
                followingExercises: followingExercises(after: exercise),
                onOpenExercise: { nextExercise in
                    selectedExercise = nextExercise
                },
                onDeleteExercise: {
                    deleteExercise(exercise)
                },
                onContinueWorkout: {
                    selectedExercise = nil
                    DispatchQueue.main.async {
                        continueWorkout()
                    }
                }
            )
        }
        .navigationDestination(item: $selectedBlock) { block in
            WorkoutBlockRunnerScreen(
                block: block,
                onFinish: {
                    selectedBlock = nil
                    DispatchQueue.main.async {
                        continueWorkout()
                    }
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if hasPendingWorkoutItem {
                    Button(action: continueWorkout) {
                        Label("Продолжить тренировку", systemImage: "play.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: beginAddingExercise) {
                    Text(AppLocalizer.string("workout.add.exercise"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.blue, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .onAppear {
            stopLegacyTimerIfNeeded()
            ensureWorkoutBlocksIfNeeded()
            collapseExercisesIfNeeded()
            preloadExerciseTemplatesIfNeeded()
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            AddWorkoutExerciseScreen(
                templates: exerciseTemplates.isEmpty ? workoutTemplates() : exerciseTemplates,
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
            WorkoutBlockComposerScreen { submissionID, draft in
                guard isAddingBlock == false else { return nil }
                guard processedBlockSubmissionIDs.insert(submissionID).inserted else {
                    return nil
                }
                isAddingBlock = true
                addBlock(draft)
                isShowingBlockEditor = false
                return nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAIGenerator) {
            AIWorkoutGeneratorScreen(
                language: appLanguage,
                existingBlocks: []
            ) { draft in
                addGeneratedDraft(draft)
                isShowingAIGenerator = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Удалить блок?",
            isPresented: Binding(
                get: { pendingDeleteBlock != nil },
                set: { if $0 == false { pendingDeleteBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить блок и упражнения", role: .destructive) {
                if let block = pendingDeleteBlock {
                    deleteBlock(block)
                }
                pendingDeleteBlock = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteBlock = nil
            }
        } message: {
            if let block = pendingDeleteBlock {
                Text("Будет удалён блок «\(displayTitle(for: block))» и все упражнения внутри него.")
            }
        }
        .confirmationDialog(
            "Удалить упражнение?",
            isPresented: Binding(
                get: { pendingDeleteExercise != nil },
                set: { if $0 == false { pendingDeleteExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить упражнение", role: .destructive) {
                if let exercise = pendingDeleteExercise {
                    deleteExercise(exercise)
                }
                pendingDeleteExercise = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteExercise = nil
            }
        } message: {
            if let exercise = pendingDeleteExercise {
                Text("«\(exercise.name)» и все его подходы будут удалены из этой тренировки.")
            }
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
            Button(AppLocalizer.string("workout.finish.confirm.action")) {
                isShowingEffortPicker = true
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalizer.string("workout.finish.confirm.message"))
        }
        .sheet(
            isPresented: $isShowingEffortPicker,
            onDismiss: {
                guard shouldShowCompletionAfterEffortPicker else { return }
                shouldShowCompletionAfterEffortPicker = false
                isShowingCompletionSummary = true
            }
        ) {
            WorkoutEffortPickerSheet(
                baseCalories: currentEstimatedCalories,
                onSelect: { effort in
                    finishWorkout(effort: effort)
                    isShowingEffortPicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isShowingCompletionSummary) {
            WorkoutCompletionSummaryScreen(workout: workout) {
                isShowingCompletionSummary = false
                DispatchQueue.main.async {
                    dismiss()
                }
            }
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

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isShowingAddMenu.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.blue))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Добавить")
        }
    }

    private func beginAddingExercise() {
        // Do not create a placeholder strength block merely by opening the
        // picker. A default block is created only after an exercise is saved.
        exerciseTargetBlock = nil
        isShowingExercisePicker = true
    }

    private var addActionsMenu: some View {
        VStack(spacing: 0) {
            addMenuAction(AppLocalizer.string("workout.add.exercise"), icon: "plus") {
                beginAddingExercise()
            }
            Divider().padding(.horizontal, 14)
            addMenuAction(AppLocalizer.string("workout.add.block"), icon: "square.stack.3d.up.fill") {
                isAddingBlock = false
                isShowingBlockEditor = true
            }
            Divider().padding(.horizontal, 14)
            addMenuAction("Создать с ИИ", icon: "sparkles") {
                isShowingAIGenerator = true
            }
        }
        .frame(width: 248)
        .background(RoundedRectangle(cornerRadius: 24).fill(activeWorkoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(activeWorkoutCardBorder))
        .shadow(color: activeWorkoutCardShadow.opacity(1.8), radius: 16, x: 0, y: 8)
    }

    private func addMenuAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            isShowingAddMenu = false
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func toggleBlock(_ id: String) {
        withAnimation(.snappy(duration: 0.22)) {
            if collapsedBlockIds.contains(id) {
                collapsedBlockIds.remove(id)
            } else {
                collapsedBlockIds.insert(id)
            }
        }
    }

    private func preloadExerciseTemplatesIfNeeded() {
        guard exerciseTemplates.isEmpty else { return }
        exerciseTemplates = workoutTemplates()
    }

    private func stopLegacyTimerIfNeeded() {
        guard workout.isTimerRunning else { return }
        workout.isTimerRunning = false
        try? modelContext.save()
    }

    private func ensureWorkoutBlocksIfNeeded() {
        let unassignedExercises = workout.exerciseItems.filter { $0.block == nil }
        guard unassignedExercises.isEmpty == false else { return }

        let strengthBlock = defaultStrengthBlock()
        var didMutate = false

        for exercise in unassignedExercises {
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

    private func deleteExercise(_ exercise: WorkoutExercise) {
        workout.exerciseItems.removeAll { $0.id == exercise.id }
        exercise.block?.exerciseItems.removeAll { $0.id == exercise.id }
        modelContext.delete(exercise)
        reindexExercises()
        try? modelContext.save()
    }

    private func deleteBlock(_ block: WorkoutBlock) {
        let blockExercises = block.exerciseItems
        for exercise in blockExercises {
            workout.exerciseItems.removeAll { $0.id == exercise.id }
            modelContext.delete(exercise)
        }
        workout.blockItems.removeAll { $0.id == block.id }
        collapsedBlockIds.remove(block.id.uuidString)
        modelContext.delete(block)
        reindexExercises()
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
            note: draft.note,
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

    private func addBlock(_ draft: WorkoutBlockComposerDraft) {
        removeUnusedLegacyDefaultStrengthBlock()
        let block = WorkoutBlock(
            title: draft.resolvedTitle,
            type: draft.type,
            mode: draft.mode,
            preset: draft.preset,
            orderIndex: workout.blockItems.count,
            rounds: draft.rounds,
            durationMinutes: draft.durationMinutes,
            workSeconds: draft.workSeconds,
            restSeconds: draft.restSeconds,
            restBetweenRoundsSeconds: draft.restBetweenRoundsSeconds
        )
        modelContext.insert(block)
        workout.blockItems.append(block)
        try? modelContext.save()
    }

    private func removeUnusedLegacyDefaultStrengthBlock() {
        guard workout.blockItems.count > 0 else { return }
        let legacyTitle = AppLocalizer.string("workout.block.strength.title")
        let removableBlocks = workout.blockItems.filter {
            $0.type == .strength
                && $0.exerciseItems.isEmpty
                && $0.title == legacyTitle
        }
        for block in removableBlocks {
            workout.blockItems.removeAll { $0.id == block.id }
            collapsedBlockIds.remove(block.id.uuidString)
            modelContext.delete(block)
        }
    }

    private func addGeneratedDraft(_ draft: AIWorkoutDraft) {
        let resolvedDraft = draft.resolvingExercises(
            using: exerciseTemplates.isEmpty ? workoutTemplates() : exerciseTemplates
        )
        guard resolvedDraft.blocks.isEmpty == false else { return }

        for block in workout.blockItems where block.exerciseItems.isEmpty {
            workout.blockItems.removeAll { $0.id == block.id }
            modelContext.delete(block)
        }

        var nextBlockIndex = workout.blockItems.count
        var nextExerciseIndex = workout.exerciseItems.count
        for generatedBlock in resolvedDraft.blocks {
            let block = WorkoutBlock(
                title: generatedBlock.title,
                type: generatedBlock.workoutBlockType,
                mode: generatedBlock.workoutBlockMode,
                orderIndex: nextBlockIndex,
                rounds: generatedBlock.rounds,
                durationMinutes: generatedBlock.durationMinutes,
                workSeconds: generatedBlock.workSeconds,
                restSeconds: generatedBlock.restSeconds,
                restBetweenRoundsSeconds: generatedBlock.restBetweenRoundsSeconds
            )
            modelContext.insert(block)
            workout.blockItems.append(block)
            nextBlockIndex += 1

            for generatedExercise in generatedBlock.exercises {
                let exercise = WorkoutExercise(
                    name: generatedExercise.name,
                    systemImage: generatedExercise.systemImage,
                    accentName: generatedExercise.accentName,
                    orderIndex: nextExerciseIndex,
                    note: generatedExercise.note,
                    activityType: generatedExercise.workoutActivityType,
                    metValue: generatedExercise.metValue
                )
                exercise.session = workout
                exercise.block = block

                for (setIndex, generatedSet) in generatedExercise.sets.enumerated() {
                    let set = generatedSet.workoutSet
                    let workoutSet = WorkoutSet(
                        orderIndex: setIndex,
                        weight: set.weight,
                        reps: set.reps,
                        durationSeconds: set.durationSeconds,
                        metricType: set.metricType
                    )
                    workoutSet.exercise = exercise
                    exercise.setItems.append(workoutSet)
                }

                workout.exerciseItems.append(exercise)
                block.exerciseItems.append(exercise)
                nextExerciseIndex += 1
            }
        }
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

    private func blockIconName(for block: WorkoutBlock?) -> String {
        guard let block else {
            return WorkoutBlockPreset.strength.iconName
        }

        return block.preset.iconName
    }

    private func subtitle(for block: WorkoutBlock) -> String {
        workoutBlockSubtitle(
            title: displayTitle(for: block),
            type: block.type,
            mode: block.mode,
            rounds: block.rounds,
            exerciseCount: block.exerciseItems.count,
            durationMinutes: block.durationMinutes,
            workSeconds: block.workSeconds,
            restSeconds: block.restSeconds,
            restBetweenRoundsSeconds: block.restBetweenRoundsSeconds
        )
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

    private func followingExercises(after exercise: WorkoutExercise) -> [WorkoutExercise] {
        if let block = exercise.block, isRunnerBlock(block) {
            return []
        }

        let orderedExercises: [WorkoutExercise]
        if let block = exercise.block {
            orderedExercises = block.exerciseItems.sorted { $0.orderIndex < $1.orderIndex }
        } else {
            orderedExercises = sortedExercises.filter { $0.block == nil }
        }
        guard let currentIndex = orderedExercises.firstIndex(where: { $0.id == exercise.id }) else {
            return []
        }
        let followingIndex = orderedExercises.index(after: currentIndex)
        guard followingIndex < orderedExercises.endIndex else { return [] }
        return Array(orderedExercises[followingIndex...])
    }

    private var hasPendingWorkoutItem: Bool {
        sortedBlockGroups.contains { group in
            if let block = group.block, isRunnerBlock(block) {
                return block.isFinished == false && group.exercises.isEmpty == false
            }
            return group.exercises.contains { $0.isFinished == false }
        }
    }

    private func continueWorkout() {
        for group in sortedBlockGroups {
            if let block = group.block,
               isRunnerBlock(block),
               block.isFinished == false,
               group.exercises.isEmpty == false {
                selectedBlock = block
                return
            }

            if let exercise = group.exercises.first(where: { $0.isFinished == false }) {
                selectedExercise = exercise
                return
            }
        }
    }

    private func isRunnerBlock(_ block: WorkoutBlock) -> Bool {
        block.type == .superset || block.type == .circuit
    }

    private func runnerAction(for block: WorkoutBlock?) -> (() -> Void)? {
        guard let block, isRunnerBlock(block), block.exerciseItems.isEmpty == false else { return nil }
        return {
            selectedBlock = block
        }
    }

    private func reindexExercises() {
        for (index, exercise) in workout.exerciseItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            exercise.orderIndex = index
        }
    }

    private func finishWorkout(effort: WorkoutEffortLevel) {
        workout.isTimerRunning = false
        let baseCalories = WorkoutCalorieEstimator.estimateWorkoutCalories(
            workout: workout,
            userWeightKg: currentUserWeight
        )
        workout.estimatedCalories = effort.adjustedCalories(baseCalories)
        workout.endedAt = Date()
        try? modelContext.save()
        LocalReminderScheduler.rescheduleWorkoutRemindersIfEnabled(
            modelContext: modelContext,
            ownerId: workout.ownerId,
            gender: workout.gender
        )
        syncCompletedAssignmentIfNeeded()
        shouldShowCompletionAfterEffortPicker = true
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

private enum WorkoutEffortLevel: String, CaseIterable, Identifiable {
    case easy
    case moderate
    case hard
    case max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy:
            return AppLocalizer.string("workout.effort.easy")
        case .moderate:
            return AppLocalizer.string("workout.effort.moderate")
        case .hard:
            return AppLocalizer.string("workout.effort.hard")
        case .max:
            return AppLocalizer.string("workout.effort.max")
        }
    }

    var subtitle: String {
        switch self {
        case .easy:
            return AppLocalizer.string("workout.effort.easy.subtitle")
        case .moderate:
            return AppLocalizer.string("workout.effort.moderate.subtitle")
        case .hard:
            return AppLocalizer.string("workout.effort.hard.subtitle")
        case .max:
            return AppLocalizer.string("workout.effort.max.subtitle")
        }
    }

    var multiplier: Double {
        switch self {
        case .easy:
            return 0.85
        case .moderate:
            return 1.0
        case .hard:
            return 1.18
        case .max:
            return 1.35
        }
    }

    var iconName: String {
        switch self {
        case .easy:
            return "leaf.fill"
        case .moderate:
            return "flame.fill"
        case .hard:
            return "bolt.fill"
        case .max:
            return "bolt.heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .easy:
            return .green
        case .moderate:
            return .orange
        case .hard:
            return .red
        case .max:
            return .purple
        }
    }

    func adjustedCalories(_ baseCalories: Int) -> Int {
        Swift.max(0, Int((Double(baseCalories) * multiplier).rounded()))
    }
}

private struct WorkoutEffortPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let baseCalories: Int
    let onSelect: (WorkoutEffortLevel) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.string("workout.effort.title"))
                        .font(.title2.weight(.bold))
                    Text(AppLocalizer.format("workout.effort.base", baseCalories))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(WorkoutEffortLevel.allCases) { effort in
                        Button {
                            onSelect(effort)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(effort.tint.opacity(0.16))

                                    Image(systemName: effort.iconName)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(effort.tint)
                                }
                                .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(effort.title)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(effort.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text(formattedWorkoutCalories(effort.adjustedCalories(baseCalories)))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 20).fill(activeWorkoutCardBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(activeWorkoutCardBorder)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WorkoutBlockSectionHeader: View {
    let title: String
    let subtitle: String
    let iconName: String
    var onStart: (() -> Void)?
    let isCompleted: Bool
    var onAddExercise: (() -> Void)?
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let onStart {
                Button(action: onStart) {
                    blockIdentity
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCompleted ? "Посмотреть результаты блока \(title)" : "Начать блок \(title)")
            } else {
                blockIdentity
            }

            Spacer()

            if isCompleted, let onStart {
                Button(action: onStart) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Посмотреть результаты блока \(title)")
            } else if let onStart {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Начать блок \(title)")
            }

            Button(action: onToggleExpanded) {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Свернуть блок" : "Развернуть блок")

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
        .contextMenu {
            if let onDelete {
                Button("Удалить блок", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    private var blockIdentity: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.14))

                Image(systemName: iconName)
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
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

struct WorkoutBlockComposerDraft {
    var title: String
    var type: WorkoutBlockType
    var mode: WorkoutBlockMode
    var preset: WorkoutBlockPreset
    var rounds: Int
    var durationMinutes: Int
    var workSeconds: Int
    var restSeconds: Int
    var restBetweenRoundsSeconds: Int

    var resolvedTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return type.title
        }
        return trimmedTitle
    }
}

struct WorkoutBlockComposerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (UUID, WorkoutBlockComposerDraft) async -> String?

    @State private var preset: WorkoutBlockPreset = .strength
    @State private var isConfiguring = false
    @State private var title = ""
    @State private var rounds = 3
    @State private var durationMinutes = 12
    @State private var workSeconds = 20
    @State private var restSeconds = 10
    @State private var restBetweenRoundsSeconds = 60
    @State private var submissionID = UUID()
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isConfiguring {
                    configurationView
                } else {
                    presetPicker
                }
            }
            .navigationTitle(isConfiguring ? preset.title : AppLocalizer.string("workout.block.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isConfiguring { isConfiguring = false } else { dismiss() }
                    } label: {
                        if isConfiguring {
                            Image(systemName: "chevron.left")
                        } else {
                            Text(AppLocalizer.string("common.cancel"))
                        }
                    }
                }
            }
        }
    }

    private var presetPicker: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(WorkoutBlockPreset.allCases) { option in
                        Button {
                            preset = option
                        } label: {
                            VStack(spacing: 7) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: option.iconName)
                                        .font(.system(size: 25, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .frame(width: 58, height: 58)
                                        .background(Circle().fill(Color.blue.opacity(0.08)))
                                    if preset == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.blue)
                                            .offset(x: 8, y: -4)
                                    }
                                }
                                Text(option.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 122)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(preset == option ? Color.blue : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 6)
            }

            Button(AppLocalizer.string("workout.block.composer.continue")) {
                applyDefaults(for: preset)
                if hasParameters {
                    isConfiguring = true
                } else {
                    save()
                }
            }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.blue))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var configurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("workout.block.title.placeholder"))
                        .font(.headline)
                    TextField(preset.defaultTitle, text: $title)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: preset.iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.blue.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(preset.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemBackground)))

                if hasParameters {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AppLocalizer.string("workout.block.composer.parameters"))
                            .font(.headline)
                            .padding(.bottom, 8)
                        configurationRows
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemBackground)))
                }

                if let saveErrorMessage {
                    Text(saveErrorMessage).font(.footnote).foregroundStyle(.red)
                }

                Button(action: save) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? AppLocalizer.string("workout.block.composer.saving") : AppLocalizer.string("common.save"))
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.blue))
                }
                .disabled(isSaving)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    @ViewBuilder private var configurationRows: some View {
        switch preset {
        case .warmup, .strength, .mobility, .stretching, .cooldown:
            EmptyView()
        case .pyramid, .ladder:
            numberRow(AppLocalizer.string("workout.block.composer.steps"), value: $rounds, range: 2...20)
        case .dropSet:
            numberRow(AppLocalizer.string("workout.block.composer.weight_drops"), value: $rounds, range: 1...6)
            numberRow(AppLocalizer.string("workout.block.composer.rest_after_series"), value: $restBetweenRoundsSeconds, range: 0...300, step: 5, suffix: AppLocalizer.string("workout.block.composer.seconds_suffix"))
        case .clusterSet:
            numberRow(AppLocalizer.string("workout.block.composer.clusters"), value: $rounds, range: 2...10)
            numberRow(AppLocalizer.string("workout.block.composer.mini_rest"), value: $restBetweenRoundsSeconds, range: 5...60, step: 5, suffix: AppLocalizer.string("workout.block.composer.seconds_suffix"))
        case .superset, .circuit, .rft:
            numberRow(AppLocalizer.string("workout.block.composer.rounds"), value: $rounds, range: 1...20)
            numberRow(AppLocalizer.string("workout.block.composer.rest"), value: $restBetweenRoundsSeconds, range: 0...600, step: 5, suffix: AppLocalizer.string("workout.block.composer.seconds_suffix"))
        case .hiit, .tabata:
            numberRow(AppLocalizer.string("workout.block.composer.intervals"), value: $rounds, range: 1...40)
            numberRow(AppLocalizer.string("workout.block.composer.work"), value: $workSeconds, range: 5...120, step: 5, suffix: AppLocalizer.string("workout.block.composer.seconds_suffix"))
            numberRow(AppLocalizer.string("workout.block.composer.rest"), value: $restSeconds, range: 0...120, step: 5, suffix: AppLocalizer.string("workout.block.composer.seconds_suffix"))
        case .amrap, .emom, .e2mom, .e3mom, .forTime:
            numberRow(AppLocalizer.string("workout.block.composer.duration"), value: $durationMinutes, range: 1...90, suffix: AppLocalizer.string("workout.block.composer.minutes_suffix"))
        }
    }

    private func numberRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, suffix: String = "") -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value.wrappedValue)\(suffix)").foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .padding(.vertical, 7)
    }

    private func applyDefaults(for preset: WorkoutBlockPreset) {
        title = preset.defaultTitle
        rounds = preset.defaultRounds
        durationMinutes = preset.defaultDurationMinutes
        workSeconds = preset.defaultWorkSeconds
        restSeconds = preset.defaultRestSeconds
        restBetweenRoundsSeconds = preset.defaultRestBetweenRoundsSeconds
    }

    private var hasParameters: Bool {
        switch preset {
        case .superset, .circuit, .hiit, .tabata, .amrap, .emom, .e2mom, .e3mom, .forTime, .rft, .pyramid, .dropSet, .clusterSet, .ladder:
            true
        case .warmup, .strength, .mobility, .stretching, .cooldown:
            false
        }
    }

    private func save() {
        guard isSaving == false else { return }
        isSaving = true
        saveErrorMessage = nil
        let draft = WorkoutBlockComposerDraft(
            title: title,
            type: preset.blockType,
            mode: preset.mode,
            preset: preset,
            rounds: preset == .strength || preset == .warmup || preset == .mobility || preset == .stretching || preset == .cooldown || preset == .forTime ? 1 : rounds,
            durationMinutes: preset.mode == .amrap || preset.mode == .emom || preset == .forTime || preset == .hiit ? durationMinutes : 0,
            workSeconds: preset.mode == .tabata || preset == .hiit ? workSeconds : 0,
            restSeconds: preset.mode == .tabata || preset == .hiit ? restSeconds : 0,
            restBetweenRoundsSeconds: preset.mode == .rounds ? restBetweenRoundsSeconds : 0
        )
        Task {
            if let message = await onSave(submissionID, draft) {
                saveErrorMessage = message
            } else {
                dismiss()
            }
            isSaving = false
        }
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
