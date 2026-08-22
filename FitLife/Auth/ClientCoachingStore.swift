import Foundation
import FirebaseFirestore

@MainActor
final class ClientCoachingStore: ObservableObject {
    @Published var intake: ClientIntakeProfile?
    @Published var request: CoachingRequest?
    @Published var activeLink: TrainerClientLink?
    @Published var trainerProfile: AppUserProfile?
    @Published var latestNote: CoachingNote?
    @Published var latestActiveAssignment: WorkoutAssignment?
    @Published var isLoading = false
    @Published private(set) var hasLoadedInitialState = false
    @Published private(set) var isUsingCachedData = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let clientId: String
    private let firestore: Firestore
    private var trainerProfileListener: ListenerRegistration?

    init(clientId: String, firestore: Firestore = .firestore()) {
        self.clientId = clientId
        self.firestore = firestore
        restoreCachedConnection()

        if let link = activeLink {
            observeTrainerProfile(for: link)
        }
    }

    deinit {
        trainerProfileListener?.remove()
    }

    func load(
        profile: AppUserProfile,
        localUserData: UserData? = nil,
        latestMeasurements: BodyMeasurements? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        if intake == nil {
            intake = makeIntake(
                profile: profile,
                localUserData: localUserData,
                latestMeasurements: latestMeasurements
            )
        }

        defer {
            hasLoadedInitialState = true
            isLoading = false
        }

        async let supportingData: Void = refreshSupportingData(
            profile: profile,
            localUserData: localUserData,
            latestMeasurements: latestMeasurements
        )

        var connectionWasLoadedFromServer = false
        do {
            let snapshot = try await activeLinksQuery.getDocuments(source: .server)
            connectionWasLoadedFromServer = true

            if let document = snapshot.documents.first,
               let link = TrainerClientLink(id: document.documentID, data: document.data()) {
                applyActiveConnection(link)
            } else {
                clearActiveConnection()
            }
        } catch {
            if activeLink == nil {
                await restoreConnectionFromFirestoreCache()
            }

            if activeLink == nil {
                errorMessage = AppErrorPresenter.message(for: error)
            }
        }

        var trainerContentWasLoadedFromServer = false
        if let link = activeLink {
            trainerContentWasLoadedFromServer = await refreshTrainerContent(for: link)
        }

        isUsingCachedData = activeLink != nil &&
            !(connectionWasLoadedFromServer && trainerContentWasLoadedFromServer)

        await supportingData
    }

    private var activeLinksQuery: Query {
        firestore
            .collection("trainer_client_links")
            .whereField("clientId", isEqualTo: clientId)
            .whereField("status", isEqualTo: "active")
    }

    private func refreshSupportingData(
        profile: AppUserProfile,
        localUserData: UserData?,
        latestMeasurements: BodyMeasurements?
    ) async {
        async let intakeRequest = try? firestore
            .collection("client_intakes")
            .document(clientId)
            .getDocument()
        async let coachingRequest = try? firestore
            .collection("coaching_requests")
            .document(clientId)
            .getDocument()

        let (intakeDocument, requestDocument) = await (intakeRequest, coachingRequest)

        if let intakeDocument,
           let data = intakeDocument.data(),
           let intake = ClientIntakeProfile(id: intakeDocument.documentID, data: data) {
            self.intake = intake
        } else if self.intake == nil {
            self.intake = makeIntake(
                profile: profile,
                localUserData: localUserData,
                latestMeasurements: latestMeasurements
            )
        }

        if let requestDocument {
            if let data = requestDocument.data(),
               let request = CoachingRequest(id: requestDocument.documentID, data: data) {
                self.request = request
            } else if requestDocument.exists == false {
                self.request = nil
            }
        }
    }

    private func refreshTrainerContent(for link: TrainerClientLink) async -> Bool {
        _ = await applyTrainerContent(for: link, source: .cache)
        let serverResults = await applyTrainerContent(for: link, source: .server)

        if trainerProfile?.id == link.trainerId {
            persistConnection(link)
        }
        return serverResults
    }

    private func applyTrainerContent(
        for link: TrainerClientLink,
        source: FirestoreSource
    ) async -> Bool {
        async let trainerRequest = try? firestore
            .collection("users")
            .document(link.trainerId)
            .getDocument(source: source)
        async let notesRequest = try? firestore
            .collection("coaching_notes")
            .whereField("clientId", isEqualTo: clientId)
            .whereField("trainerId", isEqualTo: link.trainerId)
            .getDocuments(source: source)
        async let assignmentsRequest = try? firestore
            .collection("workout_assignments")
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "assignedAt", descending: true)
            .getDocuments(source: source)

        let (trainerSnapshot, notesSnapshot, assignmentsSnapshot) = await (
            trainerRequest,
            notesRequest,
            assignmentsRequest
        )

        if let trainerSnapshot,
           let data = trainerSnapshot.data(),
           let trainer = AppUserProfile(id: trainerSnapshot.documentID, data: data) {
            trainerProfile = trainer
        }

        if let notesSnapshot {
            latestNote = notesSnapshot.documents
                .compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
                .filter { $0.authorRole == .trainer }
                .max { $0.createdAt < $1.createdAt }
        }

        if let assignmentsSnapshot {
            latestActiveAssignment = assignmentsSnapshot.documents
                .compactMap { WorkoutAssignment(id: $0.documentID, data: $0.data()) }
                .first {
                    $0.trainerId == link.trainerId &&
                    ($0.status == .assigned || $0.status == .started)
                }
        }

        return trainerSnapshot != nil && notesSnapshot != nil && assignmentsSnapshot != nil
    }

    private func restoreConnectionFromFirestoreCache() async {
        guard
            let snapshot = try? await activeLinksQuery.getDocuments(source: .cache),
            let document = snapshot.documents.first,
            let link = TrainerClientLink(id: document.documentID, data: document.data())
        else {
            return
        }

        applyActiveConnection(link)
    }

    private func applyActiveConnection(_ link: TrainerClientLink) {
        if activeLink?.trainerId != link.trainerId {
            trainerProfile = nil
            latestNote = nil
            latestActiveAssignment = nil
        }
        activeLink = link
        persistConnection(link)
        observeTrainerProfile(for: link)
    }

    private func clearActiveConnection() {
        trainerProfileListener?.remove()
        trainerProfileListener = nil
        activeLink = nil
        trainerProfile = nil
        latestNote = nil
        latestActiveAssignment = nil
        isUsingCachedData = false
        UserDefaults.standard.removeObject(forKey: connectionCacheKey)
    }

    private func observeTrainerProfile(for link: TrainerClientLink) {
        trainerProfileListener?.remove()
        trainerProfileListener = firestore
            .collection("users")
            .document(link.trainerId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard
                    let self,
                    let snapshot,
                    let data = snapshot.data(),
                    let trainer = AppUserProfile(id: snapshot.documentID, data: data)
                else {
                    return
                }

                Task { @MainActor in
                    guard self.activeLink?.trainerId == trainer.id else { return }
                    self.trainerProfile = trainer
                    self.persistConnection(link)
                }
            }
    }

    private var connectionCacheKey: String {
        "fitlife.dashboard.trainer-connection.\(clientId)"
    }

    private func persistConnection(_ link: TrainerClientLink) {
        let trainer = trainerProfile?.id == link.trainerId ? trainerProfile : nil
        let snapshot = CachedTrainerConnection(
            linkId: link.id,
            trainerId: link.trainerId,
            clientId: link.clientId,
            createdAt: link.createdAt,
            createdByOwnerId: link.createdByOwnerId,
            trainerDisplayName: trainer?.displayName,
            trainerCreatedAt: trainer?.createdAt,
            trainerIsActive: trainer?.isActive,
            trainerPhotoURL: trainer?.photoURL,
            latestNote: latestNote.map(CachedCoachingNote.init),
            latestAssignment: latestActiveAssignment.map(CachedWorkoutAssignment.init)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: connectionCacheKey)
    }

    private func restoreCachedConnection() {
        guard
            let data = UserDefaults.standard.data(forKey: connectionCacheKey),
            let snapshot = try? JSONDecoder().decode(CachedTrainerConnection.self, from: data)
        else {
            return
        }

        activeLink = snapshot.link
        trainerProfile = snapshot.trainerProfile
        latestNote = snapshot.latestNote?.note
        latestActiveAssignment = snapshot.latestAssignment?.assignment
        isUsingCachedData = true
        hasLoadedInitialState = true
    }

    func saveDraft(profile: AppUserProfile) async {
        guard var intake else { return }

        isSaving = true
        errorMessage = nil
        intake.clientEmail = profile.email
        intake.clientDisplayName = profile.displayName
        intake.status = "draft"
        intake.updatedAt = .now

        do {
            try await firestore.collection("client_intakes").document(clientId).setData(intake.firestoreData, merge: true)
            self.intake = intake
            isSaving = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSaving = false
        }
    }

    func submit(profile: AppUserProfile) async {
        guard var intake else { return }

        isSaving = true
        errorMessage = nil

        let now = Date()
        intake.clientEmail = profile.email
        intake.clientDisplayName = profile.displayName
        intake.status = CoachingRequestStatus.submitted.rawValue
        intake.updatedAt = now
        intake.submittedAt = now

        let request = CoachingRequest(
            id: clientId,
            clientId: clientId,
            status: .submitted,
            reviewComment: "",
            assignedTrainerId: self.request?.assignedTrainerId,
            updatedAt: now,
            submittedAt: now
        )

        let batch = firestore.batch()
        batch.setData(intake.firestoreData, forDocument: firestore.collection("client_intakes").document(clientId), merge: true)
        batch.setData(request.firestoreData(with: intake), forDocument: firestore.collection("coaching_requests").document(clientId), merge: true)

        do {
            try await batch.commit()
            try? await AppNotificationEventWriter.createForActiveTrainers(
                type: .coachingRequestSubmitted,
                senderId: clientId,
                senderName: profile.displayName,
                targetType: .coachingRequest,
                targetId: request.id,
                firestore: firestore
            )
            self.intake = intake
            self.request = request
            isSaving = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSaving = false
        }
    }

    func startEditing() {
        if var request {
            request.status = .draft
            self.request = request
        }
    }

    private func makeIntake(
        profile: AppUserProfile,
        localUserData: UserData?,
        latestMeasurements: BodyMeasurements?
    ) -> ClientIntakeProfile {
        ClientIntakeProfile(
            id: clientId,
            clientId: clientId,
            clientEmail: profile.email,
            clientDisplayName: profile.displayName,
            goal: localUserData.map(coachingGoal) ?? .maintain,
            age: positive(localUserData?.age) ?? 25,
            height: positive(localUserData?.height) ?? 175,
            weight: positive(localUserData?.weight) ?? 70,
            sex: localUserData.map(coachingSex) ?? .male,
            activity: localUserData.map(coachingActivity) ?? .medium,
            measurements: ClientCoachingMeasurements(
                waist: positive(latestMeasurements?.waist) ?? 0,
                chest: positive(latestMeasurements?.chest) ?? 0,
                hips: positive(latestMeasurements?.hips) ?? 0
            )
        )
    }

    private func coachingGoal(for userData: UserData) -> ClientCoachingGoal {
        switch userData.goal {
        case .loseWeight:
            return .loseWeight
        case .currentWeight:
            return .maintain
        case .gainWeight:
            return .gainMass
        }
    }

    private func coachingSex(for userData: UserData) -> ClientCoachingSex {
        switch userData.gender {
        case .male:
            return .male
        case .female:
            return .female
        }
    }

    private func coachingActivity(for userData: UserData) -> ClientCoachingActivity {
        switch userData.activityLevel {
        case .none, .light:
            return .low
        case .moderate:
            return .medium
        case .pro:
            return .high
        }
    }

    private func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}

private struct CachedTrainerConnection: Codable {
    let linkId: String
    let trainerId: String
    let clientId: String
    let createdAt: Date
    let createdByOwnerId: String
    let trainerDisplayName: String?
    let trainerCreatedAt: Date?
    let trainerIsActive: Bool?
    let trainerPhotoURL: String?
    let latestNote: CachedCoachingNote?
    let latestAssignment: CachedWorkoutAssignment?

    var link: TrainerClientLink {
        TrainerClientLink(
            id: linkId,
            trainerId: trainerId,
            clientId: clientId,
            createdAt: createdAt,
            createdByOwnerId: createdByOwnerId
        )
    }

    var trainerProfile: AppUserProfile? {
        guard let trainerDisplayName, trainerDisplayName.isEmpty == false else { return nil }
        return AppUserProfile(
            id: trainerId,
            email: "",
            displayName: trainerDisplayName,
            role: .trainer,
            createdAt: trainerCreatedAt ?? createdAt,
            isActive: trainerIsActive ?? true,
            photoURL: trainerPhotoURL
        )
    }
}

private struct CachedCoachingNote: Codable {
    let id: String
    let clientId: String
    let trainerId: String
    let authorId: String
    let authorRole: String
    let message: String
    let createdAt: Date

    init(_ note: CoachingNote) {
        id = note.id
        clientId = note.clientId
        trainerId = note.trainerId
        authorId = note.authorId
        authorRole = note.authorRole.rawValue
        message = note.message
        createdAt = note.createdAt
    }

    var note: CoachingNote? {
        guard let role = CoachingNoteAuthorRole(rawValue: authorRole) else { return nil }
        return CoachingNote(
            id: id,
            clientId: clientId,
            trainerId: trainerId,
            authorId: authorId,
            authorRole: role,
            message: message,
            createdAt: createdAt
        )
    }
}

private struct CachedWorkoutAssignment: Codable {
    let id: String
    let trainerId: String
    let clientId: String
    let templateId: String
    let titleSnapshot: String
    let notesSnapshot: String
    let exerciseCount: Int
    let assignedAt: Date
    let status: WorkoutAssignmentStatus

    init(_ assignment: WorkoutAssignment) {
        id = assignment.id
        trainerId = assignment.trainerId
        clientId = assignment.clientId
        templateId = assignment.templateId
        titleSnapshot = assignment.titleSnapshot
        notesSnapshot = assignment.notesSnapshot
        exerciseCount = assignment.exerciseCount
        assignedAt = assignment.assignedAt
        status = assignment.status
    }

    var assignment: WorkoutAssignment {
        WorkoutAssignment(
            id: id,
            trainerId: trainerId,
            clientId: clientId,
            templateId: templateId,
            titleSnapshot: titleSnapshot,
            notesSnapshot: notesSnapshot,
            exerciseCount: exerciseCount,
            assignedAt: assignedAt,
            status: status
        )
    }
}
