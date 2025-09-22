import SwiftUI
import MessageUI
import StoreKit

// MARK: - Settings

struct SettingsScreen: View {
    // заполни под себя
    private let appStoreID = "1234567890"                                       // ← твой App Store ID
    private let shareURL   = URL(string: "https://apps.apple.com/app/id1234567890")!
    private let devEmail   = "87v87@mail.ru"

    @State private var showAbout = false
    @State private var showMailView = false
    @State private var mailResult: MFMailComposeResult? = nil
    @State private var showMailErrorAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Поделиться
                    ShareLink(item: shareURL,
                              subject: Text("Попробуй это приложение")) {
                        SettingsRow(icon: "square.and.arrow.up",
                                    iconBg: .purple, title: "Поделиться с друзьями")
                    }

                    // Оценить приложение
                    Button { rateApp() } label: {
                        SettingsRow(icon: "star.fill",
                                    iconBg: .yellow, title: "Оценить приложение")
                    }

                    // Написать разработчикам
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMailView = true
                        } else {
                            // Fallback: попробуем открыть mailto:
                            let subject = "Обратная связь — \(Bundle.main.appDisplayName) \(Bundle.main.appVersionBuild)".urlEncoded
                            let body = defaultMailBody().urlEncoded
                            if let url = URL(string: "mailto:\(devEmail)?subject=\(subject)&body=\(body)") {
                                UIApplication.shared.open(url)
                            } else {
                                showMailErrorAlert = true
                            }
                        }
                    } label: {
                        SettingsRow(icon: "envelope.fill",
                                    iconBg: .green, title: "Написать разработчикам")
                    }
                }

                Section {
                    Button { showAbout = true } label: {
                        SettingsRow(icon: "info.circle.fill",
                                    iconBg: .blue, title: "О приложении")
                    }
                }
            }
            .navigationTitle("Настройки")
        }
        .tint(.blue)
        .sheet(isPresented: $showMailView) {
            MailComposeView(
                showMailView: $showMailView,
                result: $mailResult,
                to: [devEmail],
                subject: "Обратная связь — \(Bundle.main.appDisplayName) \(Bundle.main.appVersionBuild)",
                body: defaultMailBody()
            )
        }
        .sheet(isPresented: $showAbout) {
            AboutAppView()
        }
        .alert("На устройстве не настроена Почта",
               isPresented: $showMailErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Добавь почтовый аккаунт в настройках iOS или напиши нам на \(devEmail).")
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
        return """
Здравствуйте! Хочу оставить отзыв/вопрос:

(Опишите вашу ситуацию здесь)

— —
Техническая информация:
Приложение: \(Bundle.main.appDisplayName) \(Bundle.main.appVersionBuild)
Устройство: \(dev.model)
iOS: \(dev.systemName) \(dev.systemVersion)
"""
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Моё Питание!")
                        .font(.title).bold()
                    Text("""
Моё Питание! — это приложение-ассистент. Мы даём советы и помогаем отслеживать прогресс, \
но не ставим диагнозы и не назначаем лечение. Для медицинских вопросов обращайся к врачу.
""")
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("О приложении")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
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
