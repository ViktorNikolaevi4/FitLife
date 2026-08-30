import SwiftUI

struct WorkoutTemplatesScreen: View {
    let trainerId: String

    @StateObject private var store: WorkoutTemplatesStore
    @State private var showCreateSheet = false
    @State private var pendingDeleteTemplate: WorkoutTemplate?
    @State private var selectedCollection: TemplateCollection = .personal
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: WorkoutTemplatesStore(trainerId: trainerId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private enum TemplateCollection: String, CaseIterable, Identifiable {
        case personal
        case library

        var id: String { rawValue }

        var localizationKey: String {
            switch self {
            case .personal: return "trainer.templates.collection.personal"
            case .library: return "trainer.templates.collection.library"
            }
        }
    }

    var body: some View {
        List {
            Picker("", selection: $selectedCollection) {
                ForEach(TemplateCollection.allCases) { collection in
                    Text(appLanguage.localized(collection.localizationKey))
                        .tag(collection)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if selectedCollection == .personal {
                Section(appLanguage.localized("trainer.templates.section")) {
                    ForEach(store.templates) { template in
                        NavigationLink {
                            WorkoutTemplateEditorScreen(template: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(template.title)
                                    .font(.headline)

                                if template.notes.isEmpty == false {
                                    Text(template.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Text(template.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteTemplate = template
                            } label: {
                                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Section(appLanguage.localized("trainer.templates.library.section")) {
                    ForEach(store.libraryTemplates) { template in
                        WorkoutLibraryTemplateRow(
                            template: template,
                            isImported: store.isImported(template),
                            isImporting: store.isImporting(template)
                        ) {
                            Task {
                                _ = await store.importLibraryTemplate(template)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if selectedCollection == .personal && store.templates.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.templates.empty.title"),
                    systemImage: "doc.text",
                    description: Text(appLanguage.localized("trainer.templates.empty.subtitle"))
                )
            } else if selectedCollection == .library && store.libraryTemplates.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.templates.library.empty.title"),
                    systemImage: "books.vertical",
                    description: Text(appLanguage.localized("trainer.templates.library.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.templates.title"))
        .hidesHomeFloatingAddButton()
        .toolbar {
            if selectedCollection == .personal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateWorkoutTemplateScreen { title, notes in
                let didCreate = await store.createTemplate(title: title, notes: notes)
                if didCreate {
                    showCreateSheet = false
                }
            }
        }
        .confirmationDialog(
            AppLocalizer.string("trainer.templates.delete.title"),
            isPresented: Binding(
                get: { pendingDeleteTemplate != nil },
                set: { if $0 == false { pendingDeleteTemplate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                guard let pendingDeleteTemplate else { return }
                Task { await store.deleteTemplate(pendingDeleteTemplate) }
                self.pendingDeleteTemplate = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteTemplate = nil
            }
        } message: {
            Text(AppLocalizer.string("trainer.templates.delete.message"))
        }
    }
}

private struct WorkoutLibraryTemplateRow: View {
    let template: LibraryWorkoutTemplate
    let isImported: Bool
    let isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(template.title)
                        .font(.headline)

                    Text(AppLocalizer.string(template.category.localizationKey))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Button(action: onImport) {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else if isImported {
                        Label(AppLocalizer.string("trainer.templates.library.added"), systemImage: "checkmark")
                    } else {
                        Label(AppLocalizer.string("trainer.templates.library.add"), systemImage: "plus")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isImported || isImporting)
            }

            if template.notes.isEmpty == false {
                Text(template.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if template.authorName.isEmpty == false {
                Label(
                    AppLocalizer.format("trainer.templates.library.author", template.authorName),
                    systemImage: "person.crop.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if template.durationMinutes > 0 {
                    Label(
                        AppLocalizer.format("trainer.templates.library.duration", template.durationMinutes),
                        systemImage: "clock"
                    )
                }
                if template.exerciseCount > 0 {
                    Label(
                        AppLocalizer.format("trainer.overview.exercise_count", template.exerciseCount),
                        systemImage: "figure.strengthtraining.traditional"
                    )
                }
                if template.difficulty.isEmpty == false {
                    Text(template.difficulty)
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private struct CreateWorkoutTemplateScreen: View {
    let onCreate: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    private enum Field {
        case title
        case notes
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appLanguage.localized("trainer.templates.create.section")) {
                    TextField(
                        appLanguage.localized("trainer.templates.create.title_placeholder"),
                        text: $title
                    )
                    .focused($focusedField, equals: .title)

                    TextField(
                        appLanguage.localized("trainer.templates.create.notes_placeholder"),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle(appLanguage.localized("trainer.templates.create.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.add")) {
                        Task {
                            isSaving = true
                            await onCreate(title, notes)
                            isSaving = false
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            focusedField = .title
        }
    }
}
