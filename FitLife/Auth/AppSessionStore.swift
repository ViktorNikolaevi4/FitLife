import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AppSessionStore: ObservableObject {
    @Published private(set) var firebaseUser: User?
    @Published private(set) var profile: AppUserProfile?
    @Published private(set) var isLoading = true
    @Published var authErrorMessage: String?

    private let auth: Auth
    private let firestore: Firestore
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    init(auth: Auth = .auth(), firestore: Firestore = .firestore()) {
        self.auth = auth
        self.firestore = firestore
        observeAuthState()
    }

    deinit {
        if let authListenerHandle {
            auth.removeStateDidChangeListener(authListenerHandle)
        }
    }

    var currentRole: AppUserRole? {
        profile?.role
    }

    func signIn(email: String, password: String) async {
        authErrorMessage = nil
        isLoading = true

        do {
            _ = try await auth.signIn(withEmail: email, password: password)
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    func signUp(name: String, email: String, password: String) async {
        authErrorMessage = nil
        isLoading = true

        do {
            let result = try await auth.createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await changeRequest.commitChanges()
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    func signOut() {
        do {
            try auth.signOut()
            profile = nil
            firebaseUser = nil
            authErrorMessage = nil
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
        }
    }

    private func observeAuthState() {
        authListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                await self.handleAuthStateChange(user)
            }
        }
    }

    private func handleAuthStateChange(_ user: User?) async {
        firebaseUser = user
        profile = nil

        guard let user else {
            isLoading = false
            return
        }

        await loadOrCreateProfile(for: user)
    }

    private func loadOrCreateProfile(for user: User) async {
        let documentRef = firestore.collection("users").document(user.uid)

        do {
            let snapshot = try await documentRef.getDocument()

            if let data = snapshot.data(), let profile = AppUserProfile(id: user.uid, data: data) {
                try await ensureProfileSchema(for: profile, documentRef: documentRef, rawData: data)
                self.profile = profile
                isLoading = false
                return
            }

            let createdProfile = try await createInitialProfile(for: user)
            try await documentRef.setData(createdProfile.firestoreData)
            profile = createdProfile
            isLoading = false
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    private func ensureProfileSchema(
        for profile: AppUserProfile,
        documentRef: DocumentReference,
        rawData: [String: Any]
    ) async throws {
        let needsUid = (rawData["uid"] as? String)?.isEmpty != false
        let needsCreatedAt = rawData["createdAt"] == nil
        let needsIsActive = rawData["isActive"] == nil

        guard needsUid || needsCreatedAt || needsIsActive else {
            return
        }

        try await documentRef.setData(profile.firestoreData, merge: true)
    }

    private func createInitialProfile(for user: User) async throws -> AppUserProfile {
        let email = user.email ?? ""
        let role = AuthConfiguration.role(for: email)
        let trimmedName = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName: String

        if trimmedName.isEmpty {
            displayName = email.split(separator: "@").first.map(String.init) ?? "User"
        } else {
            displayName = trimmedName
        }

        return AppUserProfile(
            id: user.uid,
            email: email,
            displayName: displayName,
            role: role
        )
    }
}
