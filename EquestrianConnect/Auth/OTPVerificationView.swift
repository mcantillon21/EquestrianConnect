import SwiftUI

struct OTPVerificationView: View {
    @Environment(AuthManager.self) private var auth
    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resendCooldown = 0
    @FocusState private var fieldFocused: Bool

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
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(msg)
                                    .font(.eqFont(14, weight: .medium))
                                    .foregroundStyle(Color.eqDarkBrown)
                            }
                            .padding(EQSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: EQRadius.sm))
                        }

                        digitBoxes
                            .padding(.vertical, EQSpacing.sm)
                            .onTapGesture { fieldFocused = true }

                        EQPrimaryButton(title: "Verify Email", isLoading: isVerifying) {
                            submit()
                        }
                        .disabled(code.count < codeLength)

                        resendButton
                    }
                    .padding(EQSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: EQRadius.xl, style: .continuous)
                            .fill(Color.eqWarmWhite)
                            .eqShadow(radius: 20, y: -8, opacity: 0.15)
                    )
                    .padding(.horizontal, EQSpacing.md)

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
        .onAppear {
            fieldFocused = true
            startResendCooldown(seconds: 30)
        }
        .onChange(of: code) { _, newVal in
            // Strip non-digits and cap at 6 characters
            let digits = String(newVal.filter(\.isNumber).prefix(codeLength))
            if digits != newVal { code = digits }
            if digits.count == codeLength { submit() }
        }
    }

    // MARK: - Digit boxes

    private var digitBoxes: some View {
        ZStack {
            // Hidden text field that receives keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($fieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.011)
                .allowsHitTesting(false)

            // Visible digit display
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    DigitBox(
                        digit: digit(at: index),
                        isActive: index == code.count && fieldFocused
                    )
                }
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }

    // MARK: - Resend button

    @ViewBuilder
    private var resendButton: some View {
        if resendCooldown > 0 {
            Text("Resend code in \(resendCooldown)s")
                .font(.eqFont(14, weight: .regular))
                .foregroundStyle(Color.eqMuted)
        } else {
            Button { resend() } label: {
                HStack(spacing: 6) {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.75)
                            .tint(Color.eqSaddleBrown)
                    }
                    Text(isResending ? "Sending…" : "Resend code")
                        .font(.eqFont(14, weight: .semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                }
            }
            .disabled(isResending)
        }
    }

    // MARK: - Actions

    private func submit() {
        guard code.count == codeLength, !isVerifying else { return }
        isVerifying = true
        errorMessage = nil
        fieldFocused = false
        Task {
            do {
                try await auth.verifyOTP(email: email, code: code)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    code = ""
                    fieldFocused = true
                }
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
                await MainActor.run {
                    successMessage = "New code sent!"
                    startResendCooldown(seconds: 60)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
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

// MARK: - Single digit box

private struct DigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.eqSaddleBrown : Color.eqTaupe.opacity(0.4),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .shadow(color: Color.eqInk.opacity(isActive ? 0.08 : 0.03), radius: 6, x: 0, y: 2)

            if digit.isEmpty && isActive {
                // Blinking cursor
                Rectangle()
                    .fill(Color.eqSaddleBrown)
                    .frame(width: 2, height: 24)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: isActive)
            } else {
                Text(digit)
                    .font(.eqFont(22, weight: .bold))
                    .foregroundStyle(Color.eqDarkBrown)
            }
        }
        .frame(width: 44, height: 54)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}
