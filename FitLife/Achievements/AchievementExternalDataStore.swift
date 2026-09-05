import Foundation
import FirebaseFirestore

enum FitLifeInstallationTracker {
    private static let firstLaunchKey = "fitlife.installation.firstLaunchDate"
    private static let healthConnectionKey = "fitlife.health.steps.connectionObservedAt"

    @discardableResult
    static func ensureFirstLaunchDate(now: Date = .now) -> Date {
        if let stored = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date {
            return stored
        }
        UserDefaults.standard.set(now, forKey: firstLaunchKey)
        return now
    }

    static func healthConnectionDate(isEnabled: Bool, now: Date = .now) -> Date? {
        guard isEnabled else {
            UserDefaults.standard.removeObject(forKey: healthConnectionKey)
            return nil
        }
        if let stored = UserDefaults.standard.object(forKey: healthConnectionKey) as? Date {
            return stored
        }
        UserDefaults.standard.set(now, forKey: healthConnectionKey)
        return now
    }
}

struct AchievementExternalSnapshot: Equatable {
    var healthConnected = false
    var stepGoalDays: Int?
    var totalSteps: Int?
    var checkInCount: Int?
    var coachDays: Int?
}

@MainActor
final class AchievementExternalDataStore: ObservableObject {
    @Published private(set) var snapshot = AchievementExternalSnapshot()

    private let firestore: Firestore
    private let healthStore = HealthKitStepsStore()
    private var loadGeneration = UUID()

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    func load(
        clientId: String,
        stepsEnabled: Bool,
        stepGoal: Int,
        progressStartedAt: Date?,
        now: Date = .now
    ) async {
        let generation = UUID()
        loadGeneration = generation
        var updated = snapshot
        let installationDate = FitLifeInstallationTracker.ensureFirstLaunchDate(now: now)
        let effectiveStart = max(installationDate, progressStartedAt ?? installationDate)
        let connectionDate = FitLifeInstallationTracker.healthConnectionDate(isEnabled: stepsEnabled, now: now)
        updated.healthConnected = connectionDate.map { $0 >= effectiveStart } ?? false

        if stepsEnabled, let history = await healthStore.completeHistory(startingAt: effectiveStart, endingAt: now) {
            updated.stepGoalDays = history.filter { $0.steps >= max(stepGoal, 1) }.count
            updated.totalSteps = history.reduce(0) { total, day in
                let (sum, overflow) = total.addingReportingOverflow(max(day.steps, 0))
                return overflow ? Int.max : sum
            }
        } else if stepsEnabled == false {
            updated.stepGoalDays = 0
            updated.totalSteps = 0
        }

        if let checkInCount = await loadCheckInCount(clientId: clientId, startingAt: effectiveStart) {
            updated.checkInCount = checkInCount
        }
        if let coachDays = await loadCoachDays(clientId: clientId, startingAt: effectiveStart, now: now) {
            updated.coachDays = coachDays
        }

        guard loadGeneration == generation else { return }
        snapshot = updated
    }

    func clearForProgressReset() {
        loadGeneration = UUID()
        snapshot = AchievementExternalSnapshot()
    }

    private func loadCheckInCount(clientId: String, startingAt startDate: Date) async -> Int? {
        let query = firestore
            .collection("progress_checkins")
            .whereField("clientId", isEqualTo: clientId)
        if let server = try? await query.getDocuments(source: .server) {
            return server.documents.filter { Self.createdAt(from: $0.data()) >= startDate }.count
        }
        if let cache = try? await query.getDocuments(source: .cache) {
            return cache.documents.filter { Self.createdAt(from: $0.data()) >= startDate }.count
        }
        return nil
    }

    private func loadCoachDays(clientId: String, startingAt startDate: Date, now: Date) async -> Int? {
        let query = firestore
            .collection("trainer_client_links")
            .whereField("clientId", isEqualTo: clientId)
            .whereField("status", isEqualTo: "active")

        let documents: [QueryDocumentSnapshot]
        if let server = try? await query.getDocuments(source: .server) {
            documents = server.documents
        } else if let cache = try? await query.getDocuments(source: .cache) {
            documents = cache.documents
        } else {
            return nil
        }

        guard let createdAt = documents.compactMap({ document -> Date? in
            if let timestamp = document.data()["createdAt"] as? Timestamp {
                return timestamp.dateValue()
            }
            return document.data()["createdAt"] as? Date
        }).min() else {
            return 0
        }

        let effectiveConnectionDate = max(createdAt, startDate)
        return max(Calendar.current.dateComponents([.day], from: effectiveConnectionDate, to: now).day ?? 0, 0)
    }

    private static func createdAt(from data: [String: Any]) -> Date {
        if let timestamp = data["createdAt"] as? Timestamp {
            return timestamp.dateValue()
        }
        return data["createdAt"] as? Date ?? .distantPast
    }
}
