import Foundation
import FirebaseFirestore

@MainActor
final class WorkoutTemplatesStore: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var libraryTemplates: [LibraryWorkoutTemplate] = []
    @Published private(set) var importingLibraryTemplateIds: Set<String> = []
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
            async let templatesSnapshot = firestore
                .collection("workout_templates")
                .whereField("trainerId", isEqualTo: trainerId)
                .whereField("isActive", isEqualTo: true)
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            async let librarySnapshot = try? firestore
                .collection("workout_template_library")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            let personalDocs = try await templatesSnapshot
            let libraryDocs = await librarySnapshot

            templates = personalDocs.documents.compactMap { document in
                WorkoutTemplate(id: document.documentID, data: document.data())
            }
            libraryTemplates = (libraryDocs?.documents ?? [])
                .compactMap { document in
                    LibraryWorkoutTemplate(id: document.documentID, data: document.data())
                }
                .sorted {
                    if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
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

    func isImported(_ libraryTemplate: LibraryWorkoutTemplate) -> Bool {
        templates.contains { $0.sourceLibraryTemplateId == libraryTemplate.id }
    }

    func isImporting(_ libraryTemplate: LibraryWorkoutTemplate) -> Bool {
        importingLibraryTemplateIds.contains(libraryTemplate.id)
    }

    func importLibraryTemplate(_ libraryTemplate: LibraryWorkoutTemplate) async -> Bool {
        guard isImported(libraryTemplate) == false,
              isImporting(libraryTemplate) == false else {
            return false
        }

        importingLibraryTemplateIds.insert(libraryTemplate.id)
        defer { importingLibraryTemplateIds.remove(libraryTemplate.id) }
        errorMessage = nil

        let personalRef = firestore.collection("workout_templates").document()

        do {
            let libraryRef = firestore
                .collection("workout_template_library")
                .document(libraryTemplate.id)

            async let exercisesSnapshot = libraryRef
                .collection("exercises")
                .getDocuments()
            async let blocksSnapshot = libraryRef
                .collection("blocks")
                .getDocuments()

            let (exerciseDocs, blockDocs) = try await (exercisesSnapshot, blocksSnapshot)
            let now = Date()
            let personalTemplate = WorkoutTemplate(
                id: personalRef.documentID,
                trainerId: trainerId,
                title: libraryTemplate.title,
                notes: libraryTemplate.notes,
                createdAt: now,
                updatedAt: now,
                sourceLibraryTemplateId: libraryTemplate.id
            )

            // The parent is created first because child-write security rules
            // verify that this trainer owns the destination template.
            try await personalRef.setData(personalTemplate.firestoreData)

            do {
                let batch = firestore.batch()
                for document in exerciseDocs.documents {
                    batch.setData(
                        document.data(),
                        forDocument: personalRef.collection("exercises").document(document.documentID)
                    )
                }
                for document in blockDocs.documents {
                    batch.setData(
                        document.data(),
                        forDocument: personalRef.collection("blocks").document(document.documentID)
                    )
                }
                try await batch.commit()
            } catch {
                try? await personalRef.delete()
                throw error
            }

            templates.insert(personalTemplate, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
