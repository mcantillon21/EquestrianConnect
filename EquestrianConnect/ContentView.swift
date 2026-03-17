import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            #if targetEnvironment(simulator)
            if !SimulatorTestHarness.currentScreen.isEmpty {
                SimulatorTestHarness()
            } else if auth.isLoading {
                SplashView()
            } else if let email = auth.pendingVerificationEmail {
                OTPVerificationView(email: email)
            } else if !auth.isAuthenticated {
                LoginView()
            } else if auth.needsRoleSelection {
                RoleSelectView()
            } else {
                MainTabView()
            }
            #else
            if auth.isLoading {
                SplashView()
            } else if let email = auth.pendingVerificationEmail {
                OTPVerificationView(email: email)
            } else if !auth.isAuthenticated {
                LoginView()
            } else if auth.needsRoleSelection {
                RoleSelectView()
            } else {
                MainTabView()
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
    }
}

// MARK: - Splash

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient.eqBrown.ignoresSafeArea()
            VStack(spacing: EQSpacing.lg) {
                Image(systemName: "figure.equestrian.sports")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.eqSandyBrown)
                Text("Equestrian Connect")
                    .font(.eqDisplayTitle)
                    .foregroundStyle(.white)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.eqSandyBrown)
                    .scaleEffect(1.2)
                    .padding(.top, EQSpacing.md)
            }
        }
    }
}
