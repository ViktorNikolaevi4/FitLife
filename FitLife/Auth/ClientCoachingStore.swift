import Foundation
import FirebaseFirestore

@MainActor
final class ClientCoachingStore: ObservableObject {
    @Published var intake: ClientIntakeProfile?
    @Published var request: CoachingRequest?
    @Published var activeLink: TrainerClientLink?
    @Published var trainerProfile: AppUserProfile?
    @Published var isLoading = false
    @Published private(set) var hasLoadedInitialState = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let clientId: String
    private let firestore: Firestore

    init(clientId: String, firestore: Firestore = .firestore()) {
        self.clientId = clientId
        self.firestore = firestore
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

        do {
            async let intakeSnapshot = firestore.collection("client_intakes").document(clientId).getDocument()
            async let requestSnapshot = firestore.collection("coaching_requests").document(clientId).getDocument()
            async let activeLinksSnapshot = firestore
                .collection("trainer_client_links")
                .whereField("clientId", isEqualTo: clientId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()

            let (intakeDocument, requestDocument, activeLinksDocument) = try await (intakeSnapshot, requestSnapshot, activeLinksSnapshot)

            if let data = intakeDocument.data(),
               let intake = ClientIntakeProfile(id: intakeDocument.documentID, data: data) {
                self.intake = intake
            } else {
                self.intake = makeIntake(
                    profile: profile,
                    localUserData: localUserData,
                    latestMeasurements: latestMeasurements
                )
            }

            if let data = requestDocument.data(),
               let request = CoachingRequest(id: requestDocument.documentID, data: data) {
                self.request = request
            } else {
                self.request = nil
            }

            if let firstLink = activeLinksDocument.documents.first,
               let link = TrainerClientLink(id: firstLink.documentID, data: firstLink.data()) {
                self.activeLink = link
                let trainerSnapshot = try await firestore.collection("users").document(link.trainerId).getDocument()
                if let data = trainerSnapshot.data(),
                   let trainer = AppUserProfile(id: trainerSnapshot.documentID, data: data) {
                    self.trainerProfile = trainer
                }
            } else {
                self.activeLink = nil
                self.trainerProfile = nil
            }

            hasLoadedInitialState = true
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            hasLoadedInitialState = true
            isLoading = false
        }
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
