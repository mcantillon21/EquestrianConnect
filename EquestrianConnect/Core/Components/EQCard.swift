import SwiftUI

struct EQCard<Content: View>: View {
    var padding: CGFloat = EQSpacing.md
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.eqInk.opacity(0.06), radius: 14, x: 0, y: 5)

            content()
                .padding(padding)
        }
    }
}

// MARK: - Section Header Row

struct EQSectionRow: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "See all"

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.eqFont(15, weight: .semibold))
                .foregroundStyle(Color.eqInk)

            Spacer()

            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.eqFont(13, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                }
            }
        }
    }
}

// MARK: - Stat Card

struct EQStatCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .eqLeather

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.eqFont(32, weight: .bold))
                .foregroundStyle(Color.eqInk)

            Text(label)
                .font(.eqFont(13, weight: .regular))
                .foregroundStyle(Color.eqMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EQSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .shadow(color: Color.eqInk.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Initials Avatar

struct InitialsAvatar: View {
    let text: String
    var size: CGFloat = 40
    var background: Color = .eqLeather
    var foreground: Color = .white

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
            Text(text.initials)
                .font(.eqFont(size * 0.32, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badge

struct EQBadge: View {
    let text: String
    var color: Color = .eqLeather

    var body: some View {
        Text(text.uppercased())
            .font(.eqFont(9, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color == Color.eqForest ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                color == Color.eqForest
                    ? AnyShapeStyle(color)
                    : AnyShapeStyle(color.opacity(0.12)),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(color == Color.eqForest ? 0 : 0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Divider

struct EQDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.eqTaupe.opacity(0.5))
            .frame(height: 0.5)
    }
}
