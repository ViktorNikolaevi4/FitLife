import SwiftUI
import FirebaseFirestore

@MainActor
final class CoachingRequestsReviewStore: ObservableObject {
    @Published private(set) var requests: [CoachingRequest] = []
    @Published private(set) var trainers: [AppUserProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let currentUser: AppUserProfile
    private let firestore: Firestore

    init(currentUser: AppUserProfile, firestore: Firestore = .firestore()) {
        self.currentUser = currentUser
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let requestsSnapshot = firestore
                .collection("coaching_requests")
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            async let trainersSnapshot = firestore
                .collection("users")
                .whereField("role", isEqualTo: AppUserRole.trainer.rawValue)
                .getDocuments()

            let (requestDocs, trainerDocs) = try await (requestsSnapshot, trainersSnapshot)

            requests = requestDocs.documents.compactMap { document in
                CoachingRequest(id: document.documentID, data: document.data())
            }

            trainers = trainerDocs.documents.compactMap { document in
                AppUserProfile(id: document.documentID, data: document.data())
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func displayName(for request: CoachingRequest) -> String {
        request.intakeSnapshot?.clientDisplayName ?? request.clientId
    }

    func subtitle(for request: CoachingRequest) -> String {
        if let email = request.intakeSnapshot?.clientEmail, email.isEmpty == false {
            return email
        }

        return request.clientId
    }

    func assignedTrainer(for request: CoachingRequest) -> AppUserProfile? {
        guard let trainerId = request.assignedTrainerId else { return nil }
        return trainers.first(where: { $0.id == trainerId })
    }

    func approve(_ request: CoachingRequest, trainerId: String? = nil) async -> Bool {
        errorMessage = nil

        let resolvedTrainerId: String?
        switch currentUser.role {
        case .trainer:
            resolvedTrainerId = currentUser.id
        case .owner:
            resolvedTrainerId = trainerId ?? request.assignedTrainerId
        case .client:
            resolvedTrainerId = nil
        }

        guard let resolvedTrainerId else {
            errorMessage = AppLocalizer.string("coaching.review.error.trainer_required")
            return false
        }

        let now = Date()
        let updatedRequest = CoachingRequest(
            id: request.id,
            clientId: request.clientId,
            status: .assigned,
            reviewComment: request.reviewComment,
            assignedTrainerId: resolvedTrainerId,
            intakeSnapshot: request.intakeSnapshot,
            updatedAt: now,
            submittedAt: request.submittedAt
        )

        let link = TrainerClientLink(
            id: "\(resolvedTrainerId)_\(request.clientId)",
            trainerId: resolvedTrainerId,
            clientId: request.clientId,
            createdAt: now,
            createdByOwnerId: currentUser.id,
            status: "active"
        )

        let batch = firestore.batch()
        batch.setData(updatedRequest.firestoreData, forDocument: firestore.collection("coaching_requests").document(request.id), merge: true)
        batch.setData(link.firestoreData, forDocument: firestore.collection("trainer_client_links").document(link.id), merge: true)

        do {
            try await batch.commit()
            try? await AppNotificationEventWriter.create(
                type: .coachingRequestApproved,
                recipientId: request.clientId,
                senderId: currentUser.id,
                senderName: currentUser.displayName,
                targetType: .coachingConnection,
                targetId: request.id,
                firestore: firestore
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func requestClarification(for request: CoachingRequest, comment: String) async -> Bool {
        await update(request: request, status: .needsClarification, comment: comment)
    }

    func reject(_ request: CoachingRequest, comment: String) async -> Bool {
        await update(request: request, status: .rejected, comment: comment)
    }

    private func update(request: CoachingRequest, status: CoachingRequestStatus, comment: String) async -> Bool {
        errorMessage = nil

        let updatedRequest = CoachingRequest(
            id: request.id,
            clientId: request.clientId,
            status: status,
            reviewComment: comment,
            assignedTrainerId: request.assignedTrainerId,
            intakeSnapshot: request.intakeSnapshot,
            updatedAt: .now,
            submittedAt: request.submittedAt
        )

        do {
            try await firestore
                .collection("coaching_requests")
                .document(request.id)
                .setData(updatedRequest.firestoreData, merge: true)
            if status == .rejected {
                try? await AppNotificationEventWriter.create(
                    type: .coachingRequestRejected,
                    recipientId: request.clientId,
                    senderId: currentUser.id,
                    senderName: currentUser.displayName,
                    targetType: .coachingRequest,
                    targetId: request.id,
                    firestore: firestore
                )
            }
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct CoachingRequestsReviewScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var store: CoachingRequestsReviewStore

    init(currentUser: AppUserProfile) {
        _store = StateObject(wrappedValue: CoachingRequestsReviewStore(currentUser: currentUser))
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

            Section(AppLocalizer.string("coaching.review.section")) {
                ForEach(store.requests) { request in
                    NavigationLink {
                        CoachingRequestDetailScreen(
                            request: request,
                            currentUser: sessionStore.profile,
                            trainers: store.trainers,
                            onApprove: { trainerId in
                                await store.approve(request, trainerId: trainerId)
                            },
                            onClarify: { comment in
                                await store.requestClarification(for: request, comment: comment)
                            },
                            onReject: { comment in
                                await store.reject(request, comment: comment)
                            }
                        )
                    } label: {
                        CoachingRequestRow(
                            request: request,
                            displayName: store.displayName(for: request),
                            subtitle: store.subtitle(for: request),
                            assignedTrainer: store.assignedTrainer(for: request)
                        )
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.requests.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("coaching.review.empty.title"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(AppLocalizer.string("coaching.review.empty.subtitle"))
                )
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.review.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

private struct CoachingRequestRow: View {
    let request: CoachingRequest
    let displayName: String
    let subtitle: String
    let assignedTrainer: AppUserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayName)
                    .font(.headline)
                Spacer()
                Text(AppLocalizer.string(request.status.localizationKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let assignedTrainer {
                Text("\(AppLocalizer.string("coaching.review.assigned_trainer")): \(assignedTrainer.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch request.status {
        case .draft: .secondary
        case .submitted: .blue
        case .needsClarification: .orange
        case .approved, .assigned: .green
        case .rejected: .red
        }
    }
}

private struct CoachingRequestDetailScreen: View {
    let request: CoachingRequest
    let currentUser: AppUserProfile?
    let trainers: [AppUserProfile]
    let onApprove: (String?) async -> Bool
    let onClarify: (String) async -> Bool
    let onReject: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrainerId: String?
    @State private var reviewComment = ""
    @State private var isSubmitting = false

    var body: some View {
        Form {
            if let intake = request.intakeSnapshot {
                Section(AppLocalizer.string("coaching.review.client.section")) {
                    reviewRow(AppLocalizer.string("coaching.review.client.name"), intake.clientDisplayName)
                    reviewRow(AppLocalizer.string("coaching.review.client.email"), intake.clientEmail)
                    reviewRow(AppLocalizer.string("coaching.intake.goal"), AppLocalizer.string(intake.goal.localizationKey))
                    reviewRow(AppLocalizer.string("coaching.intake.age"), "\(intake.age)")
                    reviewRow(AppLocalizer.string("coaching.intake.height"), "\(Int(intake.height)) \(AppLocalizer.string("coaching.unit.cm"))")
                    reviewRow(AppLocalizer.string("coaching.intake.weight"), String(format: "%.1f %@", intake.weight, AppLocalizer.string("coaching.unit.kg")))
                    reviewRow(AppLocalizer.string("coaching.intake.sex"), AppLocalizer.string(intake.sex.localizationKey))
                    reviewRow(AppLocalizer.string("coaching.intake.activity"), AppLocalizer.string(intake.activity.localizationKey))
                    reviewRow(AppLocalizer.string("coaching.intake.experience"), AppLocalizer.string(intake.experience.localizationKey))
                }

                Section(AppLocalizer.string("coaching.review.context.section")) {
                    multilineRow(AppLocalizer.string("coaching.intake.limitations"), intake.limitations)
                    multilineRow(AppLocalizer.string("coaching.intake.equipment"), intake.equipment)
                    multilineRow(AppLocalizer.string("coaching.intake.schedule"), intake.schedule)
                    multilineRow(AppLocalizer.string("coaching.intake.notes"), intake.notes)
                }

                Section(AppLocalizer.string("coaching.review.measurements.section")) {
                    reviewRow(AppLocalizer.string("coaching.intake.measurement.waist"), String(format: "%.1f %@", intake.measurements.waist, AppLocalizer.string("coaching.unit.cm")))
                    reviewRow(AppLocalizer.string("coaching.intake.measurement.chest"), String(format: "%.1f %@", intake.measurements.chest, AppLocalizer.string("coaching.unit.cm")))
                    reviewRow(AppLocalizer.string("coaching.intake.measurement.hips"), String(format: "%.1f %@", intake.measurements.hips, AppLocalizer.string("coaching.unit.cm")))
                }
            }

            Section(AppLocalizer.string("coaching.review.decision.section")) {
                if currentUser?.role == .owner {
                    Picker(AppLocalizer.string("coaching.review.select_trainer"), selection: $selectedTrainerId) {
                        Text(AppLocalizer.string("coaching.review.select_trainer.placeholder"))
                            .tag(Optional<String>.none)
                        ForEach(trainers.filter { $0.isActive }) { trainer in
                            Text(trainer.displayName).tag(Optional(trainer.id))
                        }
                    }
                } else if let currentUser, currentUser.role == .trainer {
                    reviewRow(AppLocalizer.string("coaching.review.assigned_trainer"), currentUser.displayName)
                }

                TextField(AppLocalizer.string("coaching.review.comment.placeholder"), text: $reviewComment, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                if request.status == .assigned {
                    Text(AppLocalizer.string("coaching.review.assigned.readonly"))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await submitApprove() }
                    } label: {
                        actionLabel(AppLocalizer.string("coaching.review.action.approve"))
                    }
                    .disabled(isApproveDisabled || isSubmitting)

                    Button {
                        Task { await submitClarification() }
                    } label: {
                        actionLabel(AppLocalizer.string("coaching.review.action.clarify"))
                    }
                    .disabled(isSubmitting)

                    Button(role: .destructive) {
                        Task { await submitReject() }
                    } label: {
                        actionLabel(AppLocalizer.string("coaching.review.action.reject"))
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.review.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedTrainerId = request.assignedTrainerId
            reviewComment = request.reviewComment
        }
    }

    private var isApproveDisabled: Bool {
        if currentUser?.role == .owner {
            return selectedTrainerId == nil
        }
        return false
    }

    private var effectiveComment: String {
        let trimmed = reviewComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    @ViewBuilder
    private func actionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSubmitting {
                ProgressView()
            }
        }
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 12)
            Text(value.isEmpty ? "—" : value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func multilineRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.secondary)
        }
    }

    private func submitApprove() async {
        isSubmitting = true
        let succeeded = await onApprove(selectedTrainerId)
        isSubmitting = false
        if succeeded {
            dismiss()
        }
    }

    private func submitClarification() async {
        isSubmitting = true
        let succeeded = await onClarify(effectiveComment)
        isSubmitting = false
        if succeeded {
            dismiss()
        }
    }

    private func submitReject() async {
        isSubmitting = true
        let succeeded = await onReject(effectiveComment)
        isSubmitting = false
        if succeeded {
            dismiss()
        }
    }
}
