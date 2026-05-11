import SwiftUI
import MessageUI
import StoreKit
import SwiftData

// MARK: - Settings

struct SettingsScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.modelContext) private var modelContext

    // заполни под себя
    private let appStoreID = "1234567890"                                       // ← твой App Store ID
    private let shareURL   = URL(string: "https://apps.apple.com/app/id1234567890")!
    private let devEmail   = "87v87@mail.ru"
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @State private var showAbout = false
    @State private var showMailView = false
    @State private var mailResult: MFMailComposeResult? = nil
    @State private var showMailErrorAlert = false
    @State private var accountStatusMessage: String?
    @State private var isSendingEmailVerification = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    var body: some View {
        NavigationStack {
            List {

                Section {
                    CloudStatusRow()
                }

                if let firebaseUser = sessionStore.firebaseUser {
                    Section(appLanguage.localized("settings.account.section")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sessionStore.profile?.displayName ?? firebaseUser.displayName ?? "FitLife User")
                                .font(.headline)
                            Text(sessionStore.profile?.email ?? firebaseUser.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let role = sessionStore.profile?.role, role != .client {
                            HStack {
                                Text(appLanguage.localized("settings.account.role"))
                                Spacer()
                                Text(AppLocalizer.string(role.localizationKey))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text(appLanguage.localized("settings.account.email_status"))
                            Spacer()
                            Text(firebaseUser.isEmailVerified
                                 ? appLanguage.localized("settings.account.email_verified")
                                 : appLanguage.localized("settings.account.email_unverified"))
                                .foregroundStyle(firebaseUser.isEmailVerified ? Color.secondary : Color.orange)
                        }

                        if firebaseUser.isEmailVerified == false {
                            Button {
                                sendEmailVerification()
                            } label: {
                                if isSendingEmailVerification {
                                    ProgressView()
                                } else {
                                    Text(appLanguage.localized("settings.account.send_verification"))
                                }
                            }
                            .disabled(isSendingEmailVerification)

                            Button {
                                Task {
                                    await sessionStore.reloadCurrentUser()
                                }
                            } label: {
                                Text(appLanguage.localized("settings.account.refresh_verification"))
                            }
                        }

                        if let accountStatusMessage {
                            Text(accountStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            sessionStore.signOut()
                        } label: {
                            Text(appLanguage.localized("settings.account.sign_out"))
                        }

                        Button(role: .destructive) {
                            showDeleteAccountConfirmation = true
                        } label: {
                            if isDeletingAccount {
                                ProgressView()
                            } else {
                                Text(appLanguage.localized("settings.account.delete"))
                            }
                        }
                        .disabled(isDeletingAccount)
                    }
                }

                if sessionStore.currentRole == .owner {
                    Section(appLanguage.localized("settings.admin.section")) {
                        NavigationLink {
                            AdminUsersScreen()
                        } label: {
                            SettingsRow(
                                icon: "person.3.fill",
                                iconBg: .indigo,
                                title: appLanguage.localized("settings.admin.users")
                            )
                        }

                        NavigationLink {
                            TrainerClientLinksScreen()
                        } label: {
                            SettingsRow(
                                icon: "link",
                                iconBg: .teal,
                                title: appLanguage.localized("settings.admin.links")
                            )
                        }

                        if let currentUser = sessionStore.profile {
                            NavigationLink {
                                CoachingRequestsReviewScreen(currentUser: currentUser)
                            } label: {
                                SettingsRow(
                                    icon: "text.badge.checkmark",
                                    iconBg: .mint,
                                    title: appLanguage.localized("settings.admin.requests")
                                )
                            }
                        }
                    }
                }

                if sessionStore.currentRole == .trainer,
                   let trainerId = sessionStore.firebaseUser?.uid,
                   let currentUser = sessionStore.profile {
                    Section(appLanguage.localized("settings.trainer.section")) {
                        NavigationLink {
                            TrainerAssignedClientsScreen(trainerId: trainerId)
                        } label: {
                            SettingsRow(
                                icon: "person.2.fill",
                                iconBg: .green,
                                title: appLanguage.localized("settings.trainer.clients")
                            )
                        }

                        NavigationLink {
                            WorkoutTemplatesScreen(trainerId: trainerId)
                        } label: {
                            SettingsRow(
                                icon: "doc.text.fill",
                                iconBg: .orange,
                                title: appLanguage.localized("settings.trainer.templates")
                            )
                        }

                        NavigationLink {
                            TrainerAssignmentsOverviewScreen(trainerId: trainerId)
                        } label: {
                            SettingsRow(
                                icon: "list.bullet.clipboard",
                                iconBg: .pink,
                                title: appLanguage.localized("settings.trainer.assignments")
                            )
                        }

                        NavigationLink {
                            CoachingRequestsReviewScreen(currentUser: currentUser)
                        } label: {
                            SettingsRow(
                                icon: "text.badge.checkmark",
                                iconBg: .mint,
                                title: appLanguage.localized("settings.trainer.requests")
                            )
                        }
                    }
                }

                Section(appLanguage.localized("settings.language.section")) {
                    Picker(
                        appLanguage.localized("settings.language.label"),
                        selection: $appLanguageRaw
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "bell.fill",
                            iconBg: .red,
                            title: appLanguage.localized("notifications.title")
                        )
                    }
                }

                Section {
                    // Поделиться
                    ShareLink(item: shareURL,
                              subject: Text(appLanguage.localized("settings.share.subject"))) {
                        SettingsRow(icon: "square.and.arrow.up",
                                    iconBg: .purple,
                                    title: appLanguage.localized("settings.share.title"))
                    }

                    // Оценить приложение
                    Button { rateApp() } label: {
                        SettingsRow(icon: "star.fill",
                                    iconBg: .yellow,
                                    title: appLanguage.localized("settings.rate.title"))
                    }

                    // Написать разработчикам
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMailView = true
                        } else {
                            // Fallback: попробуем открыть mailto:
                            let subject = mailSubject.urlEncoded
                            let body = defaultMailBody().urlEncoded
                            if let url = URL(string: "mailto:\(devEmail)?subject=\(subject)&body=\(body)") {
                                UIApplication.shared.open(url)
                            } else {
                                showMailErrorAlert = true
                            }
                        }
                    } label: {
                        SettingsRow(icon: "envelope.fill",
                                    iconBg: .green,
                                    title: appLanguage.localized("settings.contact.title"))
                    }
                }

                Section {
                    Button { showAbout = true } label: {
                        SettingsRow(icon: "info.circle.fill",
                                    iconBg: .blue,
                                    title: appLanguage.localized("settings.about.title"))
                    }
                }
            }
            .navigationTitle(appLanguage.localized("settings.title"))
        }
        .tint(.blue)
        .sheet(isPresented: $showMailView) {
            MailComposeView(
                showMailView: $showMailView,
                result: $mailResult,
                to: [devEmail],
                subject: mailSubject,
                body: defaultMailBody()
            )
        }
        .sheet(isPresented: $showAbout) {
            AboutAppView(language: appLanguage)
        }
        .alert(appLanguage.localized("settings.mail.alert.title"),
               isPresented: $showMailErrorAlert) {
            Button(AppLocalizer.string("common.ok"), role: .cancel) {}
        } message: {
            Text(String(format: appLanguage.localized("settings.mail.alert.message"), devEmail))
        }
        .alert(appLanguage.localized("settings.account.delete.alert.title"),
               isPresented: $showDeleteAccountConfirmation) {
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
            Button(appLanguage.localized("settings.account.delete.alert.confirm"), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(appLanguage.localized("settings.account.delete.alert.message"))
        }
    }

    private func sendEmailVerification() {
        isSendingEmailVerification = true
        accountStatusMessage = nil

        Task {
            let didSend = await sessionStore.sendEmailVerification()
            if didSend {
                accountStatusMessage = appLanguage.localized("settings.account.verification_sent")
            } else {
                accountStatusMessage = sessionStore.authErrorMessage ?? AppLocalizer.string("common.error.try_again")
            }
            isSendingEmailVerification = false
        }
    }

    private func deleteAccount() {
        guard let ownerId = sessionStore.firebaseUser?.uid else { return }
        isDeletingAccount = true
        accountStatusMessage = nil

        Task {
            deleteLocalData(for: ownerId)
            let didDelete = await sessionStore.deleteCurrentAccount()
            if didDelete == false {
                accountStatusMessage = appLanguage.localized("settings.account.delete.failed")
            }
            isDeletingAccount = false
        }
    }

    private func deleteLocalData(for ownerId: String) {
        do {
            try deleteSwiftDataItems(FetchDescriptor<FoodEntry>(), ownerId: ownerId) { $0.ownerId }
            try deleteSwiftDataItems(FetchDescriptor<WaterIntake>(), ownerId: ownerId) { $0.ownerId }
            try deleteSwiftDataItems(FetchDescriptor<BodyMeasurements>(), ownerId: ownerId) { $0.ownerId }
            try deleteSwiftDataItems(FetchDescriptor<WorkoutSession>(), ownerId: ownerId) { $0.ownerId }
            try deleteSwiftDataItems(FetchDescriptor<UserData>(), ownerId: ownerId) { $0.ownerId }
            try modelContext.save()
        } catch {
            accountStatusMessage = AppErrorPresenter.message(for: error)
        }
    }

    private func deleteSwiftDataItems<T>(
        _ descriptor: FetchDescriptor<T>,
        ownerId: String,
        itemOwnerId: (T) -> String
    ) throws where T: PersistentModel {
        let items = try modelContext.fetch(descriptor)
        for item in items where itemOwnerId(item) == ownerId {
            modelContext.delete(item)
        }
    }

    // MARK: Actions

    private func rateApp() {
        // Попытка через системный промпт внутри приложения
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        // Подстраховка: открываем страницу отзыва в App Store
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func defaultMailBody() -> String {
        let dev = UIDevice.current
        return String(
            format: appLanguage.localized("settings.mail.body"),
            Bundle.main.appDisplayName,
            Bundle.main.appVersionBuild,
            dev.model,
            dev.systemName,
            dev.systemVersion
        )
    }

    private var mailSubject: String {
        String(
            format: appLanguage.localized("settings.mail.subject"),
            Bundle.main.appDisplayName,
            Bundle.main.appVersionBuild
        )
    }
}

// MARK: - Row view

private struct SettingsRow: View {
    let icon: String
    let iconBg: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg.gradient)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
        }
    }
}

// MARK: - About

private struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(language.localized("about.app_name"))
                        .font(.title).bold()
                    Text(language.localized("about.description"))
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(language.localized("settings.about.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(language.localized("common.close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mail composer (UIKit bridge)

struct MailComposeView: UIViewControllerRepresentable {
    @Binding var showMailView: Bool
    @Binding var result: MFMailComposeResult?

    var to: [String]
    var subject: String
    var body: String
    var isHTML: Bool = false

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(to)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: isHTML)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        init(_ parent: MailComposeView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            parent.result = result
            parent.showMailView = false
        }
    }
}

// MARK: - Small helpers

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

private extension Bundle {
    var appDisplayName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "App"
    }
    var appVersionBuild: String {
        let v = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
