import SwiftUI
import Observation

@Observable
final class AuthManager {
    var user: User?
    var isLoading: Bool = true
    var error: String?

    // Set after register or when login is blocked by "verify your email".
    // Non-nil means the OTP screen should be shown.
    var pendingVerificationEmail: String?

    var isAuthenticated: Bool { user != nil }
    var needsRoleSelection: Bool { isAuthenticated && !(user?.hasRole ?? false) }
    var needsOTPVerification: Bool { pendingVerificationEmail != nil }

    private let client = Base44Client.shared

    init() {
        #if targetEnvironment(simulator)
        // Add "-USE_REAL_AUTH" to the scheme's launch arguments to skip the
        // preview user and test real login / real data in the simulator.
        let useRealAuth = ProcessInfo.processInfo.arguments.contains("-USE_REAL_AUTH")
        if !useRealAuth {
            user = User(id: "preview-owner", email: "preview@eq.app", full_name: "Jordan Owner", user_type: "owner")
            isLoading = false
            return
        }
        #endif
        Task { await checkAuth() }
    }

    // MARK: Boot

    func checkAuth() async {
        await MainActor.run { isLoading = true }
        guard client.token != nil else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let me = try await client.me()
            await MainActor.run { user = me; isLoading = false }
        } catch {
            client.token = nil
            await MainActor.run { user = nil; isLoading = false }
        }
    }

    // MARK: Login

    func login(email: String, password: String) async throws {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let response = try await client.login(email: email, password: password)
            await finishAuth(response: response)
        } catch Base44Error.httpError(_, let msg) where isVerificationRequired(msg) {
            // Account exists but email not yet verified — go to OTP screen
            await MainActor.run {
                pendingVerificationEmail = email
                isLoading = false
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            throw error
        }
    }

    // MARK: Register

    func register(email: String, password: String, fullName: String) async throws {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let response = try await client.register(email: email, password: password, fullName: fullName)
            if response.access_token != nil {
                // Rare case: server skipped OTP (e.g. already verified)
                await finishAuth(response: response)
            } else {
                // Normal case: OTP sent to email
                await MainActor.run {
                    pendingVerificationEmail = email
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            throw error
        }
    }

    // MARK: OTP Verification

    func verifyOTP(email: String, code: String) async throws {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let response = try await client.verifyOTP(email: email, otpCode: code)
            await MainActor.run { pendingVerificationEmail = nil }
            await finishAuth(response: response)
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            throw error
        }
    }

    func resendOTP(email: String) async throws {
        try await client.resendOTP(email: email)
    }

    // MARK: Role Selection

    @MainActor
    func selectRole(_ role: String) async throws {
        guard var updated = user else { return }
        updated.user_type = role
        user = try await client.updateMe(updated)
    }

    // MARK: Update Profile

    @MainActor
    func updateProfile(fullName: String) async throws {
        guard var updated = user else { return }
        updated.full_name = fullName
        user = try await client.updateMe(updated)
    }

    // MARK: Dev Preview Bypass

    @MainActor
    func previewAs(_ role: String) {
        isDemoMode = true
        user = User(
            id: "preview-\(role)",
            email: "preview@equestrianconnect.app",
            full_name: role == "trainer" ? "Alex Trainer" : "Jordan Owner",
            user_type: role
        )
    }

    // MARK: Logout

    @MainActor
    func logout() {
        isDemoMode = false
        client.token = nil
        user = nil
        pendingVerificationEmail = nil
    }

    // MARK: Private helpers

    private func finishAuth(response: LoginResponse) async {
        if let token = response.access_token { client.token = token }
        do {
            let me: User
            if let u = response.user {
                me = u
            } else {
                me = try await client.me()
            }
            await MainActor.run { user = me; isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
        }
    }

    private func isVerificationRequired(_ message: String?) -> Bool {
        guard let msg = message?.lowercased() else { return false }
        return msg.contains("verify") || msg.contains("verification") || msg.contains("confirm")
    }
}
