import SwiftUI

private let authCardBackground = Color(.secondarySystemBackground)
private let authCardBorder = Color(.separator).opacity(0.22)

struct AuthScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalizer.string("auth.title"))
                        .font(.largeTitle.bold())
                    Text(AppLocalizer.string("auth.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $mode) {
                    Text(AppLocalizer.string("auth.mode.sign_in")).tag(AuthMode.signIn)
                    Text(AppLocalizer.string("auth.mode.sign_up")).tag(AuthMode.signUp)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 14) {
                    if mode == .signUp {
                        authField(
                            title: AppLocalizer.string("auth.name"),
                            text: $name,
                            keyboardType: .default,
                            textContentType: .name
                        )
                    }

                    authField(
                        title: AppLocalizer.string("auth.email"),
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never
                    )

                    SecureField(AppLocalizer.string("auth.password"), text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(authCardBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(authCardBorder)
                        )

                    if mode == .signIn {
                        Button(AppLocalizer.string("auth.action.reset_password")) {
                            resetPassword()
                        }
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(sessionStore.isLoading)
                    }
                }

                if let authErrorMessage = sessionStore.authErrorMessage, authErrorMessage.isEmpty == false {
                    Text(authErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let statusMessage, statusMessage.isEmpty == false {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack {
                        if sessionStore.isLoading {
                            ProgressView()
                                .tint(Color(.systemBackground))
                        } else {
                            Text(mode == .signIn ? AppLocalizer.string("auth.action.sign_in") : AppLocalizer.string("auth.action.sign_up"))
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitDisabled || sessionStore.isLoading)
                .opacity(isSubmitDisabled || sessionStore.isLoading ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    private var isSubmitDisabled: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode == .signUp {
            return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || trimmedEmail.isEmpty || trimmedPassword.count < 6
        }

        return trimmedEmail.isEmpty || trimmedPassword.isEmpty
    }

    private func submit() {
        statusMessage = nil
        Task {
            switch mode {
            case .signIn:
                await sessionStore.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            case .signUp:
                await sessionStore.signUp(
                    name: name,
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            }
        }
    }

    private func resetPassword() {
        statusMessage = nil
        Task {
            let didSend = await sessionStore.sendPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if didSend {
                statusMessage = AppLocalizer.string("auth.reset.sent")
            }
        }
    }

    private func authField(
        title: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType,
        autocapitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(authCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(authCardBorder)
            )
    }
}

private enum AuthMode {
    case signIn
    case signUp
}
