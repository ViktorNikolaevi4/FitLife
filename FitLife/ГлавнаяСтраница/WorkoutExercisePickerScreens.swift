import SwiftUI
import SwiftData

struct WorkoutExerciseTemplate: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let accentName: String
    let defaultSets: [(weight: Double, reps: Int)]
}

struct WorkoutExerciseDraft: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var systemImage: String
    var accentName: String
    var sets: [WorkoutDraftSet]

    init(name: String, systemImage: String, accentName: String, sets: [WorkoutDraftSet]) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.sets = sets
    }

    init(template: WorkoutExerciseTemplate) {
        self.name = template.name
        self.systemImage = template.systemImage
        self.accentName = template.accentName
        self.sets = template.defaultSets.map { WorkoutDraftSet(weight: $0.weight, reps: $0.reps) }
    }

    init(customTemplate: CustomWorkoutExerciseTemplate) {
        self.name = customTemplate.name
        self.systemImage = customTemplate.systemImage
        self.accentName = customTemplate.accentName
        self.sets = [
            WorkoutDraftSet(weight: 20, reps: 10),
            WorkoutDraftSet(weight: 20, reps: 10),
            WorkoutDraftSet(weight: 20, reps: 10)
        ]
    }
}

struct WorkoutDraftSet: Identifiable, Hashable {
    let id = UUID()
    var weight: Double
    var reps: Int
}

struct AddWorkoutExerciseScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomWorkoutExerciseTemplate.createdAt) private var customTemplates: [CustomWorkoutExerciseTemplate]

    let templates: [WorkoutExerciseTemplate]
    let onAddExercise: (WorkoutExerciseDraft) -> Void

    @State private var draftToConfigure: WorkoutExerciseDraft?
    @State private var isShowingCreateExercise = false
    @State private var searchText = ""

    private var filteredTemplates: [WorkoutExerciseTemplate] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredCustomTemplates: [CustomWorkoutExerciseTemplate] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return customTemplates }
        return customTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalizer.string("workout.select.exercise.title"))
                            .font(.largeTitle.bold())
                        Text(AppLocalizer.string("workout.select.exercise.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    createExerciseCard

                    workoutTemplateSection(
                        title: AppLocalizer.string("workout.select.exercise.library"),
                        templates: filteredTemplates
                    )

                    if !filteredCustomTemplates.isEmpty {
                        customTemplateSection
                    }

                    if filteredTemplates.isEmpty && filteredCustomTemplates.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .searchable(text: $searchText, prompt: AppLocalizer.string("workout.select.exercise.search"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $draftToConfigure) { draft in
                WorkoutExerciseSetupScreen(
                    draft: draft,
                    onSave: { configuredDraft in
                        onAddExercise(configuredDraft)
                    }
                )
            }
            .navigationDestination(isPresented: $isShowingCreateExercise) {
                CreateWorkoutExerciseTemplateScreen { template in
                    draftToConfigure = WorkoutExerciseDraft(customTemplate: template)
                }
            }
        }
    }

    private var createExerciseCard: some View {
        Button(action: { isShowingCreateExercise = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.08))

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalizer.string("workout.select.exercise.create.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(AppLocalizer.string("workout.select.exercise.create.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    private func workoutTemplateSection(title: String, templates: [WorkoutExerciseTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                ForEach(templates) { template in
                    Button(action: { draftToConfigure = WorkoutExerciseDraft(template: template) }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(workoutAccentColor(template.accentName).opacity(0.14))

                                Image(systemName: template.systemImage)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(workoutAccentColor(template.accentName))
                            }
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(AppLocalizer.format("workout.exercise.summary", template.defaultSets.count, 0))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customTemplateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.string("workout.select.exercise.saved"))
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                ForEach(filteredCustomTemplates) { template in
                    Button(action: { draftToConfigure = WorkoutExerciseDraft(customTemplate: template) }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(workoutAccentColor(template.accentName).opacity(0.14))

                                Image(systemName: template.systemImage)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(workoutAccentColor(template.accentName))
                            }
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(AppLocalizer.string("workout.select.exercise.saved.subtitle"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ExerciseIconOption: Identifiable, Hashable {
    let id = UUID()
    let systemImage: String
}

private struct ExerciseColorOption: Identifiable, Hashable {
    let id = UUID()
    let accentName: String
}

private struct CreateWorkoutExerciseTemplateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onCreated: (CustomWorkoutExerciseTemplate) -> Void

    @State private var name = ""
    @State private var selectedIcon = "dumbbell.fill"
    @State private var selectedAccent = "blue"
    @FocusState private var isNameFieldFocused: Bool

    private let iconOptions: [ExerciseIconOption] = [
        .init(systemImage: "dumbbell.fill"),
        .init(systemImage: "figure.strengthtraining.traditional"),
        .init(systemImage: "figure.run.square.stack"),
        .init(systemImage: "figure.core.training"),
        .init(systemImage: "figure.arms.open"),
        .init(systemImage: "figure.mixed.cardio"),
        .init(systemImage: "bolt.heart.fill"),
        .init(systemImage: "flame.fill")
    ]

    private let colorOptions: [ExerciseColorOption] = [
        .init(accentName: "blue"),
        .init(accentName: "green"),
        .init(accentName: "orange"),
        .init(accentName: "purple")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                previewCard

                VStack(alignment: .leading, spacing: 10) {
                    Text(AppLocalizer.string("workout.create.name"))
                        .font(.headline.weight(.semibold))

                    TextField(AppLocalizer.string("workout.create.name.placeholder"), text: $name)
                        .textFieldStyle(.plain)
                        .focused($isNameFieldFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("workout.create.color"))
                        .font(.headline.weight(.semibold))

                    HStack(spacing: 12) {
                        ForEach(colorOptions) { option in
                            Button(action: { selectedAccent = option.accentName }) {
                                ZStack {
                                    Circle()
                                        .fill(workoutAccentColor(option.accentName))
                                        .frame(width: 42, height: 42)

                                    if selectedAccent == option.accentName {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("workout.create.icon"))
                        .font(.headline.weight(.semibold))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(iconOptions) { option in
                            Button(action: { selectedIcon = option.systemImage }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(selectedIcon == option.systemImage ? workoutAccentColor(selectedAccent).opacity(0.16) : Color.white)

                                    Image(systemName: option.systemImage)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(selectedIcon == option.systemImage ? workoutAccentColor(selectedAccent) : .primary)
                                }
                                .frame(height: 64)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: saveTemplate) {
                    Text(AppLocalizer.string("workout.create.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.black))
                }
                .buttonStyle(.plain)
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("workout.create.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isNameFieldFocused = true
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(workoutAccentColor(selectedAccent).opacity(0.14))

                Image(systemName: selectedIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(workoutAccentColor(selectedAccent))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(trimmedName.isEmpty ? AppLocalizer.string("workout.create.preview") : trimmedName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(AppLocalizer.string("workout.create.preview.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveTemplate() {
        guard !trimmedName.isEmpty else { return }
        let template = CustomWorkoutExerciseTemplate(
            name: trimmedName,
            systemImage: selectedIcon,
            accentName: selectedAccent
        )
        modelContext.insert(template)
        try? modelContext.save()
        onCreated(template)
        dismiss()
    }
}

private struct WorkoutExerciseSetupScreen: View {
    @Environment(\.dismiss) private var dismiss

    let draft: WorkoutExerciseDraft
    let onSave: (WorkoutExerciseDraft) -> Void

    @State private var sets: [WorkoutDraftSet]

    init(draft: WorkoutExerciseDraft, onSave: @escaping (WorkoutExerciseDraft) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _sets = State(initialValue: draft.sets)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(workoutAccentColor(draft.accentName).opacity(0.14))

                        Image(systemName: draft.systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(workoutAccentColor(draft.accentName))
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.name)
                            .font(.title3.weight(.semibold))
                        Text(AppLocalizer.string("workout.setup.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        WorkoutDraftSetEditorRow(
                            title: AppLocalizer.format("workout.setup.set.title", index + 1),
                            set: set,
                            onChange: { updated in sets[index] = updated },
                            onDelete: {
                                guard sets.count > 1 else { return }
                                sets.remove(at: index)
                            },
                            canDelete: sets.count > 1
                        )
                    }
                }

                Button(action: addSet) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text(AppLocalizer.string("workout.setup.add.set"))
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                }
                .buttonStyle(.plain)

                Button(action: save) {
                    Text(AppLocalizer.string("workout.setup.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.black))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("workout.setup.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addSet() {
        let last = sets.last ?? WorkoutDraftSet(weight: 20, reps: 10)
        sets.append(WorkoutDraftSet(weight: last.weight, reps: last.reps))
    }

    private func save() {
        var configuredDraft = draft
        configuredDraft.sets = sets
        onSave(configuredDraft)
        dismiss()
    }
}

private struct WorkoutDraftSetEditorRow: View {
    private enum Field: Hashable {
        case weight
        case reps
    }

    let title: String
    let set: WorkoutDraftSet
    let onChange: (WorkoutDraftSet) -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var focusedField: Field?

    init(
        title: String,
        set: WorkoutDraftSet,
        onChange: @escaping (WorkoutDraftSet) -> Void,
        onDelete: @escaping () -> Void,
        canDelete: Bool
    ) {
        self.title = title
        self.set = set
        self.onChange = onChange
        self.onDelete = onDelete
        self.canDelete = canDelete
        _weightText = State(initialValue: Self.weightText(from: set.weight))
        _repsText = State(initialValue: "\(set.reps)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))

                Spacer()

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                workoutValueEditor(
                    label: AppLocalizer.string("workout.setup.weight"),
                    text: $weightText,
                    suffix: "кг",
                    keyboardType: .decimalPad,
                    field: .weight,
                    onMinus: { updateWeight(by: -2.5) },
                    onPlus: { updateWeight(by: 2.5) },
                    onCommit: commitWeight
                )

                workoutValueEditor(
                    label: AppLocalizer.string("workout.setup.reps"),
                    text: $repsText,
                    suffix: nil,
                    keyboardType: .numberPad,
                    field: .reps,
                    onMinus: { updateReps(by: -1) },
                    onPlus: { updateReps(by: 1) },
                    onCommit: commitReps
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
        .onChange(of: set) { _, newValue in
            if focusedField != .weight {
                weightText = Self.weightText(from: newValue.weight)
            }
            if focusedField != .reps {
                repsText = "\(newValue.reps)"
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(AppLocalizer.string("common.done")) {
                    commitActiveField()
                    focusedField = nil
                }
            }
        }
    }

    private func workoutValueEditor(
        label: String,
        text: Binding<String>,
        suffix: String?,
        keyboardType: UIKeyboardType,
        field: Field,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    TextField("", text: text)
                        .font(.headline.weight(.semibold))
                        .keyboardType(keyboardType)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: field)
                        .onSubmit(onCommit)

                    if let suffix {
                        Text(suffix)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .onTapGesture {
                    focusedField = field
                }

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func updateWeight(by delta: Double) {
        let next = max(0, set.weight + delta)
        weightText = Self.weightText(from: next)
        onChange(WorkoutDraftSet(weight: next, reps: set.reps))
    }

    private func updateReps(by delta: Int) {
        let next = max(1, set.reps + delta)
        repsText = "\(next)"
        onChange(WorkoutDraftSet(weight: set.weight, reps: next))
    }

    private func commitActiveField() {
        switch focusedField {
        case .weight:
            commitWeight()
        case .reps:
            commitReps()
        case nil:
            break
        }
    }

    private func commitWeight() {
        let normalized = weightText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Double(normalized) ?? set.weight
        let clamped = max(0, parsed)
        weightText = Self.weightText(from: clamped)
        onChange(WorkoutDraftSet(weight: clamped, reps: set.reps))
    }

    private func commitReps() {
        let digits = repsText.filter(\.isNumber)
        let parsed = Int(digits) ?? set.reps
        let clamped = max(1, parsed)
        repsText = "\(clamped)"
        onChange(WorkoutDraftSet(weight: set.weight, reps: clamped))
    }

    private static func weightText(from weight: Double) -> String {
        if weight.rounded() == weight {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
