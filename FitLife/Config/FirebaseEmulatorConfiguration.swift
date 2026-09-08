import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum FirebaseEmulatorConfiguration {
    private static var hasConfigured = false

    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--firebase-emulators")
        #else
        false
        #endif
    }

    static var host: String {
        #if DEBUG
        let configuredHost = ProcessInfo.processInfo.environment["FIREBASE_EMULATOR_HOST"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let configuredHost, configuredHost.isEmpty == false {
            return configuredHost
        }
        #endif
        return "127.0.0.1"
    }

    static func configureIfNeeded() {
        guard isEnabled, hasConfigured == false else { return }
        hasConfigured = true

        Auth.auth().useEmulator(withHost: host, port: 9099)
        Firestore.firestore().useEmulator(withHost: host, port: 8080)
        Storage.storage().useEmulator(withHost: host, port: 9199)

        #if DEBUG
        print("Firebase Emulator Suite enabled at \(host)")
        #endif
    }

    static func functionsURL(
        named functionName: String,
        projectId: String,
        region: String = "europe-west1"
    ) -> URL? {
        if isEnabled {
            return URL(
                string: "http://\(host):5001/\(projectId)/\(region)/\(functionName)"
            )
        }
        return URL(
            string: "https://\(region)-\(projectId).cloudfunctions.net/\(functionName)"
        )
    }
}
