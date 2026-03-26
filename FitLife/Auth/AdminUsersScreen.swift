import SwiftUI

struct AdminUsersScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var store = AdminUsersStore()
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

            Section(appLanguage.localized("admin.users.section")) {
                ForEach(store.users) { user in
                    AdminUserRow(
                        user: user,
                        isCurrentUser: user.id == sessionStore.firebaseUser?.uid,
                        onChangeRole: { role in
                            Task { await store.updateRole(for: user, to: role) }
                        }
                    )
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.users.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("admin.users.empty.title"),
                    systemImage: "person.3",
                    description: Text(appLanguage.localized("admin.users.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("admin.users.title"))
        .task {
            await store.loadUsers()
        }
        .refreshable {
            await store.loadUsers()
        }
    }
}

private struct AdminUserRow: View {
    let user: AppUserProfile
    let isCurrentUser: Bool
    let onChangeRole: (AppUserRole) -> Void

    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(roleColor.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: roleIcon)
                        .foregroundStyle(roleColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.headline)

                    if isCurrentUser {
                        Text(appLanguage.localized("admin.users.current_user"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(AppLocalizer.string(user.role.localizationKey))
                    .font(.caption)
                    .foregroundStyle(roleColor)
            }

            Spacer(minLength: 12)

            if user.role == .owner {
                Text(AppLocalizer.string(user.role.localizationKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    Button(AppLocalizer.string("role.client")) {
                        onChangeRole(.client)
                    }

                    Button(AppLocalizer.string("role.trainer")) {
                        onChangeRole(.trainer)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var roleColor: Color {
        switch user.role {
        case .owner: .orange
        case .trainer: .blue
        case .client: .secondary
        }
    }

    private var roleIcon: String {
        switch user.role {
        case .owner: "crown.fill"
        case .trainer: "figure.strengthtraining.traditional"
        case .client: "person.fill"
        }
    }
}
