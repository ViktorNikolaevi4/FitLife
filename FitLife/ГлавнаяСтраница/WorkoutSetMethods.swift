import SwiftUI
import SwiftData
import Combine
import UIKit

struct WorkoutSetGroupDescriptor: Identifiable, Hashable {
    let id: UUID
    let method: WorkoutSetMethod
    let steps: [WorkoutSet]
    let orderIndex: Int

    static func == (lhs: WorkoutSetGroupDescriptor, rhs: WorkoutSetGroupDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var isCompleted: Bool {
        steps.isEmpty == false && steps.allSatisfy(\.isCompleted)
    }

    var pyramidPattern: WorkoutPyramidPattern {
        steps.first?.pyramidPattern ?? .ascending
    }
}

func workoutSetGroups(for exercise: WorkoutExercise) -> [WorkoutSetGroupDescriptor] {
    let sorted = exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    var groups: [UUID: [WorkoutSet]] = [:]
    var methodByID: [UUID: WorkoutSetMethod] = [:]
    var orderByID: [UUID: Int] = [:]

    for set in sorted {
        let groupID = set.method == .normal ? set.id : (set.groupID ?? set.id)
        groups[groupID, default: []].append(set)
        methodByID[groupID] = set.method
        orderByID[groupID] = min(orderByID[groupID] ?? set.orderIndex, set.orderIndex)
    }

    return groups.map { id, steps in
        WorkoutSetGroupDescriptor(
            id: id,
            method: methodByID[id] ?? .normal,
            steps: steps.sorted {
                if $0.stepIndex == $1.stepIndex { return $0.orderIndex < $1.orderIndex }
                return $0.stepIndex < $1.stepIndex
            },
            orderIndex: orderByID[id] ?? 0
        )
    }
    .sorted { $0.orderIndex < $1.orderIndex }
}

struct WorkoutCompositeSetCard: View {
    let number: Int
    let group: WorkoutSetGroupDescriptor
    let onOpen: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: group.method.iconName)
                        .font(.caption.weight(.bold))
                    Text(group.method.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: group.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(group.isCompleted ? Color.green : Color.secondary)
                }
                .foregroundStyle(.blue)

                Text(summary)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(9)
        .frame(width: 152, height: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(group.isCompleted ? Color.green.opacity(0.55) : Color(.separator).opacity(0.4))
        )
        .contextMenu {
            Button("Редактировать метод", systemImage: "slider.horizontal.3", action: onEdit)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.method.title), подход \(number), \(group.steps.count) этапа, \(group.isCompleted ? "выполнен" : "не выполнен")")
        .accessibilityAction(named: "Редактировать") {
            onEdit()
        }
    }

    private var summary: String {
        switch group.method {
        case .normal:
            return group.steps.first.map(stepValue) ?? "—"
        case .dropSet:
            return group.steps.prefix(3).map { "\(formattedWorkoutWeight($0.weight))×\($0.reps)" }.joined(separator: " → ")
        case .pyramid:
            guard let first = group.steps.first, let last = group.steps.last else { return "—" }
            return "\(group.pyramidPattern.symbol) • \(formattedWorkoutWeight(first.weight))–\(formattedWorkoutWeight(last.weight)) кг"
        case .cluster:
            guard let first = group.steps.first else { return "—" }
            return "\(formattedWorkoutWeight(first.weight)) кг • \(group.steps.count)×\(first.reps)"
        }
    }

    private func stepValue(_ step: WorkoutSet) -> String {
        formattedWorkoutSetValue(
            weight: step.weight,
            reps: step.reps,
            durationSeconds: step.durationSeconds,
            metricType: step.metricType
        )
    }
}

struct WorkoutSetStepDraft: Identifiable {
    let id: UUID
    var weight: Double
    var reps: Int
    var durationSeconds: Int
    var metricType: WorkoutSetMetricType
    var restAfterSeconds: Int
    var isCompleted: Bool
}

struct WorkoutSetGroupEditorSheet: View {
    private enum Field: Hashable {
        case weight(UUID)
        case reps(UUID)
    }

    @Environment(\.dismiss) private var dismiss

    let group: WorkoutSetGroupDescriptor
    let onSave: ([WorkoutSetStepDraft], WorkoutPyramidPattern) -> Void
    let onDelete: () -> Void

    @State private var steps: [WorkoutSetStepDraft]
    @State private var showDeleteConfirmation = false
    @State private var pyramidPattern: WorkoutPyramidPattern
    @FocusState private var focusedField: Field?

    init(
        group: WorkoutSetGroupDescriptor,
        onSave: @escaping ([WorkoutSetStepDraft], WorkoutPyramidPattern) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.group = group
        self.onSave = onSave
        self.onDelete = onDelete
        _pyramidPattern = State(initialValue: group.pyramidPattern)
        _steps = State(initialValue: group.steps.map {
            WorkoutSetStepDraft(
                id: $0.id,
                weight: $0.weight,
                reps: $0.reps,
                durationSeconds: $0.durationSeconds,
                metricType: $0.metricType,
                restAfterSeconds: $0.restAfterSeconds,
                isCompleted: $0.isCompleted
            )
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    methodDescription

                    if group.method == .pyramid {
                        pyramidPatternPicker
                    }

                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        stepEditor(step, index: index)
                    }

                    Button(action: addStep) {
                        Label("Добавить этап", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить \(group.method.title.lowercased())", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(group.method.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        focusedField = nil
                        onSave(steps, pyramidPattern)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(steps.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
            .confirmationDialog(
                "Удалить \(group.method.title.lowercased())?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private var methodDescription: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: group.method.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.blue.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(editorTitle).font(.headline)
                Text(editorDescription).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }

    private var pyramidPatternPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Схема пирамиды")
                .font(.headline)
            Picker("Схема пирамиды", selection: $pyramidPattern) {
                ForEach([WorkoutPyramidPattern.ascending, .descending, .full]) { pattern in
                    Text("\(pattern.symbol) \(pattern.title)").tag(pattern)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: pyramidPattern) { _, pattern in
                applyPyramidPattern(pattern)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }

    private var editorTitle: String {
        switch group.method {
        case .normal: return "Обычный подход"
        case .dropSet: return "Последовательно снижайте вес"
        case .pyramid: return "Настройте каждую ступень"
        case .cluster: return "Мини-сеты с коротким отдыхом"
        }
    }

    private var editorDescription: String {
        switch group.method {
        case .normal: return "Один рабочий подход."
        case .dropSet: return "Этапы выполняются подряд без полного отдыха."
        case .pyramid: return "Вес и повторения меняются от ступени к ступени."
        case .cluster: return "После каждого мини-сета запускается короткий таймер отдыха."
        }
    }

    private func stepEditor(_ step: WorkoutSetStepDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stepTitle(index))
                    .font(.headline.weight(.semibold))
                Spacer()
                if steps.count > minimumStepCount {
                    Button(role: .destructive) {
                        steps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }

            editorRow(icon: "dumbbell.fill", title: "Вес") {
                HStack(spacing: 5) {
                    TextField("0", value: binding(for: step.id, keyPath: \.weight), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .weight(step.id))
                        .frame(width: 82)
                    Text("кг").foregroundStyle(.secondary)
                }
            }

            editorRow(icon: "target", title: "Повторения") {
                TextField("0", value: binding(for: step.id, keyPath: \.reps), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .reps(step.id))
                    .frame(width: 82)
            }

            if group.method == .cluster || group.method == .pyramid {
                Stepper(
                    "Отдых после этапа: \(binding(for: step.id, keyPath: \.restAfterSeconds).wrappedValue) сек",
                    value: binding(for: step.id, keyPath: \.restAfterSeconds),
                    in: 0...300,
                    step: 5
                )
                .font(.subheadline)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator).opacity(0.32)))
    }

    private func editorRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.blue).frame(width: 24)
            Text(title)
            Spacer()
            content()
        }
    }

    private func binding<Value>(for id: UUID, keyPath: WritableKeyPath<WorkoutSetStepDraft, Value>) -> Binding<Value> {
        Binding(
            get: {
                guard let index = steps.firstIndex(where: { $0.id == id }) else {
                    preconditionFailure("Missing set step")
                }
                return steps[index][keyPath: keyPath]
            },
            set: { value in
                guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
                steps[index][keyPath: keyPath] = value
            }
        )
    }

    private func stepTitle(_ index: Int) -> String {
        switch group.method {
        case .dropSet: return "Ступень \(index + 1)"
        case .pyramid: return "Ступень \(index + 1)"
        case .cluster: return "Мини-сет \(index + 1)"
        case .normal: return "Подход"
        }
    }

    private var minimumStepCount: Int {
        group.method == .normal ? 1 : 2
    }

    private func addStep() {
        let last = steps.last
        let weight: Double
        switch group.method {
        case .dropSet:
            weight = max((last?.weight ?? 20) * 0.8, 0)
        case .pyramid:
            weight = max((last?.weight ?? 20) + 5, 0)
        case .cluster, .normal:
            weight = last?.weight ?? 20
        }
        steps.append(
            WorkoutSetStepDraft(
                id: UUID(),
                weight: weight,
                reps: last?.reps ?? 8,
                durationSeconds: last?.durationSeconds ?? 30,
                metricType: .reps,
                restAfterSeconds: group.method == .cluster ? 20 : (group.method == .pyramid ? 90 : 0),
                isCompleted: false
            )
        )
    }

    private func applyPyramidPattern(_ pattern: WorkoutPyramidPattern) {
        guard steps.isEmpty == false else { return }
        let minimumWeight = steps.map(\.weight).min() ?? 20
        let maximumWeight = max(steps.map(\.weight).max() ?? minimumWeight, minimumWeight + 5)
        let count = steps.count

        for index in steps.indices {
            let progress: Double
            switch pattern {
            case .ascending:
                progress = count == 1 ? 1 : Double(index) / Double(count - 1)
            case .descending:
                progress = count == 1 ? 1 : Double(count - 1 - index) / Double(count - 1)
            case .full:
                let center = Double(max(count - 1, 1)) / 2
                progress = max(0, 1 - abs(Double(index) - center) / max(center, 1))
            case .custom:
                return
            }
            steps[index].weight = minimumWeight + (maximumWeight - minimumWeight) * progress
            steps[index].reps = max(6, 12 - Int((progress * 6).rounded()))
        }
    }
}

struct WorkoutSetMethodRunnerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let exercise: WorkoutExercise
    let groupID: UUID

    @State private var now = Date()
    @State private var currentStepIndex = 0
    @State private var isResting = false
    @State private var restEndsAt: Date?
    @State private var actualWeights: [UUID: Double]
    @State private var actualReps: [UUID: Int]
    @FocusState private var isInputFocused: Bool

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(exercise: WorkoutExercise, groupID: UUID) {
        self.exercise = exercise
        self.groupID = groupID
        let matching = exercise.setItems.filter { ($0.groupID ?? $0.id) == groupID }.sorted { $0.stepIndex < $1.stepIndex }
        let firstIncomplete = matching.firstIndex(where: { $0.isCompleted == false }) ?? max(matching.count - 1, 0)
        _currentStepIndex = State(initialValue: firstIncomplete)
        _actualWeights = State(initialValue: Dictionary(uniqueKeysWithValues: matching.map { ($0.id, $0.actualWeight ?? $0.weight) }))
        _actualReps = State(initialValue: Dictionary(uniqueKeysWithValues: matching.map { ($0.id, $0.actualReps ?? $0.reps) }))
    }

    private var steps: [WorkoutSet] {
        exercise.setItems
            .filter { ($0.groupID ?? $0.id) == groupID }
            .sorted { $0.stepIndex < $1.stepIndex }
    }

    private var method: WorkoutSetMethod {
        steps.first?.method ?? .normal
    }

    private var currentStep: WorkoutSet? {
        guard steps.isEmpty == false else { return nil }
        return steps[min(max(currentStepIndex, 0), steps.count - 1)]
    }

    private var isCompleted: Bool {
        steps.isEmpty == false && steps.allSatisfy(\.isCompleted)
    }

    private var remainingRest: Int {
        guard let restEndsAt else { return 0 }
        return max(Int(ceil(restEndsAt.timeIntervalSince(now))), 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                methodHeader
                currentStageCard
                stageHistory
            }
            .padding(16)
            .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(method.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isInputFocused == false {
                primaryControl
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isInputFocused)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { isInputFocused = false }
            }
        }
        .onReceive(ticker) { date in
            now = date
            if isResting && remainingRest == 0 {
                advanceAfterRest()
            }
        }
    }

    private var methodHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: method.iconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.blue.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name).font(.headline)
                Text("\(stageName) \(min(currentStepIndex + 1, max(steps.count, 1))) из \(steps.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }

    private var currentStageCard: some View {
        VStack(spacing: 16) {
            if isResting {
                Text("ОТДЫХ")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                Text(formatClock(remainingRest))
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("Далее: \(stageName.lowercased()) \(min(currentStepIndex + 2, steps.count))")
                    .foregroundStyle(.secondary)
            } else if let step = currentStep {
                Text(isCompleted ? "РЕЗУЛЬТАТ" : "ТЕКУЩИЙ \(stageName.uppercased())")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isCompleted ? Color.green : Color.blue)

                HStack(spacing: 12) {
                    actualField(
                        title: "Вес",
                        value: weightBinding(for: step),
                        suffix: "кг",
                        keyboard: .decimalPad
                    )
                    actualField(
                        title: "Повторения",
                        value: repsBinding(for: step),
                        suffix: "",
                        keyboard: .numberPad
                    )
                }

                Text("План: \(formattedWorkoutWeight(step.weight)) кг × \(step.reps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Нет этапов").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private func actualField(
        title: String,
        value: Binding<Double>,
        suffix: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(keyboard)
                    .font(.title3.weight(.bold))
                    .focused($isInputFocused)
                Text(suffix).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actualField(
        title: String,
        value: Binding<Int>,
        suffix: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(keyboard)
                    .font(.title3.weight(.bold))
                    .focused($isInputFocused)
                Text(suffix).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var stageHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Этапы").font(.title3.weight(.bold))
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 12) {
                    Image(systemName: step.isCompleted ? "checkmark.circle.fill" : (index == currentStepIndex ? "circle.inset.filled" : "circle"))
                        .font(.title3)
                        .foregroundStyle(step.isCompleted ? Color.green : (index == currentStepIndex ? Color.blue : Color.secondary))
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(stageName) \(index + 1)").font(.headline)
                        Text(stageResult(step))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if step.restAfterSeconds > 0 && index < steps.count - 1 {
                        Text("\(step.restAfterSeconds) сек")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            }
        }
    }

    private var primaryControl: some View {
        Button(action: primaryAction) {
            Label(primaryTitle, systemImage: primaryIcon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
        }
        .buttonStyle(.plain)
    }

    private var primaryTitle: String {
        if isCompleted { return "Готово" }
        if isResting { return "Пропустить отдых" }
        return "\(stageName) выполнен"
    }

    private var primaryIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isResting { return "forward.fill" }
        return "checkmark.circle"
    }

    private var stageName: String {
        method == .cluster ? "Мини-сет" : "Ступень"
    }

    private func primaryAction() {
        if isCompleted {
            dismiss()
        } else if isResting {
            advanceAfterRest()
        } else {
            completeCurrentStep()
        }
    }

    private func completeCurrentStep() {
        guard let step = currentStep else { return }
        step.actualWeight = actualWeights[step.id] ?? step.weight
        step.actualReps = actualReps[step.id] ?? step.reps
        step.actualDurationSeconds = step.durationSeconds
        step.isCompleted = true
        step.completedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard currentStepIndex + 1 < steps.count else { return }
        if step.restAfterSeconds > 0 {
            isResting = true
            restEndsAt = Date().addingTimeInterval(TimeInterval(step.restAfterSeconds))
        } else {
            currentStepIndex += 1
        }
    }

    private func advanceAfterRest() {
        isResting = false
        restEndsAt = nil
        currentStepIndex = min(currentStepIndex + 1, max(steps.count - 1, 0))
    }

    private func weightBinding(for step: WorkoutSet) -> Binding<Double> {
        Binding(
            get: { actualWeights[step.id] ?? step.weight },
            set: { actualWeights[step.id] = max($0, 0) }
        )
    }

    private func repsBinding(for step: WorkoutSet) -> Binding<Int> {
        Binding(
            get: { actualReps[step.id] ?? step.reps },
            set: { actualReps[step.id] = max($0, 0) }
        )
    }

    private func stageResult(_ step: WorkoutSet) -> String {
        if step.isCompleted {
            return "Факт: \(formattedWorkoutWeight(step.actualWeight ?? step.weight)) кг × \(step.actualReps ?? step.reps)"
        }
        return "План: \(formattedWorkoutWeight(step.weight)) кг × \(step.reps)"
    }

    private func formatClock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }
}
