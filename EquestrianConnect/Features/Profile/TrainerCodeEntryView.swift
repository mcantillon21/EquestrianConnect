import SwiftUI

struct TrainerCodeEntryView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: EQSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(Color.eqMutedBrown)
                                .frame(width: 80, height: 80)
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.eqSaddleBrown)
                        }

                        VStack(spacing: EQSpacing.xs) {
                            Text("Enter Trainer Code")
                                .font(.eqSerif(.title2, weight: .bold))
                                .foregroundStyle(Color.eqDarkBrown)
                            Text("Ask your trainer for their 6-character code")
                                .font(.subheadline)
                                .foregroundStyle(Color.eqMuted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, EQSpacing.xl)

                    VStack(spacing: EQSpacing.md) {
                        TextField("e.g. AB12CD", text: $code)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: code) { _, new in
                                code = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                            }
                            .padding(.vertical, EQSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                                            .strokeBorder(
                                                code.count == 6 ? Color.eqSaddleBrown : Color.eqLightTan,
                                                lineWidth: code.count == 6 ? 2 : 1
                                            )
                                    )
                                    .eqShadow(radius: 6, y: 2, opacity: 0.06)
                            )
                            .padding(.horizontal, EQSpacing.md)

                        if let error {
                            ErrorBanner(message: error) { self.error = nil }
                                .padding(.horizontal, EQSpacing.md)
                        }

                        if success {
                            HStack(spacing: EQSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Trainer connected!")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }

                        EQPrimaryButton(title: "Connect", isLoading: isLoading) {
                            connect()
                        }
                        .disabled(code.count < 6)
                        .opacity(code.count < 6 ? 0.5 : 1)
                        .padding(.horizontal, EQSpacing.md)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Connect Trainer")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func connect() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.linkToTrainer(code: code)
                await MainActor.run {
                    success = true
                    isLoading = false
                }
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run { dismiss() }
            } catch SupabaseError.notFound {
                await MainActor.run {
                    error = "Trainer code not found. Double-check with your trainer."
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
