import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Background
            Color.eqDarkBrown.ignoresSafeArea()
            LinearGradient(
                colors: [Color.eqDarkBrown, Color.eqSaddleBrown.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    VStack(spacing: EQSpacing.md) {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.eqSandyBrown)
                            .padding(.top, EQSpacing.xxl)

                        Text("Equestrian\nConnect")
                            .font(.eqDisplayTitle)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Sign in with your email")
                            .font(.subheadline)
                            .foregroundStyle(Color.eqSandyBrown.opacity(0.9))
                            .accessibilityHint("You'll receive a 6-digit code to enter on the next screen")
                    }
                    .padding(.bottom, EQSpacing.xxl)

                    // Form Card
                    VStack(spacing: EQSpacing.md) {
                        if let err = errorMessage {
                            ErrorBanner(message: err) { errorMessage = nil }
                        }

                        EQTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            icon: "envelope",
                            keyboard: .emailAddress
                        )
                        .textInputAutocapitalization(.never)

                        Text("We'll email you a 6-digit code to sign in — no password needed.")
                            .font(.eqFont(13, weight: .regular))
                            .foregroundStyle(Color.eqMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        EQPrimaryButton(
                            title: "Email Me a Code",
                            isLoading: isLoading
                        ) {
                            submit()
                        }
                        .padding(.top, EQSpacing.sm)
                    }
                    .padding(EQSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.xl, style: .continuous)
                            .fill(Color.eqWarmWhite)
                            .eqShadow(radius: 20, y: -8, opacity: 0.15)
                    )
                    .padding(.horizontal, EQSpacing.md)

                    // Demo mode
                    VStack(spacing: EQSpacing.sm) {
                        HStack {
                            Rectangle().fill(Color.eqSandyBrown.opacity(0.3)).frame(height: 0.5)
                            Text("or explore the app")
                                .font(.eqFont(12, weight: .regular))
                                .foregroundStyle(Color.eqSandyBrown.opacity(0.6))
                                .fixedSize()
                            Rectangle().fill(Color.eqSandyBrown.opacity(0.3)).frame(height: 0.5)
                        }
                        .padding(.horizontal, EQSpacing.md)

                        HStack(spacing: EQSpacing.sm) {
                            demoButton(title: "Owner Demo", role: "owner")
                            demoButton(title: "Trainer Demo", role: "trainer")
                        }
                        .padding(.horizontal, EQSpacing.md)
                    }
                    .padding(.top, EQSpacing.sm)
                }
            }
        }
    }

    private func demoButton(title: String, role: String) -> some View {
        Button { auth.previewAs(role) } label: {
            Text(title)
                .font(.eqFont(14, weight: .semibold))
                .foregroundStyle(Color.eqSandyBrown)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                        .strokeBorder(Color.eqSandyBrown.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private func submit() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email."
            return
        }
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await auth.sendMagicLink(email: email)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
