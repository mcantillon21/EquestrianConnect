import SwiftUI

// MARK: - Primary Button

struct EQPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EQSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 52)
            .padding(.horizontal, isFullWidth ? 0 : EQSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .fill(Color.eqInk)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button

struct EQSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: EQSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color.eqSaddleBrown)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 52)
            .padding(.horizontal, isFullWidth ? 0 : EQSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .strokeBorder(Color.eqSaddleBrown, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                            .fill(Color.eqCream)
                    )
            )
        }
    }
}

// MARK: - Icon Button

struct EQIconButton: View {
    let icon: String
    var color: Color = .eqSaddleBrown
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color.eqMutedBrown, in: Circle())
        }
    }
}

// MARK: - Button Styles

/// Drop-in replacement for .plain — adds spring scale + light haptic on press.
struct EQPressStyle: ButtonStyle {
    var feedback: UIImpactFeedbackGenerator.FeedbackStyle = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    Task { @MainActor in HapticFeedback.impact(feedback) }
                }
            }
    }
}

extension ButtonStyle where Self == EQPressStyle {
    static var eqPress: EQPressStyle { EQPressStyle() }
    static func eqPress(_ feedback: UIImpactFeedbackGenerator.FeedbackStyle) -> EQPressStyle {
        EQPressStyle(feedback: feedback)
    }
}

// Legacy alias kept for existing call sites
struct EQScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EQScaleButtonStyle {
    static var eqScale: EQScaleButtonStyle { EQScaleButtonStyle() }
}
