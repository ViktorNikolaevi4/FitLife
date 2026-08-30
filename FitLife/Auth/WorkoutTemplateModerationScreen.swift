import SwiftUI
import FirebaseFirestore

@MainActor
final class WorkoutTemplateModerationStore: ObservableObject {
    @Published private(set) var submissions: [WorkoutTemplateSubmission] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let firestore: Firestore

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    var pendingSubmissions: [WorkoutTemplateSubmission] {
        submissions.filter { $0.status == .pending }
    }

    var reviewedSubmissions: [WorkoutTemplateSubmission] {
        submissions.filter { $0.status != .pending }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await firestore
                .collection("workout_template_submissions")
                .getDocuments()
            submissions = snapshot.documents
                .compactMap { WorkoutTemplateSubmission(id: $0.documentID, data: $0.data()) }
                .sorted {
                    if $0.status == .pending && $1.status != .pending { return true }
                    if $0.status != .pending && $1.status == .pending { return false }
                    return $0.submittedAt > $1.submittedAt
                }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

@MainActor
final class WorkoutTemplateSubmissionDetailStore: ObservableObject {
    @Published private(set) var blocks: [WorkoutTemplateBlockItem] = []
    @Published private(set) var exercises: [WorkoutTemplateExerciseItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isReviewing = false
    @Published var errorMessage: String?

    let submission: WorkoutTemplateSubmission
    private let firestore: Firestore

    init(
        submission: WorkoutTemplateSubmission,
        firestore: Firestore = .firestore()
    ) {
        self.submission = submission
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let ref = firestore
                .collection("workout_template_submissions")
                .document(submission.id)
            async let blockSnapshot = ref.collection("blocks").getDocuments()
            async let exerciseSnapshot = ref.collection("exercises").getDocuments()
            let (blockDocs, exerciseDocs) = try await (blockSnapshot, exerciseSnapshot)

            blocks = blockDocs.documents
                .compactMap {
                    WorkoutTemplateBlockItem(
                        id: $0.documentID,
                        templateId: submission.id,
                        data: $0.data()
                    )
                }
                .sorted { $0.orderIndex < $1.orderIndex }
            exercises = exerciseDocs.documents
                .compactMap {
                    WorkoutTemplateExerciseItem(
                        id: $0.documentID,
                        templateId: submission.id,
                        data: $0.data()
                    )
                }
                .sorted { $0.orderIndex < $1.orderIndex }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func approve(reviewerID: String) async -> Bool {
        guard submission.status == .pending,
              exercises.isEmpty == false,
              isReviewing == false else { return false }
        isReviewing = true
        defer { isReviewing = false }
        errorMessage = nil

        let submissionRef = firestore
            .collection("workout_template_submissions")
            .document(submission.id)
        let libraryRef = firestore
            .collection("workout_template_library")
            .document(submission.id)
        let now = Date()

        do {
            let batch = firestore.batch()
            batch.setData(
                [
                    "title": submission.title,
                    "notes": submission.notes,
                    "category": libraryCategory.rawValue,
                    "difficulty": "",
                    "durationMinutes": estimatedDurationMinutes,
                    "exerciseCount": exercises.count,
                    "sortOrder": Int(now.timeIntervalSince1970),
                    "isActive": true,
                    "authorName": submission.trainerName,
                    "contributorTrainerId": submission.trainerId,
                    "sourceSubmissionId": submission.id,
                    "updatedAt": now
                ],
                forDocument: libraryRef
            )
            for block in blocks {
                batch.setData(
                    block.firestoreData,
                    forDocument: libraryRef.collection("blocks").document(block.id)
                )
            }
            for exercise in exercises {
                batch.setData(
                    exercise.firestoreData,
                    forDocument: libraryRef.collection("exercises").document(exercise.id)
                )
            }
            batch.setData(
                [
                    "status": WorkoutTemplateSubmissionStatus.approved.rawValue,
                    "reviewedAt": now,
                    "reviewedBy": reviewerID,
                    "reviewNote": "",
                    "publishedTemplateId": libraryRef.documentID
                ],
                forDocument: submissionRef,
                merge: true
            )
            try await batch.commit()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func reject(reviewerID: String, note: String) async -> Bool {
        guard submission.status == .pending, isReviewing == false else { return false }
        isReviewing = true
        defer { isReviewing = false }
        errorMessage = nil

        do {
            try await firestore
                .collection("workout_template_submissions")
                .document(submission.id)
                .setData(
                    [
                        "status": WorkoutTemplateSubmissionStatus.rejected.rawValue,
                        "reviewedAt": Date(),
                        "reviewedBy": reviewerID,
                        "reviewNote": note.trimmingCharacters(in: .whitespacesAndNewlines)
                    ],
                    merge: true
                )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var libraryCategory: WorkoutLibraryCategory {
        guard let firstBlock = blocks.first else { return .other }
        switch firstBlock.preset {
        case .warmup: return .warmup
        case .strength, .superset, .pyramid, .dropSet, .clusterSet: return .strength
        case .mobility, .stretching: return .mobility
        case .cooldown: return .cooldown
        case .circuit, .hiit, .tabata, .amrap, .emom, .e2mom, .e3mom, .forTime, .rft, .ladder:
            return .crossTraining
        }
    }

    private var estimatedDurationMinutes: Int {
        blocks.reduce(0) { total, block in
            switch block.preset {
            case .amrap, .emom, .e2mom, .e3mom:
                return total + max(block.durationMinutes, 0)
            case .tabata:
                let seconds = max(block.rounds, 1) * max(block.workSeconds + block.restSeconds, 0)
                return total + Int(ceil(Double(seconds) / 60.0))
            default:
                return total
            }
        }
    }
}

struct WorkoutTemplateModerationScreen: View {
    @StateObject private var store = WorkoutTemplateModerationStore()

    var body: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(AppLocalizer.string("admin.template_moderation.pending.section")) {
                ForEach(store.pendingSubmissions) { submission in
                    NavigationLink {
                        WorkoutTemplateSubmissionDetailScreen(submission: submission)
                    } label: {
                        WorkoutTemplateSubmissionRow(submission: submission)
                    }
                }
            }

            if store.reviewedSubmissions.isEmpty == false {
                Section(AppLocalizer.string("admin.template_moderation.history.section")) {
                    ForEach(store.reviewedSubmissions) { submission in
                        NavigationLink {
                            WorkoutTemplateSubmissionDetailScreen(submission: submission)
                        } label: {
                            WorkoutTemplateSubmissionRow(submission: submission)
                        }
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("admin.template_moderation.title"))
        .hidesHomeFloatingAddButton()
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.submissions.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("admin.template_moderation.empty.title"),
                    systemImage: "checkmark.seal",
                    description: Text(AppLocalizer.string("admin.template_moderation.empty.subtitle"))
                )
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
    }
}

private struct WorkoutTemplateSubmissionRow: View {
    let submission: WorkoutTemplateSubmission

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(submission.title)
                    .font(.headline)
                Spacer()
                Text(AppLocalizer.string(submission.status.localizationKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            Text(submission.trainerName.isEmpty ? submission.trainerId : submission.trainerName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(
                AppLocalizer.format(
                    "admin.template_moderation.row.meta",
                    submission.exerciseCount,
                    submission.submittedAt.formatted(date: .abbreviated, time: .shortened)
                )
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch submission.status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

private struct WorkoutTemplateSubmissionDetailScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: WorkoutTemplateSubmissionDetailStore
    @State private var showApproveConfirmation = false
    @State private var showRejectSheet = false

    init(submission: WorkoutTemplateSubmission) {
        _store = StateObject(
            wrappedValue: WorkoutTemplateSubmissionDetailStore(submission: submission)
        )
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(AppLocalizer.string("admin.template_moderation.details.section")) {
                LabeledContent(
                    AppLocalizer.string("admin.template_moderation.author"),
                    value: store.submission.trainerName.isEmpty
                        ? store.submission.trainerId
                        : store.submission.trainerName
                )
                LabeledContent(
                    AppLocalizer.string("admin.template_moderation.status"),
                    value: AppLocalizer.string(store.submission.status.localizationKey)
                )
                if store.submission.notes.isEmpty == false {
                    Text(store.submission.notes)
                        .foregroundStyle(.secondary)
                }
                if store.submission.reviewNote.isEmpty == false {
                    LabeledContent(AppLocalizer.string("admin.template_moderation.review_note")) {
                        Text(store.submission.reviewNote)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            ForEach(store.blocks) { block in
                Section(block.displayTitle) {
                    ForEach(store.exercises.filter { $0.blockId == block.id }) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                            Text(exerciseSummary(exercise))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            let ungrouped = store.exercises.filter { $0.blockId == nil }
            if ungrouped.isEmpty == false {
                Section(AppLocalizer.string("trainer.templates.exercises.section")) {
                    ForEach(ungrouped) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                            Text(exerciseSummary(exercise))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if store.submission.status == .pending {
                Section {
                    Button(AppLocalizer.string("admin.template_moderation.approve")) {
                        showApproveConfirmation = true
                    }
                    .disabled(store.isReviewing || store.exercises.isEmpty)

                    Button(
                        AppLocalizer.string("admin.template_moderation.reject"),
                        role: .destructive
                    ) {
                        showRejectSheet = true
                    }
                    .disabled(store.isReviewing)
                }
            }
        }
        .navigationTitle(store.submission.title)
        .hidesHomeFloatingAddButton()
        .overlay {
            if store.isLoading || store.isReviewing {
                ProgressView()
            }
        }
        .task { await store.load() }
        .confirmationDialog(
            AppLocalizer.string("admin.template_moderation.approve.confirm.title"),
            isPresented: $showApproveConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("admin.template_moderation.approve")) {
                Task {
                    guard let reviewerID = sessionStore.firebaseUser?.uid else { return }
                    if await store.approve(reviewerID: reviewerID) {
                        dismiss()
                    }
                }
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalizer.string("admin.template_moderation.approve.confirm.message"))
        }
        .sheet(isPresented: $showRejectSheet) {
            RejectWorkoutTemplateSubmissionSheet { note in
                guard let reviewerID = sessionStore.firebaseUser?.uid else { return false }
                let didReject = await store.reject(reviewerID: reviewerID, note: note)
                if didReject { dismiss() }
                return didReject
            }
        }
    }

    private func exerciseSummary(_ exercise: WorkoutTemplateExerciseItem) -> String {
        guard let firstSet = exercise.sets.first else { return "—" }
        if firstSet.metricType == .duration {
            return AppLocalizer.format(
                "admin.template_moderation.exercise.duration",
                exercise.sets.count,
                firstSet.durationSeconds
            )
        }
        return AppLocalizer.format(
            "admin.template_moderation.exercise.reps",
            exercise.sets.count,
            firstSet.reps
        )
    }
}

private struct RejectWorkoutTemplateSubmissionSheet: View {
    let onReject: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalizer.string("admin.template_moderation.reject.reason.section")) {
                    TextField(
                        AppLocalizer.string("admin.template_moderation.reject.reason.placeholder"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle(AppLocalizer.string("admin.template_moderation.reject.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("admin.template_moderation.reject"), role: .destructive) {
                        Task {
                            isSubmitting = true
                            if await onReject(note) { dismiss() }
                            isSubmitting = false
                        }
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
