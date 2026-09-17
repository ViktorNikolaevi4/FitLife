import Foundation
import FirebaseFirestore
import SwiftData

enum CoachingReportDeliveryResult: Equatable {
    case delivered
    case queued
}

enum CoachingReportDeliveryStatus: Equatable {
    case idle
    case sending
    case delivered
    case queued
    case failed(String)
}

private struct PendingCoachingReportDelivery: Codable, Identifiable {
    let id: String
    let targetId: String?
    let clientId: String
    let collection: String
    let reportData: Data
    let notificationId: String
    let notificationData: Data
    let createdAt: Date
    var attemptCount: Int
    var lastError: String?
    var hasPermanentFailure: Bool
}

@Model
final class PendingCoachingReportDeliveryRecord {
    @Attribute(.unique) var id: String
    var targetId: String?
    var clientId: String
    var collection: String
    var reportData: Data
    var notificationId: String
    var notificationData: Data
    var createdAt: Date
    var attemptCount: Int
    var lastError: String?
    var hasPermanentFailure: Bool

    fileprivate init(delivery: PendingCoachingReportDelivery) {
        id = delivery.id
        targetId = delivery.targetId
        clientId = delivery.clientId
        collection = delivery.collection
        reportData = delivery.reportData
        notificationId = delivery.notificationId
        notificationData = delivery.notificationData
        createdAt = delivery.createdAt
        attemptCount = delivery.attemptCount
        lastError = delivery.lastError
        hasPermanentFailure = delivery.hasPermanentFailure
    }

    fileprivate var delivery: PendingCoachingReportDelivery {
        PendingCoachingReportDelivery(
            id: id,
            targetId: targetId,
            clientId: clientId,
            collection: collection,
            reportData: reportData,
            notificationId: notificationId,
            notificationData: notificationData,
            createdAt: createdAt,
            attemptCount: attemptCount,
            lastError: lastError,
            hasPermanentFailure: hasPermanentFailure
        )
    }

    fileprivate func update(from delivery: PendingCoachingReportDelivery) {
        targetId = delivery.targetId
        clientId = delivery.clientId
        collection = delivery.collection
        reportData = delivery.reportData
        notificationId = delivery.notificationId
        notificationData = delivery.notificationData
        createdAt = delivery.createdAt
        attemptCount = delivery.attemptCount
        lastError = delivery.lastError
        hasPermanentFailure = delivery.hasPermanentFailure
    }
}

@MainActor
private final class CoachingReportDeliveryStore {
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
        context.autosaveEnabled = false
    }

    func fetchAll() throws -> [PendingCoachingReportDelivery] {
        let descriptor = FetchDescriptor<PendingCoachingReportDeliveryRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor).map(\.delivery)
    }

    func synchronize(_ deliveries: [PendingCoachingReportDelivery]) throws {
        let records = try context.fetch(FetchDescriptor<PendingCoachingReportDeliveryRecord>())
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let activeIDs = Set(deliveries.map(\.id))

        for record in records where activeIDs.contains(record.id) == false {
            context.delete(record)
        }

        for delivery in deliveries {
            if let record = recordsByID.removeValue(forKey: delivery.id) {
                record.update(from: delivery)
            } else {
                context.insert(PendingCoachingReportDeliveryRecord(delivery: delivery))
            }
        }

        try context.save()
    }
}

private enum CoachingReportOutboxError: LocalizedError {
    case invalidPayload
    case deliveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return AppLocalizer.string("coaching.report.outbox.preparation_failed")
        case .deliveryFailed(let message):
            return message
        }
    }
}

/// Надёжная локальная очередь только для снимков, которые клиент явно решил
/// отправить тренеру. Личный дневник в очередь и Firestore не попадает.
actor CoachingReportDeliveryOutbox {
    static let shared = CoachingReportDeliveryOutbox()

    private let defaultsKey = "coaching.report.delivery.outbox.v1"
    private var deliveries: [PendingCoachingReportDelivery]
    private var store: CoachingReportDeliveryStore?
    private var isConfiguringStore = false
    private var inFlightIDs: Set<String> = []
    private var permanentFailures: [String: String] = [:]
    private var cancelledClientIDs: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([PendingCoachingReportDelivery].self, from: data) {
            deliveries = decoded
        } else {
            deliveries = []
        }
    }

    /// Подключает SwiftData и переносит старую очередь из UserDefaults.
    /// Повторный вызов безопасен и ничего не перезаписывает.
    func configure(modelContainer: ModelContainer) async {
        guard store == nil, isConfiguringStore == false else { return }
        isConfiguringStore = true

        let newStore = await CoachingReportDeliveryStore(modelContainer: modelContainer)
        do {
            let storedDeliveries = try await newStore.fetchAll()
            var mergedByID = Dictionary(uniqueKeysWithValues: storedDeliveries.map { ($0.id, $0) })
            for delivery in deliveries where mergedByID[delivery.id] == nil {
                mergedByID[delivery.id] = delivery
            }
            let merged = mergedByID.values.sorted { $0.createdAt < $1.createdAt }

            // Устанавливаем store до следующего await: если в этот момент
            // пользователь отправит новый отчёт, он уже попадёт в SwiftData,
            // а не будет потерян при завершении миграции.
            store = newStore
            deliveries = merged
            try await newStore.synchronize(merged)

            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } catch {
            store = nil
            // До следующей попытки сохраняем совместимость со старым хранилищем,
            // чтобы отчёты не потерялись при редкой ошибке открытия SwiftData.
            persistToLegacyDefaults()
            #if DEBUG
            print("Failed to configure coaching report outbox: \(error)")
            #endif
        }
        isConfiguringStore = false
    }

    func submitWorkoutReport(
        _ report: CoachingWorkoutReport,
        senderName: String,
        firestore: Firestore = .firestore()
    ) async throws -> CoachingReportDeliveryResult {
        let notification = AppNotificationEvent(
            id: "workout-report-\(report.id)",
            type: .workoutReportSent,
            recipientId: report.trainerId,
            senderId: report.clientId,
            senderName: senderName,
            targetType: .workoutReport,
            targetId: report.id
        )
        return try await enqueueAndStart(
            id: report.id,
            targetId: report.id,
            clientId: report.clientId,
            collection: "coaching_workout_reports",
            reportData: report.firestoreData,
            notification: notification,
            firestore: firestore
        )
    }

    func submitNutritionReport(
        _ report: CoachingNutritionReport,
        senderName: String,
        firestore: Firestore = .firestore()
    ) async throws -> CoachingReportDeliveryResult {
        let notification = AppNotificationEvent(
            id: "nutrition-report-\(report.id)",
            type: .nutritionReportSent,
            recipientId: report.trainerId,
            senderId: report.clientId,
            senderName: senderName,
            targetType: .nutritionReport,
            targetId: report.firestoreDocumentId
        )
        return try await enqueueAndStart(
            id: report.id,
            targetId: report.firestoreDocumentId,
            clientId: report.clientId,
            collection: "coaching_nutrition_reports",
            reportData: report.firestoreData,
            notification: notification,
            firestore: firestore
        )
    }

    /// Запускает повторы в фоне и сразу возвращает управление интерфейсу.
    func retryPending(for clientId: String, firestore: Firestore = .firestore()) {
        guard cancelledClientIDs.contains(clientId) == false else { return }
        let ids = deliveries
            .filter { $0.clientId == clientId && $0.hasPermanentFailure == false }
            .map(\.id)
        for id in ids {
            startDelivery(id: id, firestore: firestore)
        }
    }

    func removeAll(for clientId: String) async {
        cancelledClientIDs.insert(clientId)
        deliveries.removeAll { $0.clientId == clientId }
        await persist()
    }

    private func enqueueAndStart(
        id: String,
        targetId: String,
        clientId: String,
        collection: String,
        reportData: [String: Any],
        notification: AppNotificationEvent,
        firestore: Firestore
    ) async throws -> CoachingReportDeliveryResult {
        cancelledClientIDs.remove(clientId)
        permanentFailures[id] = nil
        if deliveries.contains(where: { $0.id == id }) == false {
            let pending = PendingCoachingReportDelivery(
                id: id,
                targetId: targetId,
                clientId: clientId,
                collection: collection,
                reportData: try encodePropertyList(reportData),
                notificationId: notification.id,
                notificationData: try encodePropertyList(notification.firestoreData),
                createdAt: .now,
                attemptCount: 0,
                lastError: nil,
                hasPermanentFailure: false
            )
            deliveries.append(pending)
            await persist()
        }

        startDelivery(id: id, firestore: firestore)

        // Быстрая сеть успеет подтвердить запись. При медленной сети интерфейс
        // через 2,5 секунды сообщит об очереди, а отправка продолжится в фоне.
        for _ in 0..<25 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let message = permanentFailures.removeValue(forKey: id) {
                throw CoachingReportOutboxError.deliveryFailed(message)
            }
            guard let pending = deliveries.first(where: { $0.id == id }) else {
                return .delivered
            }
            if pending.hasPermanentFailure {
                throw CoachingReportOutboxError.invalidPayload
            }
        }
        return .queued
    }

    private func startDelivery(id: String, firestore: Firestore) {
        guard inFlightIDs.insert(id).inserted else { return }
        Task {
            await performDelivery(id: id, firestore: firestore)
        }
    }

    private func performDelivery(id: String, firestore: Firestore) async {
        guard let index = deliveries.firstIndex(where: { $0.id == id }) else {
            inFlightIDs.remove(id)
            return
        }

        deliveries[index].attemptCount += 1
        deliveries[index].lastError = nil
        await persist()
        let pending = deliveries[index]

        guard cancelledClientIDs.contains(pending.clientId) == false else {
            deliveries.removeAll { $0.id == id }
            inFlightIDs.remove(id)
            await persist()
            return
        }

        do {
            // Старые элементы очереди не содержат targetId и продолжают
            // доставляться в прежний документ с идентификатором отправки.
            let reportRef = firestore.collection(pending.collection).document(pending.targetId ?? pending.id)

            if cancelledClientIDs.contains(pending.clientId) {
                deliveries.removeAll { $0.id == id }
                inFlightIDs.remove(id)
                await persist()
                return
            }

            // Запись с постоянным id идемпотентна: при потере подтверждения
            // очередь безопасно повторит тот же batch. Firestore Rules разрешают
            // клиенту только точное повторение уже сохранённых данных.
            var reportData = try decodePropertyList(pending.reportData)
            let notificationData = try decodePropertyList(pending.notificationData)
            let notificationRef = firestore
                .collection("notification_events")
                .document(pending.notificationId)
            let batch = firestore.batch()
            if pending.collection == "coaching_nutrition_reports" {
                // A nutrition report can reuse the same document for the same
                // day. Keep reactions that were already added to that card.
                reportData.removeValue(forKey: "reactions")
                batch.setData(reportData, forDocument: reportRef, merge: true)
            } else {
                batch.setData(reportData, forDocument: reportRef)
            }
            batch.setData(notificationData, forDocument: notificationRef)
            try await batch.commit()

            deliveries.removeAll { $0.id == id }
            await persist()
        } catch {
            if let failedIndex = deliveries.firstIndex(where: { $0.id == id }) {
                if isPermanent(error) {
                    permanentFailures[id] = error.localizedDescription
                    deliveries.remove(at: failedIndex)
                } else {
                    deliveries[failedIndex].lastError = error.localizedDescription
                }
                await persist()
            }
        }

        inFlightIDs.remove(id)
    }

    private func encodePropertyList(_ value: [String: Any]) throws -> Data {
        guard PropertyListSerialization.propertyList(value, isValidFor: .binary) else {
            throw CoachingReportOutboxError.invalidPayload
        }
        return try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    private func decodePropertyList(_ data: Data) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw CoachingReportOutboxError.invalidPayload
        }
        return value
    }

    private func isPermanent(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain {
            // permissionDenied, invalidArgument, unauthenticated
            return [7, 3, 16].contains(nsError.code)
        }
        return false
    }

    private func persist() async {
        guard let store else {
            persistToLegacyDefaults()
            return
        }

        do {
            try await store.synchronize(deliveries)
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } catch {
            // Аварийная копия нужна только если SwiftData временно не смогла
            // сохранить очередь. При следующем configure она будет мигрирована.
            persistToLegacyDefaults()
            #if DEBUG
            print("Failed to persist coaching report outbox: \(error)")
            #endif
        }
    }

    private func persistToLegacyDefaults() {
        guard let data = try? JSONEncoder().encode(deliveries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
