import SwiftUI

struct TrainerAssignedClientsScreen: View {
    let trainerId: String

    @StateObject private var store: TrainerAssignedClientsStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAssignedClientsStore(trainerId: trainerId))
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

            Section(appLanguage.localized("trainer.clients.section")) {
                ForEach(store.clients) { client in
                    NavigationLink {
                        TrainerClientSupportScreen(trainerId: trainerId, client: client)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.green.opacity(0.14))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.green)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.displayName)
                                    .font(.headline)
                                Text(client.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.clients.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.clients.empty.title"),
                    systemImage: "person.2",
                    description: Text(appLanguage.localized("trainer.clients.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.clients.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}
