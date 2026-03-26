import SwiftUI

struct TrainerClientLinksScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var store = TrainerClientLinksStore()
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

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

            Section(appLanguage.localized("admin.links.section")) {
                ForEach(store.trainers) { trainer in
                    NavigationLink {
                        if let ownerId = sessionStore.firebaseUser?.uid {
                            TrainerClientsScreen(trainer: trainer, ownerId: ownerId)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundStyle(.blue)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(trainer.displayName)
                                    .font(.headline)
                                Text(trainer.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(
                                String(
                                    format: appLanguage.localized("admin.links.assigned_count"),
                                    store.activeClientCount(for: trainer.id)
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.trainers.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("admin.links.empty.title"),
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text(appLanguage.localized("admin.links.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("admin.links.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

private struct TrainerClientsScreen: View {
    let trainer: AppUserProfile
    let ownerId: String

    @StateObject private var store: TrainerClientsStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainer: AppUserProfile, ownerId: String) {
        self.trainer = trainer
        self.ownerId = ownerId
        _store = StateObject(wrappedValue: TrainerClientsStore(trainer: trainer, ownerId: ownerId))
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

            Section(
                String(
                    format: appLanguage.localized("admin.links.clients_for"),
                    trainer.displayName
                )
            ) {
                ForEach(store.clients) { client in
                    Toggle(isOn: binding(for: client)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.displayName)
                                .font(.headline)
                            Text(client.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .toggleStyle(.switch)
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.clients.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("admin.links.clients.empty.title"),
                    systemImage: "person.2",
                    description: Text(appLanguage.localized("admin.links.clients.empty.subtitle"))
                )
            }
        }
        .navigationTitle(trainer.displayName)
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }

    private func binding(for client: AppUserProfile) -> Binding<Bool> {
        Binding(
            get: { store.isAssigned(clientId: client.id) },
            set: { newValue in
                Task {
                    await store.setAssignment(for: client, isAssigned: newValue)
                }
            }
        )
    }
}
