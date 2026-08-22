import SwiftUI
import SwiftData

private let workoutCardBackground = Color(.secondarySystemBackground)
private let workoutCardInsetBackground = Color(.tertiarySystemBackground)
private let workoutCardBorder = Color(.separator).opacity(0.40)

struct WorkoutExerciseCard: View {
    let exercise: WorkoutExercise

    private var groups: [WorkoutSetGroupDescriptor] {
        workoutSetGroups(for: exercise)
    }

    private var completedCount: Int {
        groups.filter(\.isCompleted).count
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(workoutAccentColor(exercise.accentName).opacity(0.16))

                workoutIconImage(
                    named: exercise.systemImage,
                    accentName: exercise.accentName,
                    size: 18,
                    customAssetScale: 2.5
                )
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(AppLocalizer.format("workout.exercise.summary", groups.count, completedCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(workoutCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(workoutCardBorder)
        )
    }
}

struct WorkoutSetRow: View {
    let set: WorkoutSet
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Text(AppLocalizer.format("workout.set.number", set.orderIndex + 1))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)

                Text(
                    formattedWorkoutSetValue(
                        weight: set.weight,
                        reps: set.reps,
                        durationSeconds: set.durationSeconds,
                        metricType: set.metricType
                    )
                )
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

private enum WorkoutExerciseDetailTab: String, CaseIterable, Identifiable {
    case workout
    case records
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: return "Тренировка"
        case .records: return "Рекорды"
        case .notes: return "Заметки"
        }
    }
}

private struct WorkoutExerciseHistoryEntry: Identifiable {
    let exerciseID: UUID
    let sessionID: UUID
    let date: Date
    let completedSetCount: Int
    let estimatedOneRepMax: Double?
    let maxWeight: Double?
    let maxReps: Int?
    let volume: Double?
    let userNote: String

    var id: String { "\(sessionID.uuidString)-\(exerciseID.uuidString)" }
}

private struct WorkoutExercisePersonalBests {
    let estimatedOneRepMax: Double?
    let maxWeight: Double?
    let maxReps: Int?
    let maxVolume: Double?

    init(history: [WorkoutExerciseHistoryEntry]) {
        estimatedOneRepMax = history.compactMap(\.estimatedOneRepMax).max()
        maxWeight = history.compactMap(\.maxWeight).max()
        maxReps = history.compactMap(\.maxReps).max()
        maxVolume = history.compactMap(\.volume).max()
    }
}

private func workoutExerciseHistory(
    matching exercise: WorkoutExercise,
    in sessions: [WorkoutSession],
    ownerId: String?
) -> [WorkoutExerciseHistoryEntry] {
    let normalizedName = normalizedWorkoutExerciseName(exercise.name)

    return sessions
        .filter { session in
            guard let ownerId, ownerId.isEmpty == false else { return true }
            return session.ownerId == ownerId
        }
        .flatMap { session in
            session.exerciseItems.compactMap { historicalExercise in
                guard normalizedWorkoutExerciseName(historicalExercise.name) == normalizedName else {
                    return nil
                }

                let completedSets = historicalExercise.setItems.filter(\.isCompleted)
                let repetitionSets = completedSets.filter {
                    $0.metricType == .reps && resolvedWorkoutSetReps($0) > 0
                }
                let maxWeight = repetitionSets
                    .map(resolvedWorkoutSetWeight)
                    .filter { $0 > 0 }
                    .max()
                let maxReps = repetitionSets
                    .map(resolvedWorkoutSetReps)
                    .max()
                let oneRepMax = repetitionSets
                    .map { set -> Double in
                        let weight = resolvedWorkoutSetWeight(set)
                        let reps = Double(resolvedWorkoutSetReps(set))
                        return weight > 0 ? weight * (1 + reps / 30) : 0
                    }
                    .filter { $0 > 0 }
                    .max()
                let volume = repetitionSets.reduce(0.0) { partial, set in
                    partial + resolvedWorkoutSetWeight(set) * Double(resolvedWorkoutSetReps(set))
                }

                guard completedSets.isEmpty == false || historicalExercise.userNote.isEmpty == false else {
                    return nil
                }

                return WorkoutExerciseHistoryEntry(
                    exerciseID: historicalExercise.id,
                    sessionID: session.id,
                    date: session.endedAt ?? session.createdAt,
                    completedSetCount: completedSets.count,
                    estimatedOneRepMax: oneRepMax,
                    maxWeight: maxWeight,
                    maxReps: maxReps,
                    volume: volume > 0 ? volume : nil,
                    userNote: historicalExercise.userNote
                )
            }
        }
        .sorted { $0.date > $1.date }
}

private func normalizedWorkoutExerciseName(_ name: String) -> String {
    name
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

private func resolvedWorkoutSetWeight(_ set: WorkoutSet) -> Double {
    set.actualWeight ?? set.weight
}

private func resolvedWorkoutSetReps(_ set: WorkoutSet) -> Int {
    set.actualReps ?? set.reps
}

struct WorkoutExerciseFlowScreen: View {
    @State private var currentExercise: WorkoutExercise
    @State private var contentOpacity = 1.0
    @State private var showsCompletionFeedback = false
    @State private var isTransitioning = false

    let exerciseSequence: [WorkoutExercise]
    let onDeleteExercise: (WorkoutExercise) -> Void
    let onContinueWorkout: () -> Void

    init(
        initialExercise: WorkoutExercise,
        exerciseSequence: [WorkoutExercise],
        onDeleteExercise: @escaping (WorkoutExercise) -> Void,
        onContinueWorkout: @escaping () -> Void
    ) {
        _currentExercise = State(initialValue: initialExercise)
        self.exerciseSequence = exerciseSequence
        self.onDeleteExercise = onDeleteExercise
        self.onContinueWorkout = onContinueWorkout
    }

    private var followingExercises: [WorkoutExercise] {
        guard let currentIndex = exerciseSequence.firstIndex(where: { $0.id == currentExercise.id }) else {
            return []
        }

        return Array(exerciseSequence.dropFirst(currentIndex + 1))
    }

    var body: some View {
        WorkoutExerciseDetailScreen(
            exercise: currentExercise,
            followingExercises: followingExercises,
            onOpenExercise: transitionToExercise,
            onDeleteExercise: {
                onDeleteExercise(currentExercise)
            },
            onContinueWorkout: onContinueWorkout
        )
        .id(currentExercise.id)
        .opacity(contentOpacity)
        .overlay {
            completionFeedback
        }
        .allowsHitTesting(!isTransitioning)
    }

    @ViewBuilder
    private var completionFeedback: some View {
        if showsCompletionFeedback {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Color.green, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    private func transitionToExercise(_ nextExercise: WorkoutExercise) {
        guard nextExercise.id != currentExercise.id, !isTransitioning else { return }

        isTransitioning = true
        withAnimation(.easeOut(duration: 0.12)) {
            contentOpacity = 0
            showsCompletionFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            currentExercise = nextExercise

            withAnimation(.easeInOut(duration: 0.22)) {
                contentOpacity = 1
                showsCompletionFeedback = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                isTransitioning = false
            }
        }
    }
}

struct WorkoutExerciseDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.createdAt, order: .reverse) private var workoutHistory: [WorkoutSession]

    @Bindable var exercise: WorkoutExercise
    let followingExercises: [WorkoutExercise]
    let onOpenExercise: (WorkoutExercise) -> Void
    let onDeleteExercise: (() -> Void)?
    let onContinueWorkout: (() -> Void)?

    @State private var editingSet: WorkoutSet?
    @State private var editingSetGroup: WorkoutSetGroupDescriptor?
    @State private var activeSetGroup: WorkoutSetGroupDescriptor?
    @State private var pendingRestartSetGroup: WorkoutSetGroupDescriptor?
    @State private var showSetMethodPicker = false
    @FocusState private var isPersonalNoteFocused: Bool
    @State private var showIncompleteSetsConfirmation = false
    @State private var showNextExerciseIncompleteConfirmation = false
    @State private var showDeleteExerciseConfirmation = false
    @State private var selectedDetailTab = WorkoutExerciseDetailTab.workout
    @State private var isClosingScreen = false

    init(
        exercise: WorkoutExercise,
        followingExercises: [WorkoutExercise],
        onOpenExercise: @escaping (WorkoutExercise) -> Void,
        onDeleteExercise: (() -> Void)? = nil,
        onContinueWorkout: (() -> Void)? = nil
    ) {
        self.exercise = exercise
        self.followingExercises = followingExercises
        self.onOpenExercise = onOpenExercise
        self.onDeleteExercise = onDeleteExercise
        self.onContinueWorkout = onContinueWorkout
    }

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        setGroups.filter(\.isCompleted).count
    }

    private var areAllSetsComplete: Bool {
        setGroups.isEmpty == false && completedCount == setGroups.count
    }

    private var incompleteSetCount: Int {
        max(setGroups.count - completedCount, 0)
    }

    private var setGroups: [WorkoutSetGroupDescriptor] {
        workoutSetGroups(for: exercise)
    }

    private var coachComment: String {
        exercise.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentSet: WorkoutSet? {
        sortedSets.first(where: { $0.isCompleted == false }) ?? sortedSets.last
    }

    private var currentMetricTitle: String {
        currentSet?.metricType == .duration ? "Время" : "Повторений"
    }

    private var currentMetricValue: String {
        guard let currentSet else { return "—" }
        return formattedWorkoutMetricValue(
            reps: currentSet.reps,
            durationSeconds: currentSet.durationSeconds,
            metricType: currentSet.metricType
        )
    }

    private var exerciseHistory: [WorkoutExerciseHistoryEntry] {
        workoutExerciseHistory(
            matching: exercise,
            in: workoutHistory,
            ownerId: exercise.session?.ownerId
        )
    }

    private var personalBests: WorkoutExercisePersonalBests {
        WorkoutExercisePersonalBests(history: exerciseHistory)
    }

    private var previousNotes: [WorkoutExerciseHistoryEntry] {
        exerciseHistory.filter {
            $0.exerciseID != exercise.id &&
            $0.userNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                detailTabs

                switch selectedDetailTab {
                case .workout:
                    exerciseOverview
                    setCards
                    trainerCommentCard
                case .records:
                    personalBestsContent
                case .notes:
                    notesContent
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 118)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(item: $activeSetGroup) { group in
            WorkoutSetMethodRunnerScreen(exercise: exercise, groupID: group.id)
        }
        .safeAreaInset(edge: .bottom) {
            if selectedDetailTab == .workout && isPersonalNoteFocused == false {
                completionAction
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPersonalNoteFocused)
        .onDisappear {
            dismissPersonalNoteKeyboard()
            persistPersonalNote()
        }
        .confirmationDialog(
            "Остались невыполненные подходы",
            isPresented: $showIncompleteSetsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Завершить с пропущенными подходами") {
                finishExercise()
            }
            Button("Продолжить тренировку", role: .cancel) {}
        } message: {
            Text("Невыполненные подходы останутся без отметки.")
        }
        .confirmationDialog(
            "Не все подходы выполнены",
            isPresented: $showNextExerciseIncompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Перейти с пропущенными подходами") {
                openNextExercise()
            }
            Button("Остаться", role: .cancel) {}
        } message: {
            Text("Не выполнено \(incompleteSetCount) из \(setGroups.count) подходов.")
        }
        .onChange(of: isPersonalNoteFocused) { _, isFocused in
            if isFocused == false {
                persistPersonalNote()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeExerciseScreen) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                }
                .disabled(isClosingScreen)
                .accessibilityLabel("Назад к списку упражнений")
            }

            if onDeleteExercise != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Удалить упражнение", systemImage: "trash", role: .destructive) {
                            showDeleteExerciseConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Действия с упражнением")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    dismissPersonalNoteKeyboard()
                }
            }
        }
        .confirmationDialog(
            "Удалить упражнение?",
            isPresented: $showDeleteExerciseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить упражнение", role: .destructive) {
                persistPersonalNote()
                dismiss()
                DispatchQueue.main.async {
                    onDeleteExercise?()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("«\(exercise.name)» и все его подходы будут удалены из этой тренировки.")
        }
        .confirmationDialog(
            "Начать метод заново?",
            isPresented: Binding(
                get: { pendingRestartSetGroup != nil },
                set: { if $0 == false { pendingRestartSetGroup = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Начать заново", role: .destructive) {
                if let group = pendingRestartSetGroup {
                    restartSetGroup(group)
                }
                pendingRestartSetGroup = nil
            }
            Button("Отмена", role: .cancel) {
                pendingRestartSetGroup = nil
            }
        } message: {
            if let group = pendingRestartSetGroup {
                Text("Сохранённые результаты «\(group.method.title)» будут сброшены.")
            }
        }
        .sheet(item: $editingSet) { set in
            WorkoutExerciseSetEditorSheet(
                set: set,
                onSave: { weight, reps, durationSeconds, metricType, isCompleted in
                    set.weight = weight
                    set.reps = reps
                    set.durationSeconds = durationSeconds
                    set.metricType = metricType
                    set.isCompleted = isCompleted
                    try? modelContext.save()
                },
                onDelete: {
                    deleteSet(set)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingSetGroup) { group in
            WorkoutSetGroupEditorSheet(
                group: group,
                onSave: { drafts, pyramidPattern in
                    saveSetGroup(group, drafts: drafts, pyramidPattern: pyramidPattern)
                },
                onDelete: {
                    deleteSetGroup(group)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Добавить подход",
            isPresented: $showSetMethodPicker,
            titleVisibility: .visible
        ) {
            Button("Обычный подход") { addNormalSet() }
            Button("Дроп-сет") { addCompositeSet(method: .dropSet) }
            Button("Пирамида") { addCompositeSet(method: .pyramid) }
            Button("Кластер") { addCompositeSet(method: .cluster) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выберите способ выполнения нового подхода.")
        }
    }

    private var detailTabs: some View {
        HStack(spacing: 0) {
            ForEach(WorkoutExerciseDetailTab.allCases) { tab in
                Button {
                    isPersonalNoteFocused = false
                    persistPersonalNote()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDetailTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedDetailTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedDetailTab == tab ? Color.blue : Color.secondary)
                            .frame(maxWidth: .infinity)

                        Capsule()
                            .fill(selectedDetailTab == tab ? Color.blue : Color.clear)
                            .frame(height: 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedDetailTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
    }

    private var personalBestsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Личные рекорды")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("По выполненным подходам")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                WorkoutPersonalBestCard(
                    title: "Расчётный 1ПМ",
                    value: personalBests.estimatedOneRepMax.map { "\(formattedWorkoutWeight($0)) кг" } ?? "—",
                    icon: "chart.line.uptrend.xyaxis"
                )
                WorkoutPersonalBestCard(
                    title: "Максимальный вес",
                    value: personalBests.maxWeight.map { "\(formattedWorkoutWeight($0)) кг" } ?? "—",
                    icon: "dumbbell.fill"
                )
                WorkoutPersonalBestCard(
                    title: "Максимум повторений",
                    value: personalBests.maxReps.map(String.init) ?? "—",
                    icon: "target"
                )
                WorkoutPersonalBestCard(
                    title: "Максимальный объём",
                    value: personalBests.maxVolume.map { "\(formattedWorkoutWeight($0)) кг" } ?? "—",
                    icon: "square.stack.3d.up.fill"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("История")
                    .font(.title3.weight(.bold))

                if exerciseHistory.isEmpty {
                    WorkoutExerciseEmptyHistoryCard()
                } else {
                    ForEach(exerciseHistory.prefix(10)) { entry in
                        WorkoutExerciseHistoryRow(entry: entry)
                    }
                }
            }
        }
    }

    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            personalNoteCard

            if previousNotes.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Прошлые заметки")
                        .font(.title3.weight(.bold))

                    ForEach(previousNotes.prefix(6)) { entry in
                        WorkoutExercisePreviousNoteCard(entry: entry)
                    }
                }
            }
        }
    }

    private var exerciseOverview: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(workoutAccentColor(exercise.accentName).opacity(0.13))
                    Circle()
                        .strokeBorder(workoutAccentColor(exercise.accentName).opacity(0.7), lineWidth: 1.5)
                    workoutIconImage(
                        named: exercise.systemImage,
                        accentName: exercise.accentName,
                        size: 42,
                        customAssetScale: 2.35
                    )
                }
                .frame(width: 132, height: 132)

                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 154)
            }

            VStack(spacing: 10) {
                WorkoutExerciseMetricCard(
                    title: "Подходы",
                    value: "\(completedCount) из \(setGroups.count)",
                    icon: "square.stack.3d.up.fill"
                )
                WorkoutExerciseMetricCard(
                    title: currentMetricTitle,
                    value: currentMetricValue,
                    icon: "target"
                )
                WorkoutExerciseMetricCard(
                    title: "Вес",
                    value: currentSet.map { "\(formattedWorkoutWeight($0.weight)) кг" } ?? "—",
                    icon: "dumbbell.fill"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }

    private var setCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Подходы")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("Нажмите, чтобы изменить")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(setGroups.enumerated()), id: \.element.id) { index, group in
                        if group.method == .normal, let set = group.steps.first {
                            WorkoutSetHorizontalCard(
                                number: index + 1,
                                set: set,
                                onEdit: { editingSet = set },
                                onToggleCompletion: { toggleSetCompletion(set) }
                            )
                        } else {
                            WorkoutCompositeSetCard(
                                number: index + 1,
                                group: group,
                                onOpen: { activeSetGroup = group },
                                onStatusAction: {
                                    if group.isCompleted {
                                        pendingRestartSetGroup = group
                                    } else {
                                        activeSetGroup = group
                                    }
                                },
                                onEdit: { editingSetGroup = group }
                            )
                        }
                    }

                    WorkoutAddSetCard(action: { showSetMethodPicker = true })
                }
            }
        }
    }

    private var trainerCommentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Комментарий тренера", systemImage: "text.bubble.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(coachComment.isEmpty ? "Тренер пока не добавил комментарий к этому упражнению." : coachComment)
                .font(.subheadline)
                .foregroundStyle(coachComment.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(workoutCardBorder))
    }

    private var personalNoteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Моя заметка", systemImage: "square.and.pencil")
                .font(.headline.weight(.semibold))

            TextEditor(text: $exercise.userNote)
                .font(.body)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(workoutCardInsetBackground, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Личная заметка к упражнению")
                .focused($isPersonalNoteFocused)

            Text("Заметка сохранится автоматически.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(workoutCardBorder))
    }

    @ViewBuilder
    private var completionAction: some View {
        if exercise.isFinished, let nextExercise = followingExercises.first {
            Button {
                if incompleteSetCount > 0 {
                    showNextExerciseIncompleteConfirmation = true
                } else {
                    onOpenExercise(nextExercise)
                }
            } label: {
                Label("Следующее упражнение", systemImage: "arrow.right.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
            }
            .buttonStyle(.plain)
        } else if exercise.isFinished {
            Button(action: continueAfterCurrentExercise) {
                Label(
                    onContinueWorkout == nil ? "Упражнение завершено" : "Продолжить тренировку",
                    systemImage: onContinueWorkout == nil ? "checkmark.circle.fill" : "play.circle.fill"
                )
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
            }
            .buttonStyle(.plain)
        } else {
                    Button(action: completeExercise) {
                Label("Завершить упражнение", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
            }
            .buttonStyle(.plain)
            .disabled(sortedSets.isEmpty)
            .opacity(sortedSets.isEmpty ? 0.55 : 1)
        }
    }

    private func completeExercise() {
        if areAllSetsComplete {
            finishExercise()
        } else {
            showIncompleteSetsConfirmation = true
        }
    }

    private func finishExercise() {
        isPersonalNoteFocused = false
        exercise.isFinished = true
        persistPersonalNote()
        try? modelContext.save()

        if followingExercises.isEmpty {
            continueAfterCurrentExercise()
        } else {
            onOpenExercise(followingExercises[0])
        }
    }

    private func continueAfterCurrentExercise() {
        guard let onContinueWorkout else {
            dismiss()
            return
        }
        onContinueWorkout()
    }

    private func openNextExercise() {
        guard let nextExercise = followingExercises.first else { return }
        isPersonalNoteFocused = false
        persistPersonalNote()
        onOpenExercise(nextExercise)
    }

    private func addNormalSet() {
        let lastSet = sortedSets.last
        let set = WorkoutSet(
            orderIndex: sortedSets.count,
            weight: lastSet?.weight ?? 20,
            reps: lastSet?.reps ?? 10,
            durationSeconds: lastSet?.durationSeconds ?? 30,
            metricType: lastSet?.metricType ?? .reps
        )
        set.exercise = exercise
        exercise.setItems.append(set)
        try? modelContext.save()
        editingSet = set
    }

    private func addCompositeSet(method: WorkoutSetMethod) {
        let lastSet = sortedSets.last
        let baseWeight = max(lastSet?.weight ?? 20, 0)
        let baseReps = max(lastSet?.reps ?? 10, 1)
        let groupID = UUID()
        let presets: [(Double, Int, Int)]

        switch method {
        case .dropSet:
            presets = [
                (baseWeight, baseReps, 0),
                (baseWeight * 0.80, baseReps, 0),
                (baseWeight * 0.65, baseReps + 2, 0)
            ]
        case .pyramid:
            presets = [
                (baseWeight * 0.75, 12, 90),
                (baseWeight * 0.85, 10, 90),
                (baseWeight * 0.95, 8, 90),
                (baseWeight, 6, 0)
            ]
        case .cluster:
            let clusterReps = max(baseReps / 3, 2)
            presets = [
                (baseWeight, clusterReps, 20),
                (baseWeight, clusterReps, 20),
                (baseWeight, clusterReps, 20),
                (baseWeight, clusterReps, 0)
            ]
        case .normal:
            addNormalSet()
            return
        }

        let startingIndex = sortedSets.count
        for (stepIndex, preset) in presets.enumerated() {
            let set = WorkoutSet(
                orderIndex: startingIndex + stepIndex,
                weight: preset.0,
                reps: preset.1,
                metricType: .reps,
                method: method,
                pyramidPattern: .ascending,
                groupID: groupID,
                stepIndex: stepIndex,
                restAfterSeconds: preset.2
            )
            set.exercise = exercise
            exercise.setItems.append(set)
        }
        try? modelContext.save()

        if let group = workoutSetGroups(for: exercise).first(where: { $0.id == groupID }) {
            editingSetGroup = group
        }
    }

    private func deleteSet(_ set: WorkoutSet) {
        exercise.setItems.removeAll { $0.id == set.id }
        modelContext.delete(set)
        for (index, item) in exercise.setItems
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .enumerated() {
            item.orderIndex = index
        }
        try? modelContext.save()
    }

    private func saveSetGroup(
        _ group: WorkoutSetGroupDescriptor,
        drafts: [WorkoutSetStepDraft],
        pyramidPattern: WorkoutPyramidPattern
    ) {
        let groupOrder = setGroups.map(\.id)
        let existingByID = Dictionary(uniqueKeysWithValues: group.steps.map { ($0.id, $0) })
        let draftIDs = Set(drafts.map(\.id))

        for set in group.steps where draftIDs.contains(set.id) == false {
            exercise.setItems.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }

        for (stepIndex, draft) in drafts.enumerated() {
            let set: WorkoutSet
            if let existing = existingByID[draft.id] {
                set = existing
            } else {
                set = WorkoutSet(
                    orderIndex: group.orderIndex + stepIndex,
                    weight: draft.weight,
                    reps: draft.reps,
                    durationSeconds: draft.durationSeconds,
                    metricType: draft.metricType,
                    method: group.method,
                    pyramidPattern: pyramidPattern,
                    groupID: group.id,
                    stepIndex: stepIndex,
                    restAfterSeconds: draft.restAfterSeconds
                )
                set.id = draft.id
                set.exercise = exercise
                exercise.setItems.append(set)
            }

            set.weight = max(draft.weight, 0)
            set.reps = max(draft.reps, 0)
            set.durationSeconds = max(draft.durationSeconds, 0)
            set.metricType = draft.metricType
            set.method = group.method
            if group.method == .pyramid {
                set.pyramidPattern = pyramidPattern
            }
            set.groupID = group.id
            set.stepIndex = stepIndex
            set.restAfterSeconds = max(draft.restAfterSeconds, 0)
            set.isCompleted = draft.isCompleted
        }

        reindexSetGroups(in: groupOrder)
        try? modelContext.save()
    }

    private func deleteSetGroup(_ group: WorkoutSetGroupDescriptor) {
        for set in group.steps {
            exercise.setItems.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }
        reindexSetGroups(in: setGroups.filter { $0.id != group.id }.map(\.id))
        try? modelContext.save()
    }

    private func reindexSetGroups(in groupOrder: [UUID]) {
        let currentGroups = Dictionary(uniqueKeysWithValues: workoutSetGroups(for: exercise).map { ($0.id, $0) })
        var flatIndex = 0
        for groupID in groupOrder {
            guard let group = currentGroups[groupID] else { continue }
            for (stepIndex, set) in group.steps.enumerated() {
                set.orderIndex = flatIndex
                set.stepIndex = stepIndex
                flatIndex += 1
            }
        }
    }

    private func toggleSetCompletion(_ set: WorkoutSet) {
        set.isCompleted.toggle()
        if set.isCompleted == false {
            exercise.isFinished = false
        }
        set.completedAt = set.isCompleted ? Date() : nil
        if set.isCompleted {
            set.actualWeight = set.actualWeight ?? set.weight
            set.actualReps = set.actualReps ?? set.reps
            set.actualDurationSeconds = set.actualDurationSeconds ?? set.durationSeconds
        }
        try? modelContext.save()
    }

    private func restartSetGroup(_ group: WorkoutSetGroupDescriptor) {
        exercise.isFinished = false
        for set in group.steps {
            set.isCompleted = false
            set.actualWeight = nil
            set.actualReps = nil
            set.actualDurationSeconds = nil
            set.completedAt = nil
        }
        try? modelContext.save()

        let refreshedGroup = workoutSetGroups(for: exercise).first { $0.id == group.id } ?? group
        activeSetGroup = refreshedGroup
    }

    private func persistPersonalNote() {
        let trimmedNote = exercise.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard exercise.userNote != trimmedNote else { return }
        exercise.userNote = trimmedNote
        try? modelContext.save()
    }

    private func dismissPersonalNoteKeyboard() {
        isPersonalNoteFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func closeExerciseScreen() {
        guard isClosingScreen == false else { return }
        isClosingScreen = true
        dismissPersonalNoteKeyboard()
        persistPersonalNote()

        // Give UIKit one layout pass to remove the keyboard safe-area before
        // the parent screen restores its pinned bottom action panel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            dismiss()
        }
    }
}

private struct WorkoutSetHorizontalCard: View {
    let number: Int
    let set: WorkoutSet
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: onEdit) {
                setDetails
            }
            .buttonStyle(.plain)

            Button(action: onToggleCompletion) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Отметить подход невыполненным" : "Отметить подход выполненным")
        }
        .padding(9)
        .frame(width: 116, height: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(workoutCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(set.isCompleted ? Color.green.opacity(0.55) : workoutCardBorder)
        )
    }

    private var setDetails: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text("Подход \(number)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(formattedWorkoutSetValue(
                    weight: set.weight,
                    reps: set.reps,
                    durationSeconds: set.durationSeconds,
                    metricType: set.metricType
                ))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
    }
}

private struct WorkoutExerciseMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(workoutCardBorder))
    }
}

private struct WorkoutPersonalBestCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(workoutCardBorder))
    }
}

private struct WorkoutExerciseHistoryRow: View {
    let entry: WorkoutExerciseHistoryEntry

    private var summary: String {
        var parts = ["\(entry.completedSetCount) подх."]
        if let maxWeight = entry.maxWeight {
            parts.append("макс. \(formattedWorkoutWeight(maxWeight)) кг")
        }
        if let volume = entry.volume {
            parts.append("объём \(formattedWorkoutWeight(volume)) кг")
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            if let oneRepMax = entry.estimatedOneRepMax {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("1ПМ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formattedWorkoutWeight(oneRepMax)) кг")
                        .font(.subheadline.weight(.bold))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(workoutCardBorder))
    }
}

private struct WorkoutExerciseEmptyHistoryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Рекордов пока нет")
                    .font(.subheadline.weight(.semibold))
                Text("Отметьте хотя бы один подход выполненным.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(workoutCardBorder))
    }
}

private struct WorkoutExercisePreviousNoteCard: View {
    let entry: WorkoutExerciseHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(entry.userNote)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(workoutCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(workoutCardBorder))
    }
}

private struct WorkoutAddSetCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                Text("Добавить\nподход")
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.blue)
            .frame(width: 72, height: 72)
            .background(workoutCardInsetBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.blue.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutExerciseSetEditorSheet: View {
    private enum InputField: Hashable {
        case weight
        case reps
        case duration
    }

    @Environment(\.dismiss) private var dismiss

    let set: WorkoutSet
    let onSave: (Double, Int, Int, WorkoutSetMetricType, Bool) -> Void
    let onDelete: () -> Void

    @State private var weight: Double
    @State private var reps: Int
    @State private var durationSeconds: Int
    @State private var metricType: WorkoutSetMetricType
    @State private var isCompleted: Bool
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: InputField?

    init(
        set: WorkoutSet,
        onSave: @escaping (Double, Int, Int, WorkoutSetMetricType, Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.set = set
        self.onSave = onSave
        self.onDelete = onDelete
        _weight = State(initialValue: set.weight)
        _reps = State(initialValue: set.reps)
        _durationSeconds = State(initialValue: set.durationSeconds)
        _metricType = State(initialValue: set.metricType)
        _isCompleted = State(initialValue: set.isCompleted)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 9)

            HStack {
                Button("Отмена") { dismiss() }
                    .font(.body.weight(.medium))

                Spacer()

                Text("Редактировать подход")
                    .font(.headline.weight(.bold))

                Spacer()

                Button("Сохранить", action: save)
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Подход \(set.orderIndex + 1)")
                        .font(.title3.weight(.semibold))

                    VStack(spacing: 0) {
                        HStack {
                            Text("Тип")
                                .font(.body.weight(.semibold))
                            Spacer()
                            Picker("Тип", selection: $metricType) {
                                Text("Повторения").tag(WorkoutSetMetricType.reps)
                                Text("Время").tag(WorkoutSetMetricType.duration)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                        }
                        .padding(16)

                        Divider().padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Вес")
                                .font(.body.weight(.medium))
                            Spacer()
                            TextField("0", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.headline.weight(.semibold))
                                .frame(width: 110)
                                .focused($focusedField, equals: .weight)
                            Text("кг")
                                .font(.body.weight(.semibold))
                        }
                        .padding(16)

                        Divider().padding(.horizontal, 16)

                        if metricType == .reps {
                            HStack(spacing: 12) {
                                Image(systemName: "target")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                Text("Повторения")
                                    .font(.body.weight(.medium))
                                Spacer()
                                TextField("0", value: $reps, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 100)
                                    .focused($focusedField, equals: .reps)
                            }
                            .padding(16)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "timer")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                Text("Время")
                                    .font(.body.weight(.medium))
                                Spacer()
                                TextField("0", value: $durationSeconds, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.headline.weight(.semibold))
                                    .frame(width: 100)
                                    .focused($focusedField, equals: .duration)
                                Text("сек")
                                    .font(.body.weight(.semibold))
                            }
                            .padding(16)
                        }

                        Divider().padding(.horizontal, 16)

                        Toggle("Подход выполнен", isOn: $isCompleted)
                            .font(.body.weight(.medium))
                            .padding(16)
                    }
                    .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemBackground)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color(.separator).opacity(0.32))
                    )

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить подход", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    focusedField = nil
                }
            }
        }
        .confirmationDialog(
            "Удалить подход?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вес и повторения этого подхода будут удалены.")
        }
    }

    private func save() {
        focusedField = nil
        onSave(
            max(0, weight),
            max(0, reps),
            max(0, durationSeconds),
            metricType,
            isCompleted
        )
        dismiss()
    }
}

func workoutAccentColor(_ name: String) -> Color {
    switch name {
    case "blue": return Color(red: 0.39, green: 0.63, blue: 0.94)
    case "sky": return Color(red: 0.31, green: 0.72, blue: 0.96)
    case "cyan": return Color(red: 0.18, green: 0.76, blue: 0.86)
    case "teal": return Color(red: 0.20, green: 0.67, blue: 0.66)
    case "green": return Color(red: 0.38, green: 0.72, blue: 0.52)
    case "mint": return Color(red: 0.36, green: 0.78, blue: 0.65)
    case "lime": return Color(red: 0.60, green: 0.78, blue: 0.30)
    case "yellow": return Color(red: 0.93, green: 0.77, blue: 0.24)
    case "gold": return Color(red: 0.88, green: 0.64, blue: 0.20)
    case "orange": return Color(red: 0.92, green: 0.62, blue: 0.34)
    case "coral": return Color(red: 0.92, green: 0.45, blue: 0.32)
    case "red": return Color(red: 0.86, green: 0.30, blue: 0.30)
    case "crimson": return Color(red: 0.74, green: 0.20, blue: 0.31)
    case "pink": return Color(red: 0.91, green: 0.45, blue: 0.64)
    case "rose": return Color(red: 0.86, green: 0.35, blue: 0.49)
    case "magenta": return Color(red: 0.78, green: 0.35, blue: 0.78)
    case "violet": return Color(red: 0.60, green: 0.43, blue: 0.90)
    case "purple": return Color(red: 0.57, green: 0.56, blue: 0.85)
    case "indigo": return Color(red: 0.38, green: 0.43, blue: 0.82)
    case "navy": return Color(red: 0.22, green: 0.36, blue: 0.68)
    case "aqua": return Color(red: 0.28, green: 0.70, blue: 0.78)
    case "emerald": return Color(red: 0.24, green: 0.62, blue: 0.43)
    case "olive": return Color(red: 0.48, green: 0.58, blue: 0.31)
    case "amber": return Color(red: 0.93, green: 0.54, blue: 0.22)
    case "peach": return Color(red: 0.93, green: 0.58, blue: 0.43)
    case "salmon": return Color(red: 0.90, green: 0.42, blue: 0.42)
    case "plum": return Color(red: 0.54, green: 0.35, blue: 0.62)
    case "brown": return Color(red: 0.56, green: 0.40, blue: 0.30)
    case "slate": return Color(red: 0.43, green: 0.50, blue: 0.58)
    case "graphite": return Color(red: 0.34, green: 0.36, blue: 0.40)
    default: return workoutAccentColor("blue")
    }
}
