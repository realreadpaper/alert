import SwiftUI

enum GuardColor {
    static let ink900 = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let ink700 = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let ink500 = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let surface0 = Color.white
    static let surface50 = Color(red: 251 / 255, green: 252 / 255, blue: 253 / 255)
    static let surface100 = Color(red: 244 / 255, green: 246 / 255, blue: 248 / 255)
    static let line100 = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let line200 = Color(red: 214 / 255, green: 220 / 255, blue: 229 / 255)
    static let safe = Color(red: 15 / 255, green: 118 / 255, blue: 110 / 255)
    static let warning = Color(red: 180 / 255, green: 83 / 255, blue: 9 / 255)
    static let danger = Color(red: 153 / 255, green: 27 / 255, blue: 27 / 255)
}

enum GuardSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

struct GuardPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(GuardColor.ink900)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GuardSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(GuardColor.ink900)
                .background(GuardColor.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GuardColor.line200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GuardStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
    }
}

struct GuardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: GuardSpacing.md) {
            content
        }
        .padding(GuardSpacing.lg)
        .background(GuardColor.surface0)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GuardColor.line100, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
