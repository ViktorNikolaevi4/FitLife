import SwiftUI

struct AccountLoadingView: View {
    let hasConnectedUser: Bool
    let isPreparingLocalData: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.bg.ignoresSafeArea()

            LaunchWaveShape(heightFactor: 0.42)
                .fill(theme.accent.opacity(theme.isDark ? 0.10 : 0.07))
                .frame(height: 150)
                .ignoresSafeArea(edges: .bottom)

            LaunchWaveShape(heightFactor: 0.64)
                .fill(theme.accent.opacity(theme.isDark ? 0.16 : 0.11))
                .frame(height: 112)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                launchLogo

                VStack(spacing: 7) {
                    Text(AppLocalizer.string("app.loading.title"))
                        .font(.title3.bold())
                        .foregroundStyle(theme.primaryText)

                    Text(AppLocalizer.string("app.loading.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.top, 34)

                VStack(spacing: 18) {
                    statusRow(
                        AppLocalizer.string("app.loading.profile"),
                        state: profileState
                    )
                    statusRow(
                        AppLocalizer.string("app.loading.sync"),
                        state: syncState
                    )
                    statusRow(
                        AppLocalizer.string("app.loading.recommendations"),
                        state: recommendationsState
                    )
                }
                .frame(maxWidth: 300)
                .padding(.top, 34)

                Spacer(minLength: 150)
            }
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
    }

    private var launchLogo: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(systemName: "leaf.fill")
                    .rotationEffect(.degrees(-28))
                    .offset(x: -8, y: 5)
                Image(systemName: "leaf.fill")
                    .scaleEffect(x: -1, y: 1)
                    .rotationEffect(.degrees(28))
                    .offset(x: 8, y: -5)
            }
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [theme.accent, theme.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 64, height: 54)
            .accessibilityHidden(true)

            Text("FitLife")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(theme.primaryText)
        }
    }

    private func statusRow(_ title: String, state: LaunchLoadingState) -> some View {
        HStack(spacing: 13) {
            statusIndicator(state)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.subheadline.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(state == .pending ? theme.tertiaryText : theme.primaryText)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    @ViewBuilder
    private func statusIndicator(_ state: LaunchLoadingState) -> some View {
        switch state {
        case .complete:
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(theme.accent, in: Circle())
        case .active:
            ProgressView()
                .controlSize(.small)
                .tint(theme.accent)
        case .pending:
            Circle()
                .stroke(theme.tertiaryText.opacity(0.65), lineWidth: 1.5)
                .frame(width: 20, height: 20)
        }
    }

    private var profileState: LaunchLoadingState {
        hasConnectedUser || isPreparingLocalData ? .complete : .active
    }

    private var syncState: LaunchLoadingState {
        if isPreparingLocalData { return .complete }
        return hasConnectedUser ? .active : .pending
    }

    private var recommendationsState: LaunchLoadingState {
        isPreparingLocalData ? .active : .pending
    }
}

private enum LaunchLoadingState: Equatable {
    case complete
    case active
    case pending
}

private struct LaunchWaveShape: Shape {
    let heightFactor: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.height * heightFactor

        path.move(to: CGPoint(x: 0, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.30),
            control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.10),
            control2: CGPoint(x: rect.width * 0.60, y: rect.height * 0.82)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview("Загрузка профиля") {
    AccountLoadingView(hasConnectedUser: true, isPreparingLocalData: false)
}

#Preview("Локальные данные") {
    AccountLoadingView(hasConnectedUser: true, isPreparingLocalData: true)
        .preferredColorScheme(.dark)
}
