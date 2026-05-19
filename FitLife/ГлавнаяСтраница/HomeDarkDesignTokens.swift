import SwiftUI

enum HomeDarkColors {
    static let backgroundTop = Color(hex: "151A20")
    static let backgroundBottom = Color(hex: "05070A")

    static let cardTop = Color.white.opacity(0.085)
    static let cardBottom = Color.white.opacity(0.035)
    static let cardPressed = Color.white.opacity(0.12)

    static let strokeTop = Color.white.opacity(0.16)
    static let strokeBottom = Color.white.opacity(0.055)
    static let divider = Color.white.opacity(0.08)

    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)

    static let blue = Color(hex: "0A84FF")
    static let blueDeep = Color(hex: "1F6BFF")
    static let green = Color(hex: "30D158")
    static let red = Color(hex: "FF453A")
    static let orange = Color(hex: "FF9F0A")

    static let protein = blue
    static let fat = red
    static let carbs = green
    static let water = blue
}

enum HomeDarkMetrics {
    static let horizontalPadding: CGFloat = 20
    static let verticalSpacing: CGFloat = 18
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 24
    static let largeCardCornerRadius: CGFloat = 28
    static let iconTileSize: CGFloat = 56
    static let iconTileCornerRadius: CGFloat = 16
    static let roundButtonSize: CGFloat = 44
    static let floatingButtonSize: CGFloat = 58
    static let floatingButtonBottomPadding: CGFloat = 74
    static let strokeWidth: CGFloat = 1
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowY: CGFloat = 14
    static let floatingShadowRadius: CGFloat = 22
    static let floatingShadowY: CGFloat = 10
}

struct HomeDarkBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                HomeDarkColors.backgroundTop,
                HomeDarkColors.backgroundBottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            RadialGradient(
                colors: [
                    HomeDarkColors.blue.opacity(0.16),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
        .overlay {
            RadialGradient(
                colors: [
                    HomeDarkColors.blueDeep.opacity(0.10),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }
}

struct DarkPremiumCard: ViewModifier {
    var cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                HomeDarkColors.cardTop,
                                HomeDarkColors.cardBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                HomeDarkColors.strokeTop,
                                HomeDarkColors.strokeBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: HomeDarkMetrics.strokeWidth
                    )
            }
            .shadow(
                color: .black.opacity(0.45),
                radius: HomeDarkMetrics.cardShadowRadius,
                x: 0,
                y: HomeDarkMetrics.cardShadowY
            )
            .shadow(color: .white.opacity(0.035), radius: 1, x: 0, y: 1)
    }
}

struct DarkIconTile: ViewModifier {
    var size: CGFloat = HomeDarkMetrics.iconTileSize
    var cornerRadius: CGFloat = HomeDarkMetrics.iconTileCornerRadius
    var tint: Color = HomeDarkColors.blue

    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.28),
                                tint.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: HomeDarkMetrics.strokeWidth)
            }
            .shadow(color: tint.opacity(0.18), radius: 18, x: 0, y: 8)
    }
}

struct DarkFloatingButton: ViewModifier {
    var size: CGFloat = HomeDarkMetrics.floatingButtonSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                HomeDarkColors.blue,
                                HomeDarkColors.blueDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: HomeDarkMetrics.strokeWidth)
            }
            .shadow(
                color: HomeDarkColors.blue.opacity(0.35),
                radius: HomeDarkMetrics.floatingShadowRadius,
                x: 0,
                y: HomeDarkMetrics.floatingShadowY
            )
            .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func darkPremiumCard(cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius) -> some View {
        modifier(DarkPremiumCard(cornerRadius: cornerRadius))
    }

    func darkIconTile(
        size: CGFloat = HomeDarkMetrics.iconTileSize,
        cornerRadius: CGFloat = HomeDarkMetrics.iconTileCornerRadius,
        tint: Color = HomeDarkColors.blue
    ) -> some View {
        modifier(
            DarkIconTile(
                size: size,
                cornerRadius: cornerRadius,
                tint: tint
            )
        )
    }

    func darkFloatingButton(size: CGFloat = HomeDarkMetrics.floatingButtonSize) -> some View {
        modifier(DarkFloatingButton(size: size))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let alpha: UInt64
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch cleaned.count {
        case 3:
            alpha = 255
            red = (value >> 8) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
        case 6:
            alpha = 255
            red = value >> 16
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        case 8:
            alpha = value >> 24
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        default:
            alpha = 255
            red = 255
            green = 255
            blue = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
