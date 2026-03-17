import SwiftUI

struct OTPVerificationView: View {
    @Environment(AuthManager.self) private var auth
    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0       // seconds remaining
    @State private var successMessage: String?

    private let codeLength = 6

    var body: some View {
        ZStack {
            Color.eqDarkBrown.ignoresSafeArea()
            LinearGradient(
                colors: [Color.eqDarkBrown, Color.eqSaddleBrown.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: EQSpacing.md) {
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.eqSandyBrown)
                            .padding(.top, EQSpacing.xxl)

                        Text("Check your email")
                            .font(.eqDisplayTitle)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 4) {
                            Text("We sent a 6-digit code to")
                                .font(.subheadline)
                                .foregroundStyle(Color.eqSandyBrown.opacity(0.8))
                            Text(email)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.eqSandyBrown)
                        }
                    }
                    .padding(.bottom, EQSpacing.xxl)

                    // Card
                    VStack(spacing: EQSpacing.lg) {
                        if let err = errorMessage {
                            ErrorBanner(message: err) { errorMessage = nil }
                        }
                        if let msg = successMessage {
                            HStack(spacing: EQSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(msg)
                                    .font(.eqFont(14, weight: .medium))
                                    .foregroundStyle(Color.eqDarkBrown)
                            }
                            .padding(EQSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: EQRadius.sm))
                        }

                        // Digit boxes
                        digitBoxes
                            .padding(.vertical, EQSpacing.sm)

                        EQPrimaryButton(title: "Verify Email", isLoading: isVerifying) {
                            submit()
                        }
                        .disabled(code.count < codeLength)

                        // Resend
                        resendButton
                    }
                    .padding(EQSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.xl, style: .continuous)
                            .fill(Color.eqWarmWhite)
                            .eqShadow(radius: 20, y: -8, opacity: 0.15)
                    )
                    .padding(.horizontal, EQSpacing.md)

                    // Wrong email?
                    Button {
                        auth.pendingVerificationEmail = nil
                    } label: {
                        Text("Wrong email? Go back")
                            .font(.eqFont(14, weight: .regular))
                            .foregroundStyle(Color.eqSandyBrown.opacity(0.7))
                    }
                    .padding(.top, EQSpacing.lg)
                }
            }
        }
        .onAppear { startResendCooldown(seconds: 30) }
        .onChange(of: code) { _, newVal in
            // Auto-submit when all 6 digits are entered
            if newVal.count == codeLength { submit() }
        }
    }

    // MARK: Digit Boxes

    private var digitBoxes: some View {
        ZStack {
            // Hidden real text field that drives the boxes
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .id("otpField")

            HStack(spacing: EQSpacing.sm) {
                ForEach(0..<codeLength, id: \.self) { i in
                    let char: String = i < code.count
                        ? String(code[code.index(code.startIndex, offsetBy: i)])
                        : ""
                    let isFocused = i == min(code.count, codeLength - 1)

                    ZStack {
                        RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                            .fill(Color.eqWarmWhite)
                            .stroke(
                                isFocused && code.count < codeLength
                                    ? Color.eqSaddleBrown
                                    : Color.eqTaupe.opacity(0.4),
                                lineWidth: isFocused && code.count < codeLength ? 2 : 1
                            )
                            .frame(width: 44, height: 54)

                        Text(char)
                            .font(.eqFont(22, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                    }
                }
            }
        }
        .onTapGesture {
            // Bring up keyboard when tapping the box area
            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }

    // MARK: Resend Button

    @ViewBuilder
    private var resendButton: some View {
        if resendCooldown > 0 {
            Text("Resend code in \(resendCooldown)s")
                .font(.eqFont(14, weight: .regular))
                .foregroundStyle(Color.eqMuted)
        } else {
            Button {
                resend()
            } label: {
                HStack(spacing: 4) {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    }
                    Text(isResending ? "Sending…" : "Resend code")
                        .font(.eqFont(14, weight: .semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                }
            }
            .disabled(isResending)
        }
    }

    // MARK: Actions

    private func submit() {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == codeLength, !isVerifying else { return }
        isVerifying = true
        errorMessage = nil
        Task {
            do {
                try await auth.verifyOTP(email: email, code: trimmed)
                // auth.user will be set — ContentView transitions automatically
            } catch {
                errorMessage = error.localizedDescription
                code = ""
            }
            isVerifying = false
        }
    }

    private func resend() {
        isResending = true
        errorMessage = nil
        successMessage = nil
        Task {
            do {
                try await auth.resendOTP(email: email)
                successMessage = "New code sent!"
                startResendCooldown(seconds: 60)
            } catch {
                errorMessage = error.localizedDescription
            }
            isResending = false
        }
    }

    private func startResendCooldown(seconds: Int) {
        resendCooldown = seconds
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { resendCooldown -= 1 }
            }
        }
    }
}

// MARK: - Stroke helper

private extension RoundedRectangle {
    func stroke(_ color: Color, lineWidth: CGFloat) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 0) // placeholder — see below
                .strokeBorder(color, lineWidth: lineWidth)
        )
    }
}

private extension View {
    func stroke(_ color: Color, lineWidth: CGFloat) -> some View { self }
}
