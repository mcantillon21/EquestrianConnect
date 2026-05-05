import SwiftUI

private enum OnboardingStep {
    case role
    case trainerCode
}

struct RoleSelectView: View {
    @Environment(AuthManager.self) private var auth
    @State private var selectedRole: String? = nil
    @State private var step: OnboardingStep = .role
    @State private var trainerCode = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            switch step {
            case .role:
                roleStep
            case .trainerCode:
                trainerCodeStep
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Step 1: Role Selection

    private var roleStep: some View {
        VStack(spacing: 0) {
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

            EQPrimaryButton(title: "Continue", isLoading: isLoading) {
                advanceFromRole()
            }
            .disabled(selectedRole == nil)
            .opacity(selectedRole == nil ? 0.5 : 1)
            .padding(.horizontal, EQSpacing.md)
            .padding(.bottom, EQSpacing.xl)
        }
    }

    // MARK: - Step 2: Trainer Code (owners only)

    private var trainerCodeStep: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation { step = .role }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundStyle(Color.eqSaddleBrown)
                }
                Spacer()
            }
            .padding(.horizontal, EQSpacing.md)
            .padding(.top, EQSpacing.lg)

            Spacer()

            VStack(spacing: EQSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.eqMutedBrown)
                        .frame(width: 80, height: 80)
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.eqSaddleBrown)
                }

                Text("Connect with\nyour trainer")
                    .font(.eqDisplayTitle)
                    .foregroundStyle(Color.eqDarkBrown)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Ask your trainer for their 6-character code\nto link your account to theirs")
                    .font(.subheadline)
                    .foregroundStyle(Color.eqMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: EQSpacing.lg) {
                // Code input
                TextField("e.g. AB12CD", text: $trainerCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: trainerCode) { _, new in
                        trainerCode = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    }
                    .padding(.vertical, EQSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                                    .strokeBorder(
                                        trainerCode.count == 6 ? Color.eqSaddleBrown : Color.eqLightTan,
                                        lineWidth: trainerCode.count == 6 ? 2 : 1
                                    )
                            )
                            .eqShadow(radius: 6, y: 2, opacity: 0.06)
                    )
                    .padding(.horizontal, EQSpacing.md)

                if let error {
                    ErrorBanner(message: error) { self.error = nil }
                }

                EQPrimaryButton(
                    title: trainerCode.count == 6 ? "Connect & Continue" : "Continue Without Code",
                    isLoading: isLoading
                ) {
                    commitWithCode()
                }
                .padding(.horizontal, EQSpacing.md)

                Button("Skip for now") {
                    commitWithCode()
                }
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)
            }

            Spacer()
                .frame(height: EQSpacing.xxl)
        }
    }

    // MARK: - Actions

    private func advanceFromRole() {
        guard let role = selectedRole else { return }
        if role == "owner" {
            withAnimation { step = .trainerCode }
        } else {
            commitRole("trainer")
        }
    }

    private func commitRole(_ role: String) {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.selectRole(role)
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func commitWithCode() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.selectRole("owner")
                if trainerCode.count == 6 {
                    try await auth.linkToTrainer(code: trainerCode)
                }
            } catch SupabaseError.notFound {
                await MainActor.run {
                    error = "Trainer code not found. Check with your trainer and try again."
                    isLoading = false
                }
                return
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
            await MainActor.run { isLoading = false }
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
