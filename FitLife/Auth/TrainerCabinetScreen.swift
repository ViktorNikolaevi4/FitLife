import SwiftUI

struct TrainerCabinetScreen: View {
    let trainerId: String
    let currentUser: AppUserProfile

    @StateObject private var attentionStore: TrainerAttentionStore

    init(trainerId: String, currentUser: AppUserProfile) {
        self.trainerId = trainerId
        self.currentUser = currentUser
        _attentionStore = StateObject(
            wrappedValue: TrainerAttentionStore(trainerId: trainerId)
        )
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TrainerAttentionScreen(trainerId: trainerId)
                } label: {
                    attentionSummary
                }
            }

            Section(AppLocalizer.string("trainer.cabinet.clients.section")) {
                NavigationLink {
                    TrainerAssignedClientsScreen(trainerId: trainerId)
                } label: {
                    TrainerCabinetRow(
                        icon: "person.2.fill",
                        tint: .green,
                        title: AppLocalizer.string("settings.trainer.clients"),
                        subtitle: AppLocalizer.format(
                            "trainer.cabinet.clients.count",
                            attentionStore.allClientCount
                        )
                    )
                }

                NavigationLink {
                    CoachingRequestsReviewScreen(currentUser: currentUser)
                } label: {
                    TrainerCabinetRow(
                        icon: "text.badge.checkmark",
                        tint: .mint,
                        title: AppLocalizer.string("settings.trainer.requests"),
                        subtitle: AppLocalizer.string("trainer.cabinet.requests.subtitle")
                    )
                }
            }

            Section(AppLocalizer.string("trainer.cabinet.work.section")) {
                NavigationLink {
                    WorkoutTemplatesScreen(trainerId: trainerId)
                } label: {
                    TrainerCabinetRow(
                        icon: "doc.text.fill",
                        tint: .orange,
                        title: AppLocalizer.string("settings.trainer.templates"),
                        subtitle: AppLocalizer.string("trainer.cabinet.templates.subtitle")
                    )
                }

                NavigationLink {
                    TrainerAssignmentsOverviewScreen(trainerId: trainerId)
                } label: {
                    TrainerCabinetRow(
                        icon: "list.bullet.clipboard",
                        tint: .pink,
                        title: AppLocalizer.string("settings.trainer.assignments"),
                        subtitle: AppLocalizer.string("trainer.cabinet.assignments.subtitle")
                    )
                }
            }
        }
        .navigationTitle(AppLocalizer.string("trainer.cabinet.title"))
        .hidesHomeFloatingAddButton()
        .task {
            await attentionStore.load()
        }
        .refreshable {
            await attentionStore.load()
        }
    }

    private var attentionSummary: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(attentionTint.opacity(0.16))
                    .frame(width: 52, height: 52)

                if attentionStore.isLoading && attentionStore.items.isEmpty {
                    ProgressView()
                        .tint(attentionTint)
                } else {
                    Image(systemName: attentionIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(attentionTint)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.string("settings.trainer.attention"))
                    .font(.headline)

                Text(attentionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if attentionStore.isLoading == false && attentionStore.items.isEmpty == false {
                Text(attentionStore.items.count.formatted())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 32, minHeight: 32)
                    .background(attentionTint, in: Circle())
            }
        }
        .padding(.vertical, 6)
    }

    private var attentionTint: Color {
        attentionStore.items.isEmpty ? .green : .red
    }

    private var attentionIcon: String {
        attentionStore.items.isEmpty
            ? "checkmark.seal.fill"
            : "exclamationmark.bubble.fill"
    }

    private var attentionSubtitle: String {
        if let errorMessage = attentionStore.errorMessage,
           errorMessage.isEmpty == false {
            return AppLocalizer.string("trainer.cabinet.attention.error")
        }

        if attentionStore.isLoading && attentionStore.items.isEmpty {
            return AppLocalizer.string("trainer.cabinet.attention.loading")
        }

        if attentionStore.items.isEmpty {
            return AppLocalizer.string("trainer.cabinet.attention.empty")
        }

        return AppLocalizer.format(
            "trainer.cabinet.attention.count",
            attentionStore.items.count
        )
    }
}

private struct TrainerCabinetRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
