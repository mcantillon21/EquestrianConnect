import SwiftUI
import Observation

@Observable
final class AuthManager {
    var user: User?
    var isLoading: Bool = true
    var error: String?

    // Non-nil means the OTP screen should be shown.
    var pendingVerificationEmail: String?

    var isAuthenticated: Bool { user != nil }
    var needsRoleSelection: Bool { isAuthenticated && !(user?.hasRole ?? false) }
    var needsOTPVerification: Bool { pendingVerificationEmail != nil }

    private let client = SupabaseClient.shared

    init() {
        #if targetEnvironment(simulator)
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
        guard client.accessToken != nil else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            // Try refreshing the session first
            if client.refreshToken != nil {
                _ = try? await client.refreshSession()
            }
            let profile = try await client.getProfile()
            await MainActor.run { user = profile; isLoading = false }
        } catch {
            client.signOut()
            await MainActor.run { user = nil; isLoading = false }
        }
    }

    // MARK: Magic Link Login

    func sendMagicLink(email: String) async throws {
        await MainActor.run { isLoading = true; error = nil }
        do {
            try await client.signInWithOtp(email: email)
            await MainActor.run {
                pendingVerificationEmail = email
                isLoading = false
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
            let response = try await client.verifyOtp(email: email, token: code)
            if let at = response.access_token { client.accessToken = at }
            if let rt = response.refresh_token { client.refreshToken = rt }
            await MainActor.run { pendingVerificationEmail = nil }

            // Fetch the profile
            let profile = try await client.getProfile()
            await MainActor.run { user = profile; isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            throw error
        }
    }

    func resendOTP(email: String) async throws {
        try await client.signInWithOtp(email: email)
    }

    // MARK: Role Selection

    @MainActor
    func selectRole(_ role: String) async throws {
        guard var updated = user else { return }
        updated.user_type = role
        user = try await client.updateProfile(updated)
    }

    // MARK: Update Profile

    @MainActor
    func updateProfile(fullName: String) async throws {
        guard var updated = user else { return }
        updated.full_name = fullName
        user = try await client.updateProfile(updated)
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
        client.signOut()
        user = nil
        pendingVerificationEmail = nil
    }
}
