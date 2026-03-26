import SwiftUI

struct TrainerAssignmentsOverviewScreen: View {
    let trainerId: String

    @StateObject private var store: TrainerAssignmentsOverviewStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAssignmentsOverviewStore(trainerId: trainerId))
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

            ForEach([WorkoutAssignmentStatus.assigned, .started, .completed], id: \.rawValue) { status in
                let items = store.assignments(for: status)
                if items.isEmpty == false {
                    Section(AppLocalizer.string(status.localizationKey)) {
                        ForEach(items) { assignment in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(assignment.titleSnapshot)
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    if let clientName = store.clientName(for: assignment.clientId) {
                                        Text(
                                            AppLocalizer.format(
                                                "trainer.overview.client",
                                                clientName
                                            )
                                        )
                                    }

                                    Text(
                                        AppLocalizer.format(
                                            "trainer.overview.exercise_count",
                                            assignment.exerciseCount
                                        )
                                    )
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Text(assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.assignments.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.overview.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("trainer.overview.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.overview.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

