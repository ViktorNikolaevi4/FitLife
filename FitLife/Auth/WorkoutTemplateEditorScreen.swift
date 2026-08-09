import SwiftUI
import SwiftData

private let workoutTemplateEditorCardBackground = Color(.secondarySystemBackground)
private let workoutTemplateEditorBorder = Color(.separator).opacity(0.22)

struct WorkoutTemplateEditorScreen: View {
    let template: WorkoutTemplate

    @StateObject private var store: WorkoutTemplateContentStore
    @State private var showAddExercise = false
    @State private var showAddBlock = false
    @State private var showAIGenerator = false
    @State private var targetBlockId: String?
    @State private var targetGroupId: String?
    @State private var blockForNewGroup: WorkoutTemplateBlockItem?
    @State private var showAssignSheet = false
    @State private var expandedExerciseIds: Set<String> = []
    @State private var collapsedBlockIds: Set<String> = []
    @State private var collapsedNestedGroupIds: Set<String> = []
    @State private var pendingDeleteExercise: WorkoutTemplateExerciseItem?
    @State private var pendingEmptyBlockDeletion: WorkoutTemplateBlockItem?
    @State private var editingExercise: WorkoutTemplateExerciseItem?
    @Query(sort: \CustomWorkoutExerciseTemplate.createdAt) private var customTemplates: [CustomWorkoutExerciseTemplate]
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(template: WorkoutTemplate) {
        self.template = template
        _store = StateObject(wrappedValue: WorkoutTemplateContentStore(template: template))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var templates: [WorkoutExerciseTemplate] {
        workoutTemplates()
    }

    private var templateBlockGroups: [WorkoutTemplateBlockGroup] {
        var groups = store.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { block in
                let exercises = store.exercises
                    .filter { $0.blockId == block.id }
                    .sorted { $0.orderIndex < $1.orderIndex }
                let nestedGroups = block.groups
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { nested in
                        WorkoutTemplateNestedGroup(
                            item: nested,
                            exercises: exercises.filter { $0.groupId == nested.id }
                        )
                    }
                return WorkoutTemplateBlockGroup(
                    id: block.id,
                    block: block,
                    title: block.displayTitle,
                    subtitle: block.subtitle(exerciseCount: exercises.count),
                    exercises: exercises.filter { $0.groupId == nil },
                    nestedGroups: nestedGroups
                )
            }

        let groupedIds = Set(groups.flatMap { $0.exercises.map(\.id) })
        let legacyExercises = store.exercises
            .filter { groupedIds.contains($0.id) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
        if legacyExercises.isEmpty == false {
            groups.insert(
                WorkoutTemplateBlockGroup(
                    id: "legacy-strength",
                    block: nil,
                    title: AppLocalizer.string("workout.block.strength.title"),
                    subtitle: AppLocalizer.format("workout.block.exercise_count", legacyExercises.count),
                    exercises: legacyExercises,
                    nestedGroups: []
                ),
                at: 0
            )
        }

        return groups
    }

    private var estimatedCalories: Int {
        WorkoutCalorieEstimator.estimateTemplateCalories(exercises: store.exercises)
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if template.notes.isEmpty == false {
                Section(appLanguage.localized("trainer.templates.notes")) {
                    Text(template.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.exercises.isEmpty == false {
                Section {
                    HStack(spacing: 12) {
                        Label {
                            Text(AppLocalizer.format("trainer.templates.estimated_calories.value", estimatedCalories))
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.headline)

                        Spacer()

                        Text(AppLocalizer.format("workout.block.exercise_count", store.exercises.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(AppLocalizer.string("trainer.templates.summary"))
                } footer: {
                    Text(AppLocalizer.string("trainer.templates.estimated_calories.hint"))
                }
            }

            Section(appLanguage.localized("trainer.templates.exercises.section")) {
                ForEach(templateBlockGroups) { group in
                    WorkoutTemplateBlockHeader(
                        title: group.title,
                        subtitle: group.subtitle,
                        onAddExercise: group.block.map { block in
                            {
                                targetBlockId = block.id
                                targetGroupId = nil
                                showAddExercise = true
                            }
                        },
                        onAddGroup: group.block.map { block in
                            {
                                blockForNewGroup = block
                            }
                        },
                        isExpanded: collapsedBlockIds.contains(group.id) == false,
                        onToggleExpanded: { toggleBlock(group.id) }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if collapsedBlockIds.contains(group.id) == false {
                        ForEach(group.exercises) { exercise in
                            exerciseRow(exercise)
                        }

                        ForEach(group.nestedGroups) { nestedGroup in
                            WorkoutTemplateNestedGroupHeader(
                                group: nestedGroup.item,
                                isExpanded: collapsedNestedGroupIds.contains(nestedGroup.id) == false,
                                onToggleExpanded: { toggleNestedGroup(nestedGroup.id) },
                                onAddExercise: {
                                    targetBlockId = group.block?.id
                                    targetGroupId = nestedGroup.id
                                    showAddExercise = true
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 2, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            if collapsedNestedGroupIds.contains(nestedGroup.id) == false {
                                ForEach(nestedGroup.exercises) { exercise in
                                    exerciseRow(exercise)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(template.title)
        .hidesHomeFloatingAddButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAssignSheet = true
                } label: {
                    Image(systemName: "paperplane")
                }
                .disabled(store.exercises.isEmpty)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBlock = true
                } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAIGenerator = true
                } label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("Создать тренировку с ИИ")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    targetBlockId = nil
                    showAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.blocks.isEmpty && store.exercises.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.templates.exercises.empty.title"),
                    systemImage: "dumbbell",
                    description: Text(appLanguage.localized("trainer.templates.exercises.empty.subtitle"))
                )
            }
        }
        .task {
            await store.load()
        }
        .sheet(isPresented: $showAddExercise) {
            AddWorkoutExerciseScreen(templates: templates) { draft in
                Task {
                    await store.addExercise(draft, blockId: targetBlockId, groupId: targetGroupId)
                    targetBlockId = nil
                    targetGroupId = nil
                    showAddExercise = false
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddBlock) {
            AddWorkoutTemplateBlockScreen { draft in
                Task {
                    await store.addBlock(
                        title: draft.resolvedTitle,
                        type: draft.type,
                        mode: draft.mode,
                        rounds: draft.rounds,
                        durationMinutes: draft.durationMinutes,
                        workSeconds: draft.workSeconds,
                        restSeconds: draft.restSeconds,
                        restBetweenRoundsSeconds: draft.restBetweenRoundsSeconds
                    )
                    showAddBlock = false
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAIGenerator) {
            AIWorkoutGeneratorScreen(language: appLanguage) { draft in
                Task {
                    await store.addGeneratedDraft(draft)
                    showAIGenerator = false
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $blockForNewGroup) { block in
            AddWorkoutTemplateGroupScreen { draft in
                Task {
                    await store.addGroup(
                        to: block,
                        title: draft.title,
                        kind: draft.kind,
                        rounds: draft.rounds,
                        restSeconds: draft.restSeconds,
                        note: draft.note
                    )
                    blockForNewGroup = nil
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAssignSheet) {
            NavigationStack {
                AssignWorkoutTemplateScreen(
                    template: template,
                    exerciseCount: store.exercises.count
                )
            }
        }
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                WorkoutExerciseSetupScreen(
                    draft: WorkoutExerciseDraft(
                        name: exercise.name,
                        systemImage: exercise.systemImage,
                        accentName: exercise.accentName,
                        activityType: exercise.activityType,
                        metValue: exercise.metValue,
                        sets: exercise.sets,
                        note: exercise.note
                    ),
                    onSave: { draft in
                        Task { await store.updateExercise(exercise, with: draft) }
                    }
                )
            }
        }
        .confirmationDialog(
            AppLocalizer.string("workout.exercise.delete.title"),
            isPresented: Binding(
                get: { pendingDeleteExercise != nil },
                set: { if $0 == false { pendingDeleteExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("workout.exercise.delete"), role: .destructive) {
                guard let pendingDeleteExercise else { return }
                expandedExerciseIds.remove(pendingDeleteExercise.id)
                Task { await store.deleteExercise(pendingDeleteExercise) }
                self.pendingDeleteExercise = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteExercise = nil
            }
        } message: {
            Text(AppLocalizer.string("workout.exercise.delete.message"))
        }
        .confirmationDialog(
            "Удалить пустой блок?",
            isPresented: Binding(
                get: { pendingEmptyBlockDeletion != nil },
                set: { if $0 == false { pendingEmptyBlockDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить блок", role: .destructive) {
                guard let block = pendingEmptyBlockDeletion else { return }
                Task { await store.deleteEmptyBlock(block) }
                pendingEmptyBlockDeletion = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingEmptyBlockDeletion = nil
            }
        } message: {
            Text("В блоке «\(pendingEmptyBlockDeletion?.displayTitle ?? "")» больше нет упражнений.")
        }
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(.snappy(duration: 0.22)) {
            if expandedExerciseIds.contains(id) {
                expandedExerciseIds.remove(id)
            } else {
                expandedExerciseIds.insert(id)
            }
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

    private func toggleNestedGroup(_ id: String) {
        withAnimation(.snappy(duration: 0.22)) {
            if collapsedNestedGroupIds.contains(id) {
                collapsedNestedGroupIds.remove(id)
            } else {
                collapsedNestedGroupIds.insert(id)
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: WorkoutTemplateExerciseItem) -> some View {
        WorkoutTemplateExerciseCard(
            exercise: exercise,
            isExpanded: expandedExerciseIds.contains(exercise.id),
            onToggleExpanded: { toggleExpanded(exercise.id) },
            onEdit: { editingExercise = exercise }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { pendingDeleteExercise = exercise } label: {
                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
            }
        }
        .contextMenu {
            if store.blocks.isEmpty == false {
                Menu("Переместить в блок") {
                    ForEach(store.blocks.sorted { $0.orderIndex < $1.orderIndex }) { block in
                        Button(block.displayTitle) {
                            Task {
                                pendingEmptyBlockDeletion = await store.moveExercise(exercise, to: block)
                            }
                        }
                        .disabled(exercise.blockId == block.id)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }
}

private struct WorkoutTemplateBlockGroup: Identifiable {
    let id: String
    let block: WorkoutTemplateBlockItem?
    let title: String
    let subtitle: String
    let exercises: [WorkoutTemplateExerciseItem]
    let nestedGroups: [WorkoutTemplateNestedGroup]
}

private struct WorkoutTemplateNestedGroup: Identifiable {
    let item: WorkoutTemplateBlockGroupItem
    let exercises: [WorkoutTemplateExerciseItem]
    var id: String { item.id }
}

private struct WorkoutTemplateBlockHeader: View {
    let title: String
    let subtitle: String
    var onAddExercise: (() -> Void)?
    var onAddGroup: (() -> Void)?
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

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
            if let onAddGroup {
                Button(action: onAddGroup) {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить подгруппу")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

private struct WorkoutTemplateNestedGroupHeader: View {
    let group: WorkoutTemplateBlockGroupItem
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onAddExercise: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.kind == .superset ? "link" : "arrow.triangle.branch")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.subheadline.weight(.semibold))
                Text(groupDescription).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onToggleExpanded) {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Button(action: onAddExercise) {
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.10)))
    }

    private var groupDescription: String {
        var parts = [group.kind.title]
        if group.rounds > 1 { parts.append("\(group.rounds) круг(а)") }
        if group.restSeconds > 0 { parts.append("отдых \(group.restSeconds) сек") }
        return parts.joined(separator: " · ")
    }
}

private struct WorkoutTemplateBlockDraft {
    var title: String
    var type: WorkoutBlockType
    var mode: WorkoutBlockMode
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

private struct AIWorkoutGeneratorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let language: AppLanguage
    let onAdd: (AIWorkoutDraft) -> Void

    @State private var command = ""
    @State private var draft: AIWorkoutDraft?
    @State private var errorMessage: String?
    @State private var isGenerating = false

    private let generator = AIWorkoutDraftGenerator()

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    draftPreview(draft)
                } else {
                    commandForm
                }
            }
            .navigationTitle(draft == nil ? "Тренировка с ИИ" : "Черновик тренировки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) { dismiss() }
                }
                if let draft {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Добавить") { onAdd(draft) }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var commandForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Опишите тренировку своими словами", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Text("ИИ создаст черновик. Ничего не будет сохранено без вашего подтверждения.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField(
                    "Например: Добавь основную часть — приседания со штангой 10×10, жим лёжа 4×8, отдых 90 секунд.",
                    text: $command,
                    axis: .vertical
                )
                .lineLimit(5...8)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: generate) {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Создаём черновик…" : "Создать черновик")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.blue))
                }
                .buttonStyle(.plain)
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func draftPreview(_ draft: AIWorkoutDraft) -> some View {
        List {
            if draft.summary.isEmpty == false {
                Section("Что создаст ИИ") {
                    Text(draft.summary)
                        .font(.subheadline)
                }
            }

            ForEach(draft.blocks) { block in
                Section(block.title) {
                    Text(blockSubtitle(block))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(block.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.body.weight(.semibold))
                            Text(exerciseSummary(exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if exercise.note.isEmpty == false {
                                Text(exercise.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Сформировать заново") {
                    self.draft = nil
                    errorMessage = nil
                }
                .foregroundStyle(.blue)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func generate() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommand.isEmpty == false else { return }
        errorMessage = nil
        isGenerating = true
        Task {
            do {
                draft = try await generator.generate(command: trimmedCommand, language: language)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func blockSubtitle(_ block: AIWorkoutDraftBlock) -> String {
        if block.workoutBlockType == .circuit {
            return circuitSubtitle(
                mode: block.workoutBlockMode,
                rounds: block.rounds,
                exerciseCount: block.exercises.count,
                durationMinutes: block.durationMinutes,
                workSeconds: block.workSeconds,
                restSeconds: block.restSeconds,
                restBetweenRoundsSeconds: block.restBetweenRoundsSeconds
            )
        }
        return AppLocalizer.format("workout.block.exercise_count", block.exercises.count)
    }

    private func exerciseSummary(_ exercise: AIWorkoutDraftExercise) -> String {
        let values = exercise.sets.map { set in
            formattedWorkoutSetValue(
                weight: set.weight,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: WorkoutSetMetricType(rawValue: set.metricType) ?? .reps
            )
        }
        return values.joined(separator: " · ")
    }
}

private struct WorkoutTemplateGroupDraft {
    let title: String
    let kind: WorkoutBlockGroupKind
    let rounds: Int
    let restSeconds: Int
    let note: String
}

private struct AddWorkoutTemplateGroupScreen: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkoutTemplateGroupDraft) -> Void

    @State private var title = ""
    @State private var kind: WorkoutBlockGroupKind = .superset
    @State private var rounds = 1
    @State private var restSeconds = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Подгруппа") {
                    TextField("Название, например: Пирамида приседаний", text: $title)
                    Picker("Тип", selection: $kind) {
                        ForEach(WorkoutBlockGroupKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
                Section("Настройки") {
                    Stepper("Повторов группы: \(rounds)", value: $rounds, in: 1...20)
                    Stepper("Отдых: \(restSeconds) сек", value: $restSeconds, in: 0...600, step: 5)
                    TextField("Заметка для клиента (необязательно)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Добавить подгруппу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.save")) {
                        onSave(WorkoutTemplateGroupDraft(
                            title: title,
                            kind: kind,
                            rounds: rounds,
                            restSeconds: restSeconds,
                            note: note
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AddWorkoutTemplateBlockScreen: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkoutTemplateBlockDraft) -> Void

    @State private var type: WorkoutBlockType = .circuit
    @State private var mode: WorkoutBlockMode = .rounds
    @State private var title = ""
    @State private var rounds = 3
    @State private var durationMinutes = 12
    @State private var workSeconds = 20
    @State private var restSeconds = 10
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
                        Picker(AppLocalizer.string("workout.block.mode"), selection: $mode) {
                            ForEach(WorkoutBlockMode.circuitCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch mode {
                        case .rounds:
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
                        case .amrap:
                            Stepper(
                                AppLocalizer.format("workout.block.duration.value", durationMinutes),
                                value: $durationMinutes,
                                in: 1...90
                            )
                        case .tabata:
                            Stepper(
                                AppLocalizer.format("workout.block.rounds.value", rounds),
                                value: $rounds,
                                in: 1...40
                            )
                            Stepper(
                                AppLocalizer.format("workout.block.work.value", workSeconds),
                                value: $workSeconds,
                                in: 5...120,
                                step: 5
                            )
                            Stepper(
                                AppLocalizer.format("workout.block.rest.value", restSeconds),
                                value: $restSeconds,
                                in: 0...120,
                                step: 5
                            )
                        }
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
            WorkoutTemplateBlockDraft(
                title: title,
                type: type,
                mode: type == .circuit ? mode : .rounds,
                rounds: type == .circuit ? rounds : 1,
                durationMinutes: type == .circuit ? durationMinutes : 0,
                workSeconds: type == .circuit && mode == .tabata ? workSeconds : 0,
                restSeconds: type == .circuit && mode == .tabata ? restSeconds : 0,
                restBetweenRoundsSeconds: type == .circuit && mode == .rounds ? restBetweenRoundsSeconds : 0
            )
        )
        dismiss()
    }
}

private struct WorkoutTemplateExerciseCard: View {
    let exercise: WorkoutTemplateExerciseItem
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(workoutAccentColor(exercise.accentName).opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay {
                            workoutIconImage(
                                named: exercise.systemImage,
                                accentName: exercise.accentName,
                                size: 18
                            )
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(AppLocalizer.format("trainer.templates.exercise.summary", exercise.sets.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Button(action: onEdit) {
                        Label("Редактировать подходы", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Divider()

                    if exercise.note.isEmpty == false {
                        Label(exercise.note, systemImage: "text.bubble")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)

                        Divider()
                    }

                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)

                            Text(
                                formattedWorkoutSetValue(
                                    weight: set.weight,
                                    reps: set.reps,
                                    durationSeconds: set.durationSeconds,
                                    metricType: set.metricType
                                )
                            )
                            .font(.subheadline.weight(.medium))

                            Spacer()
                        }
                        .padding(.vertical, 10)

                        if index < exercise.sets.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(workoutTemplateEditorCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(workoutTemplateEditorBorder)
        )
    }
}
