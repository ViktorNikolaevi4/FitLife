import SwiftUI
import MessageUI
import StoreKit

// MARK: - Settings

struct SettingsScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    // заполни под себя
    private let appStoreID = "1234567890"                                       // ← твой App Store ID
    private let shareURL   = URL(string: "https://apps.apple.com/app/id1234567890")!
    private let devEmail   = "87v87@mail.ru"
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @State private var showAbout = false
    @State private var showMailView = false
    @State private var mailResult: MFMailComposeResult? = nil
    @State private var showMailErrorAlert = false

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

                        if let role = sessionStore.profile?.role {
                            HStack {
                                Text(appLanguage.localized("settings.account.role"))
                                Spacer()
                                Text(AppLocalizer.string(role.localizationKey))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            sessionStore.signOut()
                        } label: {
                            Text(appLanguage.localized("settings.account.sign_out"))
                        }
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
