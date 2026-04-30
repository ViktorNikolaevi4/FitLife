import Foundation
import FirebaseFirestore

@MainActor
final class WorkoutTemplatesStore: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
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
            let snapshot = try await firestore
                .collection("workout_templates")
                .whereField("trainerId", isEqualTo: trainerId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            templates = snapshot.documents.compactMap { document in
                WorkoutTemplate(id: document.documentID, data: document.data())
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func createTemplate(title: String, notes: String) async -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTitle.isEmpty == false else { return false }

        errorMessage = nil

        do {
            let documentRef = firestore.collection("workout_templates").document()
            let template = WorkoutTemplate(
                id: documentRef.documentID,
                trainerId: trainerId,
                title: normalizedTitle,
                notes: normalizedNotes
            )

            try await documentRef.setData(template.firestoreData)
            templates.insert(template, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTemplate(_ template: WorkoutTemplate) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("workout_templates")
                .document(template.id)
                .setData(
                    [
                        "isActive": false,
                        "updatedAt": Date()
                    ],
                    merge: true
                )

            templates.removeAll { $0.id == template.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
