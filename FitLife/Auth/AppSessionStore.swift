import Foundation
import FirebaseAuth
import FirebaseCore
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
    private var initialLoadingTimeoutTask: Task<Void, Never>?

    init(auth: Auth = .auth(), firestore: Firestore = .firestore()) {
        self.auth = auth
        self.firestore = firestore
        observeAuthState()
    }

    deinit {
        initialLoadingTimeoutTask?.cancel()
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
            do {
                try await result.user.sendEmailVerification()
            } catch {
                logAuthDiagnostic("Email verification send failed after sign up", error)
                authErrorMessage = AppErrorPresenter.message(for: error)
            }
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

    func sendPasswordReset(email: String) async -> Bool {
        authErrorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedEmail.isEmpty == false else {
            authErrorMessage = AppLocalizer.string("auth.reset.missing_email")
            return false
        }

        do {
            try await auth.sendPasswordReset(withEmail: trimmedEmail)
            return true
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
            return false
        }
    }

    func sendEmailVerification() async -> Bool {
        authErrorMessage = nil

        guard let user = auth.currentUser else {
            return false
        }

        do {
            try await user.sendEmailVerification()
            return true
        } catch {
            logAuthDiagnostic("Email verification send failed", error)
            authErrorMessage = AppErrorPresenter.message(for: error)
            return false
        }
    }

    func reloadCurrentUser() async {
        guard let user = auth.currentUser else { return }

        do {
            try await user.reload()
            firebaseUser = auth.currentUser
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
        }
    }

    func deleteCurrentAccount(password: String) async -> Bool {
        authErrorMessage = nil

        guard
            let user = auth.currentUser,
            let email = user.email,
            password.isEmpty == false
        else {
            return false
        }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            try await requestServerAccountDataDeletion(for: user)
            try await user.delete()
            try? auth.signOut()
            profile = nil
            firebaseUser = nil
            return true
        } catch {
            authErrorMessage = AppErrorPresenter.message(for: error)
            return false
        }
    }

    private func requestServerAccountDataDeletion(for user: User) async throws {
        guard
            let projectId = FirebaseApp.app()?.options.projectID,
            let endpoint = URL(
                string: "https://europe-west1-\(projectId).cloudfunctions.net/deleteCurrentAccountData"
            )
        else {
            throw URLError(.badURL)
        }

        let idToken = try await refreshedIDToken(for: user)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["confirm": true])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let error = payload?["error"] as? [String: Any]
            let code = error?["code"] as? String ?? "account_deletion_failed"
            throw NSError(
                domain: "FitLife.AccountDeletion",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: accountDeletionErrorMessage(for: code)]
            )
        }
    }

    private func refreshedIDToken(for user: User) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(true) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token, token.isEmpty == false {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: URLError(.userAuthenticationRequired))
                }
            }
        }
    }

    private func accountDeletionErrorMessage(for code: String) -> String {
        switch code {
        case "recent_login_required":
            return AppLocalizer.string("settings.account.delete.reauthentication_required")
        default:
            return AppLocalizer.string("settings.account.delete.failed")
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

    private func logAuthDiagnostic(_ context: String, _ error: Error) {
        let nsError = error as NSError
        print("[Auth] \(context): domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
    }

    private func handleAuthStateChange(_ user: User?) async {
        initialLoadingTimeoutTask?.cancel()
        firebaseUser = user
        profile = nil

        guard let user else {
            isLoading = false
            return
        }

        // Firestore can wait indefinitely while iOS has no usable route to the
        // network. The local SwiftData content is still safe to show, so never
        // leave the whole application on its launch screen in that situation.
        initialLoadingTimeoutTask = Task { [weak self, userId = user.uid] in
            try? await Task.sleep(for: .seconds(5))
            guard Task.isCancelled == false else { return }
            self?.finishInitialLoadingIfNeeded(for: userId)
        }

        await loadOrCreateProfile(for: user)
        initialLoadingTimeoutTask?.cancel()
        initialLoadingTimeoutTask = nil
    }

    private func finishInitialLoadingIfNeeded(for userId: String) {
        guard firebaseUser?.uid == userId, isLoading else { return }
        isLoading = false
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
            role: AuthConfiguration.defaultNewUserRole
        )
    }
}
