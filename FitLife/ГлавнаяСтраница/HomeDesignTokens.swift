import SwiftUI

enum HomeColors {
    static let background = Color(red: 0.957, green: 0.961, blue: 0.973)
    static let elevatedBackground = Color(red: 0.980, green: 0.980, blue: 0.988)
    static let card = Color(red: 0.996, green: 0.996, blue: 1.000)
    static let primaryText = Color.black
    static let secondaryText = Color(red: 0.439, green: 0.451, blue: 0.482)
    static let tertiaryText = Color(red: 0.620, green: 0.631, blue: 0.659)
    static let accent = Color(red: 0.039, green: 0.518, blue: 1.000)
    static let primaryActionGradient = LinearGradient(
        colors: [
            Color(hex: "347DFF"),
            Color(hex: "1257E8")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let border = Color.black.opacity(0.06)
    static let subtleFill = Color.black.opacity(0.045)
    static let shadow = Color.black.opacity(0.08)
    static let strongShadow = Color.black.opacity(0.16)
}

enum HomeMetrics {
    static let screenHorizontalPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let compactCardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 30
    static let largeCardCornerRadius: CGFloat = 34
    static let iconButtonSize: CGFloat = 44
    static let iconButtonCornerRadius: CGFloat = 22
    static let floatingButtonSize: CGFloat = 58
    static let floatingButtonBottomPadding: CGFloat = 74
    static let hairlineWidth: CGFloat = 0.6
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowY: CGFloat = 10
    static let floatingShadowRadius: CGFloat = 18
    static let floatingShadowY: CGFloat = 8
}

struct HomePremiumLightCardModifier: ViewModifier {
    var cornerRadius: CGFloat = HomeMetrics.cardCornerRadius
    var background: Color = HomeColors.card
    var border: Color = HomeColors.border
    var shadow: Color = HomeColors.shadow
    var shadowRadius: CGFloat = HomeMetrics.cardShadowRadius
    var shadowY: CGFloat = HomeMetrics.cardShadowY

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: HomeMetrics.hairlineWidth)
            )
            .shadow(color: shadow, radius: shadowRadius, x: 0, y: shadowY)
    }
}

struct HomeRoundIconButtonModifier: ViewModifier {
    var size: CGFloat = HomeMetrics.iconButtonSize
    var foreground: Color = HomeColors.primaryText
    var background: Color = HomeColors.card
    var border: Color = HomeColors.border

    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(background))
            .overlay(Circle().strokeBorder(border, lineWidth: HomeMetrics.hairlineWidth))
            .shadow(color: HomeColors.shadow, radius: 14, x: 0, y: 6)
    }
}

struct HomeFloatingActionButtonModifier: ViewModifier {
    var size: CGFloat = HomeMetrics.floatingButtonSize
    var foreground: Color = .white
    var background: Color = HomeColors.primaryText

    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(background))
            .shadow(
                color: HomeColors.strongShadow,
                radius: HomeMetrics.floatingShadowRadius,
                x: 0,
                y: HomeMetrics.floatingShadowY
            )
    }
}

extension View {
    func homePremiumLightCard(
        cornerRadius: CGFloat = HomeMetrics.cardCornerRadius,
        background: Color = HomeColors.card
    ) -> some View {
        modifier(
            HomePremiumLightCardModifier(
                cornerRadius: cornerRadius,
                background: background
            )
        )
    }

    func homeRoundIconButton(
        size: CGFloat = HomeMetrics.iconButtonSize,
        foreground: Color = HomeColors.primaryText,
        background: Color = HomeColors.card
    ) -> some View {
        modifier(
            HomeRoundIconButtonModifier(
                size: size,
                foreground: foreground,
                background: background
            )
        )
    }

    func homeFloatingActionButton(
        size: CGFloat = HomeMetrics.floatingButtonSize,
        foreground: Color = .white,
        background: Color = HomeColors.primaryText
    ) -> some View {
        modifier(
            HomeFloatingActionButtonModifier(
                size: size,
                foreground: foreground,
                background: background
            )
        )
    }
}
