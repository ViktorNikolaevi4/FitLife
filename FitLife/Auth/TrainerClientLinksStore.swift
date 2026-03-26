import Foundation
import FirebaseFirestore

@MainActor
final class TrainerClientLinksStore: ObservableObject {
    @Published private(set) var trainers: [AppUserProfile] = []
    @Published private(set) var links: [TrainerClientLink] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let firestore: Firestore

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let trainersSnapshot = firestore
                .collection("users")
                .whereField("role", isEqualTo: AppUserRole.trainer.rawValue)
                .getDocuments()

            async let linksSnapshot = firestore
                .collection("trainer_client_links")
                .getDocuments()

            let (trainerDocs, linkDocs) = try await (trainersSnapshot, linksSnapshot)

            trainers = trainerDocs.documents.compactMap { document in
                AppUserProfile(id: document.documentID, data: document.data())
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            links = linkDocs.documents.compactMap { document in
                TrainerClientLink(id: document.documentID, data: document.data())
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func activeClientCount(for trainerId: String) -> Int {
        links.filter { $0.trainerId == trainerId && $0.status == "active" }.count
    }
}

@MainActor
final class TrainerClientsStore: ObservableObject {
    @Published private(set) var clients: [AppUserProfile] = []
    @Published private(set) var linksByClientId: [String: TrainerClientLink] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let trainer: AppUserProfile
    private let ownerId: String
    private let firestore: Firestore

    init(
        trainer: AppUserProfile,
        ownerId: String,
        firestore: Firestore = .firestore()
    ) {
        self.trainer = trainer
        self.ownerId = ownerId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let clientsSnapshot = firestore
                .collection("users")
                .whereField("role", isEqualTo: AppUserRole.client.rawValue)
                .getDocuments()

            async let linksSnapshot = firestore
                .collection("trainer_client_links")
                .whereField("trainerId", isEqualTo: trainer.id)
                .getDocuments()

            let (clientDocs, linkDocs) = try await (clientsSnapshot, linksSnapshot)

            clients = clientDocs.documents.compactMap { document in
                AppUserProfile(id: document.documentID, data: document.data())
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            linksByClientId = Dictionary(
                uniqueKeysWithValues: linkDocs.documents.compactMap { document in
                    guard let link = TrainerClientLink(id: document.documentID, data: document.data()) else {
                        return nil
                    }
                    return (link.clientId, link)
                }
            )

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func isAssigned(clientId: String) -> Bool {
        linksByClientId[clientId]?.status == "active"
    }

    func setAssignment(for client: AppUserProfile, isAssigned: Bool) async {
        let documentId = "\(trainer.id)_\(client.id)"
        let documentRef = firestore.collection("trainer_client_links").document(documentId)

        errorMessage = nil

        do {
            if isAssigned {
                let link = TrainerClientLink(
                    id: documentId,
                    trainerId: trainer.id,
                    clientId: client.id,
                    createdByOwnerId: ownerId
                )

                try await documentRef.setData(link.firestoreData)
                linksByClientId[client.id] = link
            } else {
                try await documentRef.delete()
                linksByClientId.removeValue(forKey: client.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TrainerAssignedClientsStore: ObservableObject {
    @Published private(set) var clients: [AppUserProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let trainerId: String
    private let firestore: Firestore

    init(trainerId: String, firestore: Firestore = .firestore()) {
        self.trainerId = trainerId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let linksSnapshot = try await firestore
                .collection("trainer_client_links")
                .whereField("trainerId", isEqualTo: trainerId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()

            let clientIds = linksSnapshot.documents.compactMap { document in
                TrainerClientLink(id: document.documentID, data: document.data())?.clientId
            }

            var loadedClients: [AppUserProfile] = []
            for clientId in clientIds {
                let snapshot = try await firestore.collection("users").document(clientId).getDocument()
                guard let data = snapshot.data(),
                      let profile = AppUserProfile(id: snapshot.documentID, data: data) else {
                    continue
                }
                loadedClients.append(profile)
            }

            clients = loadedClients.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
