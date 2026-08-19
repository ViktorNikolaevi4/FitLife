import SwiftUI

private let workoutCardBackground = Color(.secondarySystemBackground)
private let workoutCardInsetBackground = Color(.tertiarySystemBackground)
private let workoutCardBorder = Color(.separator).opacity(0.40)

struct WorkoutExerciseCard: View {
    let exercise: WorkoutExercise

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
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

                Text(AppLocalizer.format("workout.exercise.summary", sortedSets.count, completedCount))
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

struct WorkoutExerciseDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercise: WorkoutExercise
    let followingExercises: [WorkoutExercise]
    let onOpenExercise: (WorkoutExercise) -> Void

    @State private var personalNote: String
    @State private var editingSet: WorkoutSet?
    @FocusState private var isPersonalNoteFocused: Bool
    @State private var showIncompleteSetsConfirmation = false

    init(
        exercise: WorkoutExercise,
        followingExercises: [WorkoutExercise],
        onOpenExercise: @escaping (WorkoutExercise) -> Void
    ) {
        self.exercise = exercise
        self.followingExercises = followingExercises
        self.onOpenExercise = onOpenExercise
        _personalNote = State(initialValue: exercise.userNote)
    }

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    private var areAllSetsComplete: Bool {
        sortedSets.isEmpty == false && completedCount == sortedSets.count
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                exerciseOverview
                setCards
                trainerCommentCard
                personalNoteCard
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 118)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if isPersonalNoteFocused == false {
                completionAction
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPersonalNoteFocused)
        .onDisappear(perform: persistPersonalNote)
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
        .onChange(of: isPersonalNoteFocused) { _, isFocused in
            if isFocused == false {
                persistPersonalNote()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    isPersonalNoteFocused = false
                }
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
                    value: "\(completedCount) из \(sortedSets.count)",
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
                    ForEach(sortedSets, id: \.id) { set in
                        WorkoutSetHorizontalCard(
                            set: set,
                            onEdit: { editingSet = set },
                            onToggleCompletion: { toggleSetCompletion(set) }
                        )
                    }

                    WorkoutAddSetCard(action: addSet)
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

            TextEditor(text: $personalNote)
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
                onOpenExercise(nextExercise)
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
            Button { dismiss() } label: {
                Label("Упражнение завершено", systemImage: "checkmark.circle.fill")
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
            dismiss()
        } else {
            onOpenExercise(followingExercises[0])
        }
    }

    private func addSet() {
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

    private func toggleSetCompletion(_ set: WorkoutSet) {
        set.isCompleted.toggle()
        try? modelContext.save()
    }

    private func persistPersonalNote() {
        let trimmedNote = personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard exercise.userNote != trimmedNote else { return }
        exercise.userNote = trimmedNote
        try? modelContext.save()
    }
}

private struct WorkoutSetHorizontalCard: View {
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
                Text("Подход \(set.orderIndex + 1)")
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
