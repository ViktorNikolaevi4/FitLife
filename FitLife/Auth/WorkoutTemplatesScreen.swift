import SwiftUI

struct WorkoutTemplatesScreen: View {
    let trainerId: String

    @StateObject private var store: WorkoutTemplatesStore
    @State private var showCreateSheet = false
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: WorkoutTemplatesStore(trainerId: trainerId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
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
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.templates.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.templates.empty.title"),
                    systemImage: "doc.text",
                    description: Text(appLanguage.localized("trainer.templates.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.templates.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
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
