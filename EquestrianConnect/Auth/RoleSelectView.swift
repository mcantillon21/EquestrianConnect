import SwiftUI

struct RoleSelectView: View {
    @Environment(AuthManager.self) private var auth
    @State private var selectedRole: String? = nil
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: EQSpacing.sm) {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.eqSaddleBrown)
                        .padding(.top, EQSpacing.xxl)

                    Text("How do you\nuse the barn?")
                        .font(.eqDisplayTitle)
                        .foregroundStyle(Color.eqDarkBrown)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Choose your role to personalise your experience")
                        .font(.subheadline)
                        .foregroundStyle(Color.eqMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, EQSpacing.xl)

                // Role Cards
                VStack(spacing: EQSpacing.md) {
                    RoleCard(
                        icon: "person.fill",
                        title: "Horse Owner",
                        subtitle: "Manage your horses, track health, training, and finances",
                        isSelected: selectedRole == "owner"
                    ) { selectedRole = "owner" }

                    RoleCard(
                        icon: "figure.equestrian.sports",
                        title: "Trainer",
                        subtitle: "Oversee client horses, log training sessions, and coordinate with owners",
                        isSelected: selectedRole == "trainer"
                    ) { selectedRole = "trainer" }
                }
                .padding(.horizontal, EQSpacing.md)

                Spacer()

                if let error {
                    ErrorBanner(message: error) { self.error = nil }
                        .padding(.bottom, EQSpacing.sm)
                }

                EQPrimaryButton(
                    title: "Continue",
                    isLoading: isLoading
                ) {
                    confirm()
                }
                .disabled(selectedRole == nil)
                .opacity(selectedRole == nil ? 0.5 : 1)
                .padding(.horizontal, EQSpacing.md)
                .padding(.bottom, EQSpacing.xl)
            }
        }
    }

    private func confirm() {
        guard let role = selectedRole else { return }
        isLoading = true
        Task {
            do {
                try await auth.selectRole(role)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: EQSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.eqSaddleBrown : Color.eqMutedBrown)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : Color.eqSaddleBrown)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.eqSerif(.headline, weight: .bold))
                        .foregroundStyle(Color.eqDarkBrown)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.eqMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.eqSaddleBrown : Color.eqLightTan)
            }
            .padding(EQSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .fill(Color.eqWarmWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.eqSaddleBrown : Color.eqLightTan,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .eqShadow(radius: isSelected ? 10 : 4, y: isSelected ? 4 : 2, opacity: isSelected ? 0.12 : 0.05)
            )
        }
        .buttonStyle(.eqScale)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
