import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: EQSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.eqMutedBrown)
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.eqSaddleBrown)
            }

            VStack(spacing: EQSpacing.sm) {
                Text(title)
                    .font(.eqSerif(.title3, weight: .bold))
                    .foregroundStyle(Color.eqDarkBrown)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color.eqMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EQSpacing.xl)
            }

            if let actionTitle, let action {
                EQPrimaryButton(title: actionTitle, isFullWidth: false, action: action)
                    .padding(.top, EQSpacing.sm)
            }

            Spacer()
        }
    }
}

// MARK: - Loading View

struct EQLoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.eqSaddleBrown)
                .scaleEffect(1.3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    var dismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: EQSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(EQSpacing.md)
        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: EQRadius.sm))
        .padding(.horizontal)
    }
}
