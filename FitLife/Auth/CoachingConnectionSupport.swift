import SwiftUI
import FirebaseFirestore

enum ProfileUpdateRequestType: String, CaseIterable, Codable, Identifiable {
    case weightUpdate = "weight_update"
    case measurementsUpdate = "measurements_update"
    case limitationsUpdate = "limitations_update"
    case equipmentUpdate = "equipment_update"
    case generalUpdate = "general_update"

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .weightUpdate: return "coaching.update_request.type.weight"
        case .measurementsUpdate: return "coaching.update_request.type.measurements"
        case .limitationsUpdate: return "coaching.update_request.type.limitations"
        case .equipmentUpdate: return "coaching.update_request.type.equipment"
        case .generalUpdate: return "coaching.update_request.type.general"
        }
    }
}

enum CoachingNoteAuthorRole: String, Codable {
    case trainer
    case client
}

struct ProgressCheckIn: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let weight: Double
    let waist: Double
    let chest: Double
    let hips: Double
    let energy: Int
    let adherence: Int
    let notes: String
    let createdAt: Date

    init(
        id: String,
        clientId: String,
        trainerId: String,
        weight: Double,
        waist: Double,
        chest: Double,
        hips: Double,
        energy: Int,
        adherence: Int,
        notes: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.weight = weight
        self.waist = waist
        self.chest = chest
        self.hips = hips
        self.energy = energy
        self.adherence = adherence
        self.notes = notes
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let weight = data["weight"] as? Double,
            let waist = data["waist"] as? Double,
            let chest = data["chest"] as? Double,
            let hips = data["hips"] as? Double,
            let energy = data["energy"] as? Int,
            let adherence = data["adherence"] as? Int,
            let notes = data["notes"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.weight = weight
        self.waist = waist
        self.chest = chest
        self.hips = hips
        self.energy = energy
        self.adherence = adherence
        self.notes = notes
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "weight": weight,
            "waist": waist,
            "chest": chest,
            "hips": hips,
            "energy": energy,
            "adherence": adherence,
            "notes": notes,
            "createdAt": createdAt
        ]
    }
}

struct ProfileUpdateRequest: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let type: ProfileUpdateRequestType
    let message: String
    let status: String
    let createdAt: Date
    let resolvedAt: Date?

    init(
        id: String,
        clientId: String,
        trainerId: String,
        type: ProfileUpdateRequestType,
        message: String,
        status: String = "open",
        createdAt: Date = .now,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.type = type
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let typeRaw = data["type"] as? String,
            let type = ProfileUpdateRequestType(rawValue: typeRaw),
            let message = data["message"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.type = type
        self.message = message
        self.status = (data["status"] as? String) ?? "open"
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        if let timestamp = data["resolvedAt"] as? Timestamp {
            self.resolvedAt = timestamp.dateValue()
        } else {
            self.resolvedAt = data["resolvedAt"] as? Date
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "type": type.rawValue,
            "message": message,
            "status": status,
            "createdAt": createdAt,
            "resolvedAt": resolvedAt as Any
        ]
    }
}

struct CoachingNote: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let authorId: String
    let authorRole: CoachingNoteAuthorRole
    let message: String
    let createdAt: Date

    init(
        id: String,
        clientId: String,
        trainerId: String,
        authorId: String,
        authorRole: CoachingNoteAuthorRole,
        message: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.authorId = authorId
        self.authorRole = authorRole
        self.message = message
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let authorId = data["authorId"] as? String,
            let authorRoleRaw = data["authorRole"] as? String,
            let authorRole = CoachingNoteAuthorRole(rawValue: authorRoleRaw),
            let message = data["message"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.authorId = authorId
        self.authorRole = authorRole
        self.message = message
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "authorId": authorId,
            "authorRole": authorRole.rawValue,
            "message": message,
            "createdAt": createdAt
        ]
    }
}

@MainActor
final class ClientCoachingHomeStore: ObservableObject {
    @Published private(set) var checkIns: [ProgressCheckIn] = []
    @Published private(set) var updateRequests: [ProfileUpdateRequest] = []
    @Published private(set) var notes: [CoachingNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let clientId: String
    private let trainerId: String
    private let firestore: Firestore

    init(clientId: String, trainerId: String, firestore: Firestore = .firestore()) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let checkInsSnapshot = firestore
                .collection("progress_checkins")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            async let requestsSnapshot = firestore
                .collection("profile_update_requests")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            async let notesSnapshot = firestore
                .collection("coaching_notes")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            let (checkInDocs, requestDocs, noteDocs) = try await (checkInsSnapshot, requestsSnapshot, notesSnapshot)

            checkIns = checkInDocs.documents.compactMap { ProgressCheckIn(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            updateRequests = requestDocs.documents.compactMap { ProfileUpdateRequest(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            notes = noteDocs.documents.compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func submitCheckIn(
        weight: Double,
        waist: Double,
        chest: Double,
        hips: Double,
        energy: Int,
        adherence: Int,
        notes: String
    ) async {
        isSubmitting = true
        errorMessage = nil

        let checkIn = ProgressCheckIn(
            id: UUID().uuidString,
            clientId: clientId,
            trainerId: trainerId,
            weight: weight,
            waist: waist,
            chest: chest,
            hips: hips,
            energy: energy,
            adherence: adherence,
            notes: notes
        )

        do {
            try await firestore
                .collection("progress_checkins")
                .document(checkIn.id)
                .setData(checkIn.firestoreData)
            isSubmitting = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }

    func sendNote(_ message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let note = CoachingNote(
            id: UUID().uuidString,
            clientId: clientId,
            trainerId: trainerId,
            authorId: clientId,
            authorRole: .client,
            message: trimmed
        )

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .setData(note.firestoreData)
            isSubmitting = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }

    func resolveUpdateRequest(_ request: ProfileUpdateRequest) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("profile_update_requests")
                .document(request.id)
                .setData([
                    "status": "resolved",
                    "resolvedAt": Date()
                ], merge: true)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TrainerClientSupportStore: ObservableObject {
    @Published private(set) var intake: ClientIntakeProfile?
    @Published private(set) var activeLink: TrainerClientLink?
    @Published private(set) var checkIns: [ProgressCheckIn] = []
    @Published private(set) var updateRequests: [ProfileUpdateRequest] = []
    @Published private(set) var notes: [CoachingNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let trainerId: String
    private let client: AppUserProfile
    private let firestore: Firestore

    init(trainerId: String, client: AppUserProfile, firestore: Firestore = .firestore()) {
        self.trainerId = trainerId
        self.client = client
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let intakeSnapshot = firestore
                .collection("client_intakes")
                .document(client.id)
                .getDocument()

            async let activeLinkSnapshot = firestore
                .collection("trainer_client_links")
                .document("\(trainerId)_\(client.id)")
                .getDocument()

            async let checkInsSnapshot = firestore
                .collection("progress_checkins")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let requestsSnapshot = firestore
                .collection("profile_update_requests")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let notesSnapshot = firestore
                .collection("coaching_notes")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            let (intakeDoc, activeLinkDoc, checkInDocs, requestDocs, noteDocs) = try await (
                intakeSnapshot,
                activeLinkSnapshot,
                checkInsSnapshot,
                requestsSnapshot,
                notesSnapshot
            )

            intake = intakeDoc.data().flatMap { ClientIntakeProfile(id: intakeDoc.documentID, data: $0) }
            activeLink = activeLinkDoc.data().flatMap { TrainerClientLink(id: activeLinkDoc.documentID, data: $0) }

            checkIns = checkInDocs.documents.compactMap { ProgressCheckIn(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            updateRequests = requestDocs.documents.compactMap { ProfileUpdateRequest(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            notes = noteDocs.documents.compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func sendNote(_ message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let note = CoachingNote(
            id: UUID().uuidString,
            clientId: client.id,
            trainerId: trainerId,
            authorId: trainerId,
            authorRole: .trainer,
            message: trimmed
        )

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .setData(note.firestoreData)
            isSubmitting = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }

    func createUpdateRequest(type: ProfileUpdateRequestType, message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let request = ProfileUpdateRequest(
            id: UUID().uuidString,
            clientId: client.id,
            trainerId: trainerId,
            type: type,
            message: trimmed
        )

        do {
            try await firestore
                .collection("profile_update_requests")
                .document(request.id)
                .setData(request.firestoreData)
            isSubmitting = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

struct ClientCoachingHomeScreen: View {
    let clientId: String
    let trainerId: String
    let trainer: AppUserProfile?

    @StateObject private var store: ClientCoachingHomeStore
    @State private var showCheckInSheet = false
    @State private var noteMessage = ""

    init(clientId: String, trainerId: String, trainer: AppUserProfile?) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.trainer = trainer
        _store = StateObject(wrappedValue: ClientCoachingHomeStore(clientId: clientId, trainerId: trainerId))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let trainer {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalizer.string("coaching.linked.trainer"))
                            .font(.headline)
                        Text(trainer.displayName)
                            .font(.title3.weight(.semibold))
                        Text(trainer.email)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showCheckInSheet = true
                } label: {
                    Label(AppLocalizer.string("coaching.checkin.action.new"), systemImage: "waveform.path.ecg")
                }
            }

            Section(AppLocalizer.string("coaching.update_request.section")) {
                let openRequests = store.updateRequests.filter { $0.status == "open" }
                if openRequests.isEmpty {
                    Text(AppLocalizer.string("coaching.update_request.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(openRequests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppLocalizer.string(request.type.localizationKey))
                                .font(.headline)
                            Text(request.message)
                                .foregroundStyle(.secondary)
                            Button(AppLocalizer.string("coaching.update_request.action.resolve")) {
                                Task { await store.resolveUpdateRequest(request) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.checkin.history")) {
                if store.checkIns.isEmpty {
                    Text(AppLocalizer.string("coaching.checkin.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.checkIns.prefix(5)) { checkIn in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(checkIn.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Text("\(AppLocalizer.string("coaching.intake.weight")): \(String(format: "%.1f", checkIn.weight)) \(AppLocalizer.string("coaching.unit.kg"))")
                                .foregroundStyle(.secondary)
                            Text("\(AppLocalizer.string("coaching.checkin.energy")): \(checkIn.energy)/5  •  \(AppLocalizer.string("coaching.checkin.adherence")): \(checkIn.adherence)/5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if checkIn.notes.isEmpty == false {
                                Text(checkIn.notes)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.notes.section")) {
                TextField(AppLocalizer.string("coaching.notes.placeholder.client"), text: $noteMessage, axis: .vertical)
                    .lineLimit(2...5)

                Button {
                    Task {
                        await store.sendNote(noteMessage)
                        if store.errorMessage == nil {
                            noteMessage = ""
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.notes.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || noteMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if store.notes.isEmpty {
                    Text(AppLocalizer.string("coaching.notes.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.notes.prefix(10)) { note in
                        CoachingNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("workouts.connection"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(isPresented: $showCheckInSheet) {
            NavigationStack {
                ClientCheckInFormScreen(store: store)
            }
        }
    }
}

private struct ClientCheckInFormScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 70
    @State private var waist: Double = 80
    @State private var chest: Double = 95
    @State private var hips: Double = 95
    @State private var energy = 3
    @State private var adherence = 3
    @State private var notes = ""

    var body: some View {
        Form {
            Section(AppLocalizer.string("coaching.checkin.section.metrics")) {
                metricField(AppLocalizer.string("coaching.intake.weight"), value: $weight, unit: AppLocalizer.string("coaching.unit.kg"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.waist"), value: $waist, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.chest"), value: $chest, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.hips"), value: $hips, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
            }

            Section(AppLocalizer.string("coaching.checkin.section.state")) {
                Stepper("\(AppLocalizer.string("coaching.checkin.energy")): \(energy)/5", value: $energy, in: 1...5)
                Stepper("\(AppLocalizer.string("coaching.checkin.adherence")): \(adherence)/5", value: $adherence, in: 1...5)
                TextField(AppLocalizer.string("coaching.checkin.notes"), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    Task {
                        await store.submitCheckIn(
                            weight: weight,
                            waist: waist,
                            chest: chest,
                            hips: hips,
                            energy: energy,
                            adherence: adherence,
                            notes: notes
                        )
                        if store.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.checkin.action.submit"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting)
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.cancel")) {
                    dismiss()
                }
            }
        }
    }

    private func metricField(
        _ title: String,
        value: Binding<Double>,
        unit: String,
        precision: FloatingPointFormatStyle<Double>.Configuration.Precision
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(precision))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

struct TrainerClientSupportScreen: View {
    let trainerId: String
    let client: AppUserProfile

    @StateObject private var store: TrainerClientSupportStore
    @State private var requestType: ProfileUpdateRequestType = .generalUpdate
    @State private var requestMessage = ""
    @State private var noteMessage = ""
    @FocusState private var focusedField: TrainerWorkspaceField?

    init(trainerId: String, client: AppUserProfile) {
        self.trainerId = trainerId
        self.client = client
        _store = StateObject(wrappedValue: TrainerClientSupportStore(trainerId: trainerId, client: client))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                TrainerClientWorkspaceSummary(
                    client: client,
                    intake: store.intake,
                    activeLink: store.activeLink,
                    lastCheckIn: store.checkIns.first,
                    openRequestCount: openRequests.count,
                    lastNote: store.notes.first
                )
            }

            Section(AppLocalizer.string("coaching.workspace.quick_actions")) {
                Button {
                    focusedField = .updateRequest
                } label: {
                    Label(AppLocalizer.string("coaching.workspace.action.request_update"), systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    focusedField = .note
                } label: {
                    Label(AppLocalizer.string("coaching.workspace.action.add_note"), systemImage: "square.and.pencil")
                }
            }

            if let intake = store.intake {
                Section(AppLocalizer.string("coaching.workspace.intake")) {
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.goal"),
                        value: AppLocalizer.string(intake.goal.localizationKey)
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.weight"),
                        value: "\(String(format: "%.1f", intake.weight)) \(AppLocalizer.string("coaching.unit.kg"))"
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.height"),
                        value: "\(String(format: "%.0f", intake.height)) \(AppLocalizer.string("coaching.unit.cm"))"
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.activity"),
                        value: AppLocalizer.string(intake.activity.localizationKey)
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.experience"),
                        value: AppLocalizer.string(intake.experience.localizationKey)
                    )

                    if intake.limitations.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.limitations"),
                            value: intake.limitations
                        )
                    }

                    if intake.equipment.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.equipment"),
                            value: intake.equipment
                        )
                    }

                    if intake.schedule.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.schedule"),
                            value: intake.schedule
                        )
                    }

                    if intake.notes.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.notes"),
                            value: intake.notes
                        )
                    }
                }
            }

            Section(AppLocalizer.string("coaching.update_request.section")) {
                Picker(AppLocalizer.string("coaching.update_request.type"), selection: $requestType) {
                    ForEach(ProfileUpdateRequestType.allCases) { type in
                        Text(AppLocalizer.string(type.localizationKey)).tag(type)
                    }
                }

                TextField(AppLocalizer.string("coaching.update_request.message"), text: $requestMessage, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .updateRequest)

                Button {
                    Task {
                        await store.createUpdateRequest(type: requestType, message: requestMessage)
                        if store.errorMessage == nil {
                            requestMessage = ""
                            requestType = .generalUpdate
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.update_request.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || requestMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if openRequests.isEmpty == false {
                    ForEach(openRequests) { request in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppLocalizer.string(request.type.localizationKey))
                                .font(.headline)
                            Text(request.message)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.checkin.history")) {
                if store.checkIns.isEmpty {
                    Text(AppLocalizer.string("coaching.checkin.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.checkIns) { checkIn in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(checkIn.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Text("\(AppLocalizer.string("coaching.intake.weight")): \(String(format: "%.1f", checkIn.weight)) \(AppLocalizer.string("coaching.unit.kg"))")
                                .foregroundStyle(.secondary)
                            Text("\(AppLocalizer.string("coaching.intake.measurement.waist")): \(String(format: "%.1f", checkIn.waist)) • \(AppLocalizer.string("coaching.intake.measurement.chest")): \(String(format: "%.1f", checkIn.chest)) • \(AppLocalizer.string("coaching.intake.measurement.hips")): \(String(format: "%.1f", checkIn.hips))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(AppLocalizer.string("coaching.checkin.energy")): \(checkIn.energy)/5  •  \(AppLocalizer.string("coaching.checkin.adherence")): \(checkIn.adherence)/5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if checkIn.notes.isEmpty == false {
                                Text(checkIn.notes)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.notes.section")) {
                TextField(AppLocalizer.string("coaching.notes.placeholder.trainer"), text: $noteMessage, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .note)

                Button {
                    Task {
                        await store.sendNote(noteMessage)
                        if store.errorMessage == nil {
                            noteMessage = ""
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.notes.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || noteMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if store.notes.isEmpty {
                    Text(AppLocalizer.string("coaching.notes.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.notes) { note in
                        CoachingNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(client.displayName)
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }

    private var openRequests: [ProfileUpdateRequest] {
        store.updateRequests.filter { $0.status == "open" }
    }
}

private struct CoachingNoteRow: View {
    let note: CoachingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalizer.string(note.authorRole == .trainer ? "coaching.notes.author.trainer" : "coaching.notes.author.client"))
                .font(.headline)
            Text(note.message)
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private enum TrainerWorkspaceField: Hashable {
    case updateRequest
    case note
}

private struct TrainerClientWorkspaceSummary: View {
    let client: AppUserProfile
    let intake: ClientIntakeProfile?
    let activeLink: TrainerClientLink?
    let lastCheckIn: ProgressCheckIn?
    let openRequestCount: Int
    let lastNote: CoachingNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(client.displayName)
                    .font(.title3.weight(.semibold))
                Text(client.email)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.goal"),
                    value: intake.map { AppLocalizer.string($0.goal.localizationKey) } ?? "—"
                )
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.weight"),
                    value: intake.map { "\(String(format: "%.1f", $0.weight))" } ?? "—",
                    suffix: intake == nil ? nil : AppLocalizer.string("coaching.unit.kg")
                )
            }

            HStack(spacing: 12) {
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.last_checkin"),
                    value: lastCheckIn.map { $0.createdAt.formatted(date: .abbreviated, time: .omitted) } ?? "—"
                )
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.open_requests"),
                    value: "\(openRequestCount)"
                )
            }

            if let activeLink {
                Label(
                    "\(AppLocalizer.string("coaching.workspace.connected_since")) \(activeLink.createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "link"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let lastNote, lastNote.message.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.string("coaching.workspace.last_note"))
                        .font(.headline)
                    Text(lastNote.message)
                        .font(.subheadline)
                    Text(lastNote.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkspaceMetricCard: View {
    let title: String
    let value: String
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.headline)
                if let suffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TrainerWorkspaceInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrainerWorkspaceTextBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
