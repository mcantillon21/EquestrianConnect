import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var fullName = ""
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

                        Text(isRegistering ? "Create your account" : "Welcome back")
                            .font(.subheadline)
                            .foregroundStyle(Color.eqSandyBrown.opacity(0.9))
                    }
                    .padding(.bottom, EQSpacing.xxl)

                    // Form Card
                    VStack(spacing: EQSpacing.md) {
                        if let err = errorMessage {
                            ErrorBanner(message: err) { errorMessage = nil }
                        }

                        if isRegistering {
                            EQTextField(
                                label: "Full Name",
                                placeholder: "Jane Smith",
                                text: $fullName,
                                icon: "person"
                            )
                        }

                        EQTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            icon: "envelope",
                            keyboard: .emailAddress
                        )
                        .textInputAutocapitalization(.never)

                        EQTextField(
                            label: "Password",
                            placeholder: "••••••••",
                            text: $password,
                            icon: "lock",
                            isSecure: true
                        )

                        EQPrimaryButton(
                            title: isRegistering ? "Create Account" : "Sign In",
                            isLoading: isLoading
                        ) {
                            submit()
                        }
                        .padding(.top, EQSpacing.sm)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isRegistering.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isRegistering ? "Already have an account?" : "Don't have an account?")
                                    .foregroundStyle(Color.eqDarkBrown.opacity(0.7))
                                Text(isRegistering ? "Sign In" : "Create one")
                                    .foregroundStyle(Color.eqSaddleBrown)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(EQSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.xl, style: .continuous)
                            .fill(Color.eqWarmWhite)
                            .eqShadow(radius: 20, y: -8, opacity: 0.15)
                    )
                    .padding(.horizontal, EQSpacing.md)

                    // Demo mode — prominent
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
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        if isRegistering && fullName.isEmpty {
            errorMessage = "Please enter your full name."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if isRegistering {
                    try await auth.register(email: email, password: password, fullName: fullName)
                } else {
                    try await auth.login(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
