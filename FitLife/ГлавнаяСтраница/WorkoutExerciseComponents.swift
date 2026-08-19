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

    @State private var personalNote: String
    @State private var editingSet: WorkoutSet?

    init(exercise: WorkoutExercise, followingExercises: [WorkoutExercise]) {
        self.exercise = exercise
        self.followingExercises = followingExercises
        _personalNote = State(initialValue: exercise.userNote)
    }

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    private var isComplete: Bool {
        sortedSets.isEmpty == false && completedCount == sortedSets.count
    }

    private var coachComment: String {
        exercise.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentSet: WorkoutSet? {
        sortedSets.first(where: { $0.isCompleted == false }) ?? sortedSets.last
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
            completionAction
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground))
        }
        .onDisappear(perform: persistPersonalNote)
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
                    title: "Повторений",
                    value: currentSet.map {
                        formattedWorkoutMetricValue(
                            reps: $0.reps,
                            durationSeconds: $0.durationSeconds,
                            metricType: $0.metricType
                        )
                    } ?? "—",
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
                        WorkoutSetHorizontalCard(set: set) {
                            editingSet = set
                        }
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
        if isComplete, let nextExercise = followingExercises.first {
            NavigationLink {
                WorkoutExerciseDetailScreen(
                    exercise: nextExercise,
                    followingExercises: Array(followingExercises.dropFirst())
                )
            } label: {
                Label("Следующее упражнение", systemImage: "arrow.right.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
            }
            .buttonStyle(.plain)
        } else if isComplete {
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
        for set in sortedSets {
            set.isCompleted = true
        }
        persistPersonalNote()
        try? modelContext.save()
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

    private func persistPersonalNote() {
        let trimmedNote = personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard exercise.userNote != trimmedNote else { return }
        exercise.userNote = trimmedNote
        try? modelContext.save()
    }
}

private struct WorkoutSetHorizontalCard: View {
    let set: WorkoutSet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Подход \(set.orderIndex + 1)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 8)
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                }

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
            .padding(9)
            .frame(width: 96, height: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(workoutCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(set.isCompleted ? Color.green.opacity(0.55) : workoutCardBorder)
            )
        }
        .buttonStyle(.plain)
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
        NavigationStack {
            Form {
                Section("Подход \(set.orderIndex + 1)") {
                    Picker("Тип", selection: $metricType) {
                        Text("Повторения").tag(WorkoutSetMetricType.reps)
                        Text("Время").tag(WorkoutSetMetricType.duration)
                    }

                    TextField("Вес, кг", value: $weight, format: .number)
                        .keyboardType(.decimalPad)

                    if metricType == .reps {
                        TextField("Повторения", value: $reps, format: .number)
                            .keyboardType(.numberPad)
                    } else {
                        TextField("Время, секунд", value: $durationSeconds, format: .number)
                            .keyboardType(.numberPad)
                    }

                    Toggle("Подход выполнен", isOn: $isCompleted)
                }

                Section {
                    Button("Удалить подход", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Редактировать подход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
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
