import Foundation
import FirebaseFirestore

@MainActor
final class AdminUsersStore: ObservableObject {
    @Published private(set) var users: [AppUserProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let firestore: Firestore

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await firestore
                .collection("users")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            users = snapshot.documents.compactMap { document in
                AppUserProfile(id: document.documentID, data: document.data())
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func updateRole(for user: AppUserProfile, to role: AppUserRole) async {
        guard user.role != role else { return }

        errorMessage = nil

        do {
            try await firestore
                .collection("users")
                .document(user.id)
                .setData(["role": role.rawValue], merge: true)

            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index].role = role
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
