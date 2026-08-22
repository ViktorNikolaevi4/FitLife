import SwiftUI

struct DashboardTrainerConnectionCard: View {
    let clientId: String
    let profile: AppUserProfile
    let localUserData: UserData?
    let theme: AppTheme
    let onOpenConnection: () -> Void
    let onOpenChat: () -> Void
    let onOpenReports: () -> Void
    let onOpenAssignment: (WorkoutAssignment) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @StateObject private var store: ClientCoachingStore
    @State private var hasCompletedInitialLoad = false

    init(
        clientId: String,
        profile: AppUserProfile,
        localUserData: UserData?,
        theme: AppTheme,
        onOpenConnection: @escaping () -> Void,
        onOpenChat: @escaping () -> Void,
        onOpenReports: @escaping () -> Void,
        onOpenAssignment: @escaping (WorkoutAssignment) -> Void
    ) {
        self.clientId = clientId
        self.profile = profile
        self.localUserData = localUserData
        self.theme = theme
        self.onOpenConnection = onOpenConnection
        self.onOpenChat = onOpenChat
        self.onOpenReports = onOpenReports
        self.onOpenAssignment = onOpenAssignment
        _store = StateObject(wrappedValue: ClientCoachingStore(clientId: clientId))
    }

    var body: some View {
        Group {
            if store.isLoading && !store.hasLoadedInitialState {
                loadingCard
            } else if store.activeLink != nil {
                activeTrainerCard
            } else if isRequestPending {
                pendingRequestCard
            } else if store.errorMessage != nil {
                errorCard
            } else {
                disconnectedCard
            }
        }
        .padding(.horizontal)
        .task(id: refreshKey) {
            await refresh()
            hasCompletedInitialLoad = true
        }
        .onAppear {
            guard hasCompletedInitialLoad, store.hasLoadedInitialState else { return }
            Task { await refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.hasLoadedInitialState else { return }
            Task { await refresh() }
        }
    }

    private var isRequestPending: Bool {
        guard let status = store.request?.status else { return false }
        return status == .submitted || status == .approved || status == .assigned
    }

    private var unreadTrainerNotifications: [AppNotificationEvent] {
        notificationsStore.notifications.filter { event in
            guard !event.isRead else { return false }
            guard event.type == .coachNoteReceived || event.type == .workoutAssigned else { return false }
            guard let trainerId = store.activeLink?.trainerId else { return true }
            return event.senderId == trainerId
        }
    }

    private var hasUnreadTrainerMessage: Bool {
        unreadTrainerNotifications.contains { $0.type == .coachNoteReceived }
    }

    private var refreshKey: String {
        let eventIDs = notificationsStore.notifications
            .filter { $0.type == .coachNoteReceived || $0.type == .workoutAssigned }
            .map(\.id)
            .sorted()
            .joined(separator: ",")
        return "\(clientId)|\(eventIDs)"
    }

    private var activeTrainerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenConnection) {
                HStack(spacing: 14) {
                    trainerAvatar

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(trainerName)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)

                            if hasUnreadTrainerMessage {
                                Image(systemName: "envelope.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 26, height: 26)
                                    .background(theme.accent.opacity(0.12), in: Circle())
                                    .accessibilityLabel(AppLocalizer.string("dashboard.coach.new_message"))
                            }

                            if !unreadTrainerNotifications.isEmpty {
                                Text("\(unreadTrainerNotifications.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red, in: Capsule())
                            }
                        }

                        HStack(spacing: 6) {
                            Text(AppLocalizer.string("dashboard.coach.your_trainer"))
                            if store.isUsingCachedData {
                                Image(systemName: "cloud.slash")
                                    .accessibilityLabel(AppLocalizer.string("dashboard.coach.cached_data"))
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                    }

                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().overlay(theme.divider)

            Button(action: openLatestEvent) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: latestEventIcon)
                                .font(.caption.weight(.semibold))
                                .frame(width: 16, height: 16)
                                .accessibilityHidden(true)

                            Text(latestEventTitle)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isLatestEventUnread ? theme.accent : theme.secondaryText)

                        Spacer()
                        if let date = latestTrainerEvent?.date {
                            Text(messageDateText(date))
                                .font(.caption)
                                .foregroundStyle(theme.tertiaryText)
                        }
                    }

                    Text(latestEventText)
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .topLeading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                if case let .assignment(assignment) = latestTrainerEvent {
                    actionButton(
                        title: AppLocalizer.string("dashboard.coach.open_workout"),
                        icon: "dumbbell",
                        emphasized: true,
                        action: { openAssignment(assignment) }
                    )
                    actionButton(
                        title: AppLocalizer.string("dashboard.coach.write"),
                        icon: "bubble.left",
                        emphasized: false,
                        action: openChat
                    )
                } else {
                    actionButton(
                        title: AppLocalizer.string("dashboard.coach.write"),
                        icon: "bubble.left",
                        emphasized: false,
                        action: openChat
                    )
                    actionButton(
                        title: AppLocalizer.string("dashboard.coach.send_report"),
                        icon: "doc.text",
                        emphasized: true,
                        action: onOpenReports
                    )
                }
            }
        }
        .padding(20)
        .adaptiveHomeCard(theme: theme, cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(isLatestEventUnread ? theme.accent : .clear, lineWidth: 1.2)
        }
    }

    private var pendingRequestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                symbolCircle("person.badge.clock", color: theme.accent, size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalizer.string("dashboard.coach.connection_title"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(AppLocalizer.string("dashboard.coach.request_sent"))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            HStack(spacing: 12) {
                symbolCircle("clock", color: .orange, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalizer.string("dashboard.coach.awaiting"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(AppLocalizer.string("dashboard.coach.awaiting.subtitle"))
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.subtleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            outlineButton(
                title: AppLocalizer.string("dashboard.coach.details"),
                icon: "info.circle",
                action: onOpenConnection
            )
        }
        .padding(20)
        .adaptiveHomeCard(theme: theme, cornerRadius: 26)
    }

    private var disconnectedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                symbolCircle("person.crop.circle", color: theme.accent, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppLocalizer.string("dashboard.coach.personal_title"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(AppLocalizer.string("dashboard.coach.personal_subtitle"))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            benefitRow(
                icon: "list.clipboard",
                title: AppLocalizer.string("dashboard.coach.benefit.programs"),
                subtitle: AppLocalizer.string("dashboard.coach.benefit.programs.subtitle")
            )
            benefitRow(
                icon: "bubble.left.and.text.bubble.right",
                title: AppLocalizer.string("dashboard.coach.benefit.feedback"),
                subtitle: AppLocalizer.string("dashboard.coach.benefit.feedback.subtitle")
            )

            actionButton(
                title: AppLocalizer.string("dashboard.coach.connect"),
                icon: "person.badge.plus",
                emphasized: true,
                action: onOpenConnection
            )
        }
        .padding(20)
        .adaptiveHomeCard(theme: theme, cornerRadius: 26)
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.string("dashboard.coach.loading"))
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Text(AppLocalizer.string("dashboard.coach.loading.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveHomeCard(theme: theme, cornerRadius: 26)
    }

    private var errorCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.string("dashboard.coach.load_failed"))
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Button(AppLocalizer.string("dashboard.coach.retry")) {
                    Task { await refresh() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveHomeCard(theme: theme, cornerRadius: 26)
    }

    private var trainerName: String {
        let name = store.trainerProfile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? AppLocalizer.string("dashboard.coach.trainer") : name
    }

    private var trainerAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [theme.accent, theme.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))

            if
                let urlString = store.trainerProfile?.photoURL,
                let url = URL(string: urlString) {
                CachedTrainerAvatarImage(
                    url: url,
                    cacheKey: store.trainerProfile?.id ?? clientId,
                    placeholder: { trainerInitialsView }
                )
            } else {
                trainerInitialsView
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay(Circle().stroke(theme.border.opacity(0.55), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var trainerInitialsView: some View {
        Text(trainerInitials)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
    }

    private var trainerInitials: String {
        let initials = trainerName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "T" : initials.uppercased()
    }

    private var latestTrainerEvent: LatestTrainerEvent? {
        switch (store.latestNote, store.latestActiveAssignment) {
        case let (note?, assignment?):
            return note.createdAt >= assignment.assignedAt ? .note(note) : .assignment(assignment)
        case let (note?, nil):
            return .note(note)
        case let (nil, assignment?):
            return .assignment(assignment)
        case (nil, nil):
            return nil
        }
    }

    private var latestEventTitle: String {
        switch latestTrainerEvent {
        case .note:
            return AppLocalizer.string(isLatestEventUnread ? "dashboard.coach.new_message" : "dashboard.coach.trainer_comment")
        case .assignment:
            return AppLocalizer.string(isLatestEventUnread ? "dashboard.coach.new_workout" : "dashboard.coach.assigned_workout")
        case nil:
            return AppLocalizer.string("dashboard.coach.connection_active")
        }
    }

    private var latestEventText: String {
        switch latestTrainerEvent {
        case let .note(note): return note.message
        case let .assignment(assignment): return assignment.titleSnapshot
        case nil: return AppLocalizer.string("dashboard.coach.no_messages")
        }
    }

    private var latestEventIcon: String {
        switch latestTrainerEvent {
        case .note: return "bubble.left.fill"
        case .assignment: return "dumbbell.fill"
        case nil: return "checkmark.circle.fill"
        }
    }

    private var isLatestEventUnread: Bool {
        guard let event = latestTrainerEvent else { return false }
        return unreadTrainerNotifications.contains {
            $0.type == event.notificationType && $0.targetId == event.id
        }
    }

    private func symbolCircle(_ icon: String, color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(theme.isDark ? 0.15 : 0.10))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: size * 0.40, weight: .medium))
                    .foregroundStyle(color)
            }
    }

    private func messageDateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(width: 38, height: 38)
                .background(theme.accent.opacity(theme.isDark ? 0.14 : 0.09), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.primaryText)
                Text(subtitle).font(.caption).foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        emphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(emphasized ? Color.white : theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(emphasized ? AnyShapeStyle(LinearGradient(colors: [theme.accent, theme.accentDeep], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(theme.subtleFill))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func outlineButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(theme.accent.opacity(0.8), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func openChat() {
        let notifications = unreadTrainerNotifications.filter { $0.type == .coachNoteReceived }
        onOpenChat()
        Task {
            for notification in notifications {
                await notificationsStore.markRead(notification)
            }
        }
    }

    private func openAssignment(_ assignment: WorkoutAssignment) {
        let notifications = unreadTrainerNotifications.filter {
            $0.type == .workoutAssigned && $0.targetId == assignment.id
        }
        onOpenAssignment(assignment)
        Task {
            for notification in notifications {
                await notificationsStore.markRead(notification)
            }
        }
    }

    private func openLatestEvent() {
        switch latestTrainerEvent {
        case .note: openChat()
        case let .assignment(assignment): openAssignment(assignment)
        case nil: onOpenConnection()
        }
    }

    @MainActor
    private func refresh() async {
        await store.load(profile: profile, localUserData: localUserData, latestMeasurements: nil)
    }
}

private struct CachedTrainerAvatarImage<Placeholder: View>: View {
    let url: URL
    private let cacheKey: String
    private let placeholder: Placeholder
    @State private var image: UIImage?

    init(
        url: URL,
        cacheKey: String,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey
        self.placeholder = placeholder()
        _image = State(initialValue: Self.readCachedImage(cacheKey: cacheKey))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url.absoluteString) {
            await refreshImage()
        }
    }

    private func refreshImage() async {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode),
            let downloadedImage = UIImage(data: data)
        else {
            return
        }

        image = downloadedImage
        try? Self.save(data: data, cacheKey: cacheKey)
    }

    private static func readCachedImage(cacheKey: String) -> UIImage? {
        guard let url = cacheURL(cacheKey: cacheKey) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func save(data: Data, cacheKey: String) throws {
        guard let url = cacheURL(cacheKey: cacheKey) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func cacheURL(cacheKey: String) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let safeKey = cacheKey.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return root
            .appendingPathComponent("FitLifeTrainerAvatars", isDirectory: true)
            .appendingPathComponent("\(safeKey).image")
    }
}

private enum LatestTrainerEvent {
    case note(CoachingNote)
    case assignment(WorkoutAssignment)

    var id: String {
        switch self {
        case let .note(note): return note.id
        case let .assignment(assignment): return assignment.id
        }
    }

    var date: Date {
        switch self {
        case let .note(note): return note.createdAt
        case let .assignment(assignment): return assignment.assignedAt
        }
    }

    var notificationType: AppNotificationEventType {
        switch self {
        case .note: return .coachNoteReceived
        case .assignment: return .workoutAssigned
        }
    }
}
