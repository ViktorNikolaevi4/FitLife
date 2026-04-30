import SwiftUI
import SwiftData

private let workoutPickerCardBackground = Color(.secondarySystemBackground)
private let workoutPickerInsetBackground = Color(.tertiarySystemBackground)
private let workoutPickerCardBorder = Color(.separator).opacity(0.40)

struct WorkoutExerciseTemplate: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let accentName: String
    let defaultSets: [WorkoutDraftSet]
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
        self.sets = template.defaultSets
    }

    init(customTemplate: CustomWorkoutExerciseTemplate) {
        self.name = customTemplate.name
        self.systemImage = customTemplate.systemImage
        self.accentName = customTemplate.accentName
        self.sets = [
            WorkoutDraftSet(weight: 20, reps: 10)
        ]
    }
}

struct WorkoutDraftSet: Identifiable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var durationSeconds: Int
    var metricTypeRaw: String

    var metricType: WorkoutSetMetricType {
        get { WorkoutSetMetricType(rawValue: metricTypeRaw) ?? .reps }
        set { metricTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int = 10,
        durationSeconds: Int = 30,
        metricType: WorkoutSetMetricType = .reps
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.metricTypeRaw = metricType.rawValue
    }
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
                        .fill(workoutPickerInsetBackground)

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
            .background(RoundedRectangle(cornerRadius: 22).fill(workoutPickerCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(workoutPickerCardBorder)
            )
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

                                workoutIconImage(
                                    named: template.systemImage,
                                    accentName: template.accentName,
                                    size: 22
                                )
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
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 22).fill(workoutPickerCardBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(workoutPickerCardBorder)
                        )
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

                                workoutIconImage(
                                    named: template.systemImage,
                                    accentName: template.accentName,
                                    size: 22
                                )
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
                                .foregroundStyle(.primary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 22).fill(workoutPickerCardBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(workoutPickerCardBorder)
                        )
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
    @State private var selectedIcon = WorkoutExerciseIcon.run
    @State private var selectedAccent = "blue"
    @FocusState private var isNameFieldFocused: Bool

    private let iconOptions: [ExerciseIconOption] = [
        .init(systemImage: WorkoutExerciseIcon.cleanAndJerk),
        .init(systemImage: WorkoutExerciseIcon.jumpingJack),
        .init(systemImage: WorkoutExerciseIcon.run),
        .init(systemImage: WorkoutExerciseIcon.bench),
        .init(systemImage: WorkoutExerciseIcon.inclineBench),
        .init(systemImage: WorkoutExerciseIcon.shoulderPress),
        .init(systemImage: WorkoutExerciseIcon.legPress),
        .init(systemImage: WorkoutExerciseIcon.biceps),
        .init(systemImage: WorkoutExerciseIcon.pullUps),
        .init(systemImage: WorkoutExerciseIcon.snatch),
        .init(systemImage: WorkoutExerciseIcon.squats),
        .init(systemImage: WorkoutExerciseIcon.pistolSquat),
        .init(systemImage: WorkoutExerciseIcon.lunges),
        .init(systemImage: WorkoutExerciseIcon.sidePlank),
        .init(systemImage: WorkoutExerciseIcon.boxJumps),
        .init(systemImage: WorkoutExerciseIcon.deadlift),
        .init(systemImage: WorkoutExerciseIcon.battleRopes),
        .init(systemImage: WorkoutExerciseIcon.jumpRope),
        .init(systemImage: WorkoutExerciseIcon.lowerAbs),
        .init(systemImage: WorkoutExerciseIcon.oneArmRow),
        .init(systemImage: WorkoutExerciseIcon.rowing),
        .init(systemImage: "figure.strengthtraining.traditional"),
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
                        .background(RoundedRectangle(cornerRadius: 18).fill(workoutPickerCardBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(workoutPickerCardBorder)
                        )
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
                                        .fill(
                                            selectedIcon == option.systemImage
                                            ? workoutAccentColor(selectedAccent).opacity(0.16)
                                            : workoutPickerCardBackground
                                        )

                                    workoutIconImage(
                                        named: option.systemImage,
                                        accentName: selectedIcon == option.systemImage ? selectedAccent : "blue",
                                        size: 22
                                    )
                                }
                                .frame(height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .strokeBorder(
                                            selectedIcon == option.systemImage
                                            ? workoutAccentColor(selectedAccent).opacity(0.28)
                                            : workoutPickerCardBorder
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: saveTemplate) {
                    Text(AppLocalizer.string("workout.create.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
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

                workoutIconImage(
                    named: selectedIcon,
                    accentName: selectedAccent,
                    size: 28
                )
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
        .background(RoundedRectangle(cornerRadius: 24).fill(workoutPickerCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(workoutPickerCardBorder)
        )
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

                        workoutIconImage(
                            named: draft.systemImage,
                            accentName: draft.accentName,
                            size: 24
                        )
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
                    .background(RoundedRectangle(cornerRadius: 18).fill(workoutPickerCardBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(workoutPickerCardBorder)
                    )
                }
                .buttonStyle(.plain)

                Button(action: save) {
                    Text(AppLocalizer.string("workout.setup.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(AppLocalizer.string("common.done")) {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }

    private func addSet() {
        let last = sets.last ?? WorkoutDraftSet(weight: 20, reps: 10)
        sets.append(
            WorkoutDraftSet(
                weight: last.weight,
                reps: last.reps,
                durationSeconds: last.durationSeconds,
                metricType: last.metricType
            )
        )
    }

    private func save() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        DispatchQueue.main.async {
            var configuredDraft = draft
            configuredDraft.sets = sets
            onSave(configuredDraft)
            dismiss()
        }
    }
}

struct WorkoutDraftSetEditorRow: View {
    private enum Field: Hashable {
        case weight
        case value
    }

    let title: String
    let set: WorkoutDraftSet
    let onChange: (WorkoutDraftSet) -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    @State private var weightText: String
    @State private var valueText: String
    @State private var activeEditor: Field?
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
        _valueText = State(initialValue: Self.valueText(from: set))
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

            HStack(alignment: .top, spacing: 12) {
                workoutValueEditor(
                    label: AppLocalizer.string("workout.setup.weight"),
                    field: .weight,
                    displayValue: "\(weightText) кг",
                    text: $weightText,
                    keyboardType: .decimalPad,
                    stepButtons: [
                        (label: "-5", action: { updateWeight(by: -5) }),
                        (label: "-2.5", action: { updateWeight(by: -2.5) }),
                        (label: "+2.5", action: { updateWeight(by: 2.5) }),
                        (label: "+5", action: { updateWeight(by: 5) })
                    ],
                    onCommit: commitWeight
                )

                workoutValueEditor(
                    label: set.metricType == .reps
                        ? AppLocalizer.string("workout.setup.reps")
                        : AppLocalizer.string("workout.setup.time"),
                    field: .value,
                    displayValue: set.metricType == .reps
                        ? valueText
                        : formattedWorkoutMetricValue(
                            reps: set.reps,
                            durationSeconds: set.durationSeconds,
                            metricType: set.metricType
                        ),
                    text: $valueText,
                    keyboardType: .numberPad,
                    header: {
                        Picker("", selection: metricTypeBinding) {
                            Text(AppLocalizer.string("workout.setup.metric.reps")).tag(WorkoutSetMetricType.reps)
                            Text(AppLocalizer.string("workout.setup.metric.time")).tag(WorkoutSetMetricType.duration)
                        }
                        .pickerStyle(.segmented)
                    },
                    stepButtons: metricStepButtons,
                    onCommit: commitValue
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(workoutPickerCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(workoutPickerCardBorder)
        )
        .onChange(of: set) { _, newValue in
            if focusedField != .weight {
                weightText = Self.weightText(from: newValue.weight)
            }
            if focusedField != .value {
                valueText = Self.valueText(from: newValue)
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard oldValue != newValue, let oldValue, newValue == nil else { return }
            commit(field: oldValue)
        }
        .animation(.easeInOut(duration: 0.18), value: activeEditor)
    }

    private func workoutValueEditor<Header: View>(
        label: String,
        field: Field,
        displayValue: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        @ViewBuilder header: () -> Header = { EmptyView() },
        stepButtons: [(label: String, action: () -> Void)],
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            header()

            HStack(spacing: 8) {
                Button(action: {
                    guard activeEditor != field else { return }
                    if let activeEditor {
                        commit(field: activeEditor)
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        focusedField = nil
                        self.activeEditor = field
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(displayValue)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    if activeEditor == field {
                        commit(field: field)
                    } else if let activeEditor {
                        commit(field: activeEditor)
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        focusedField = nil
                        activeEditor = activeEditor == field ? nil : field
                    }
                }) {
                    Image(systemName: activeEditor == field ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(workoutPickerCardBackground.opacity(activeEditor == field ? 0.95 : 0.8)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(activeEditor == field ? workoutPickerInsetBackground : workoutPickerInsetBackground.opacity(0.9))
            )

            if activeEditor == field {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(Array(stepButtons.enumerated()), id: \.offset) { _, button in
                            Button(action: button.action) {
                                Text(button.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(workoutPickerInsetBackground)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 10) {
                        TextField("", text: text)
                            .font(.headline.weight(.semibold))
                            .keyboardType(keyboardType)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: field)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(workoutPickerInsetBackground)
                            )
                            .onSubmit(onCommit)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func updateWeight(by delta: Double) {
        let next = max(0, set.weight + delta)
        weightText = Self.weightText(from: next)
        onChange(
            WorkoutDraftSet(
                id: set.id,
                weight: next,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: set.metricType
            )
        )
    }

    private func commitActiveField() {
        switch focusedField {
        case .weight:
            commitWeight()
        case .value:
            commitValue()
        case nil:
            break
        }
    }

    private func commit(field: Field) {
        switch field {
        case .weight:
            commitWeight()
        case .value:
            commitValue()
        }
    }

    private func commitWeight() {
        let normalized = weightText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = Double(normalized) ?? set.weight
        let clamped = max(0, parsed)
        weightText = Self.weightText(from: clamped)
        onChange(
            WorkoutDraftSet(
                id: set.id,
                weight: clamped,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: set.metricType
            )
        )
    }

    private var metricTypeBinding: Binding<WorkoutSetMetricType> {
        Binding(
            get: { set.metricType },
            set: updateMetricType(to:)
        )
    }

    private var metricStepButtons: [(label: String, action: () -> Void)] {
        switch set.metricType {
        case .reps:
            [
                (label: "-2", action: { updateReps(by: -2) }),
                (label: "-1", action: { updateReps(by: -1) }),
                (label: "+1", action: { updateReps(by: 1) }),
                (label: "+2", action: { updateReps(by: 2) })
            ]
        case .duration:
            [
                (label: "-10s", action: { updateDuration(by: -10) }),
                (label: "-5s", action: { updateDuration(by: -5) }),
                (label: "+5s", action: { updateDuration(by: 5) }),
                (label: "+10s", action: { updateDuration(by: 10) })
            ]
        }
    }

    private func updateMetricType(to metricType: WorkoutSetMetricType) {
        var updated = set
        updated.metricType = metricType
        if metricType == .reps {
            updated.reps = max(1, updated.reps)
        } else {
            updated.durationSeconds = max(5, updated.durationSeconds)
        }
        valueText = Self.valueText(from: updated)
        onChange(updated)
    }

    private func updateReps(by delta: Int) {
        let next = max(1, set.reps + delta)
        valueText = "\(next)"
        onChange(
            WorkoutDraftSet(
                id: set.id,
                weight: set.weight,
                reps: next,
                durationSeconds: set.durationSeconds,
                metricType: .reps
            )
        )
    }

    private func updateDuration(by delta: Int) {
        let next = max(5, set.durationSeconds + delta)
        valueText = "\(next)"
        onChange(
            WorkoutDraftSet(
                id: set.id,
                weight: set.weight,
                reps: set.reps,
                durationSeconds: next,
                metricType: .duration
            )
        )
    }

    private func commitValue() {
        let digits = valueText.filter(\.isNumber)
        switch set.metricType {
        case .reps:
            let parsed = Int(digits) ?? set.reps
            let clamped = max(1, parsed)
            valueText = "\(clamped)"
            onChange(
                WorkoutDraftSet(
                    id: set.id,
                    weight: set.weight,
                    reps: clamped,
                    durationSeconds: set.durationSeconds,
                    metricType: .reps
                )
            )
        case .duration:
            let parsed = Int(digits) ?? set.durationSeconds
            let clamped = max(5, parsed)
            valueText = "\(clamped)"
            onChange(
                WorkoutDraftSet(
                    id: set.id,
                    weight: set.weight,
                    reps: set.reps,
                    durationSeconds: clamped,
                    metricType: .duration
                )
            )
        }
    }

    private static func weightText(from weight: Double) -> String {
        if weight.rounded() == weight {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private static func valueText(from set: WorkoutDraftSet) -> String {
        switch set.metricType {
        case .reps:
            return "\(set.reps)"
        case .duration:
            return "\(set.durationSeconds)"
        }
    }
}
