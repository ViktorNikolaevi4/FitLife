import SwiftUI

struct AuthScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var statusMessage: String?

    var body: some View {
        let theme = AppTheme(colorScheme)

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 92)

                    authHeader(theme: theme)

                    authModePicker(theme: theme)

                    VStack(spacing: 14) {
                        if mode == .signUp {
                            authField(
                                title: AppLocalizer.string("auth.name"),
                                systemImage: "person.fill",
                                text: $name,
                                keyboardType: .default,
                                textContentType: .name,
                                theme: theme
                            )
                        }

                        authField(
                            title: AppLocalizer.string("auth.email"),
                            systemImage: "envelope.fill",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            theme: theme
                        )

                        passwordField(theme: theme)

                        if mode == .signIn {
                            Button(AppLocalizer.string("auth.action.reset_password")) {
                                resetPassword()
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .disabled(sessionStore.isLoading)
                        }
                    }

                    if let authErrorMessage = sessionStore.authErrorMessage, authErrorMessage.isEmpty == false {
                        statusLabel(authErrorMessage, color: HomeDarkColors.red)
                    }

                    if let statusMessage, statusMessage.isEmpty == false {
                        statusLabel(statusMessage, color: theme.secondaryText)
                    }

                    submitButton(theme: theme)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(authBackground(theme: theme).ignoresSafeArea())
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

    private func authHeader(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accent, theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .shadow(color: theme.accent.opacity(0.32), radius: 20, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.string("auth.title"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(theme.primaryText)

                Text(AppLocalizer.string("auth.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func authModePicker(theme: AppTheme) -> some View {
        HStack(spacing: 4) {
            authModeButton(
                AppLocalizer.string("auth.mode.sign_in"),
                mode: .signIn,
                theme: theme
            )

            authModeButton(
                AppLocalizer.string("auth.mode.sign_up"),
                mode: .signUp,
                theme: theme
            )
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.subtleFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        }
    }

    private func authModeButton(_ title: String, mode buttonMode: AuthMode, theme: AppTheme) -> some View {
        Button {
            mode = buttonMode
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mode == buttonMode ? Color.white : theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    if mode == buttonMode {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [theme.accent, theme.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: theme.accent.opacity(0.24), radius: 12, x: 0, y: 6)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func passwordField(theme: AppTheme) -> some View {
        authFieldContainer(systemImage: "lock.fill", theme: theme) {
            SecureField(AppLocalizer.string("auth.password"), text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .foregroundStyle(theme.primaryText)
        }
    }

    private func submitButton(theme: AppTheme) -> some View {
        Button(action: submit) {
            HStack {
                if sessionStore.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(mode == .signIn ? AppLocalizer.string("auth.action.sign_in") : AppLocalizer.string("auth.action.sign_up"))
                        .fontWeight(.semibold)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accent, theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: theme.accent.opacity(0.30), radius: 18, x: 0, y: 9)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitDisabled || sessionStore.isLoading)
        .opacity(isSubmitDisabled || sessionStore.isLoading ? 0.48 : 1)
    }

    private func statusLabel(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func authField(
        title: String,
        systemImage: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType,
        autocapitalization: TextInputAutocapitalization = .words,
        theme: AppTheme
    ) -> some View {
        authFieldContainer(systemImage: systemImage, theme: theme) {
            TextField(title, text: text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .foregroundStyle(theme.primaryText)
        }
    }

    private func authFieldContainer<Content: View>(
        systemImage: String,
        theme: AppTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 22)

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func authBackground(theme: AppTheme) -> some View {
        if theme.isDark {
            HomeDarkBackground()
        } else {
            theme.bg
        }
    }
}

private enum AuthMode {
    case signIn
    case signUp
}
