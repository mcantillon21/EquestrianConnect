import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @State private var isEditing = false
    @State private var fullName = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var showLogoutAlert = false
    @State private var showRoleChange = false
    @State private var codeCopied = false
    @State private var isGeneratingCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EQSpacing.md) {
                        profileHeader
                        accountSection
                        if auth.user?.isTrainer == true {
                            trainerCodeSection
                        }
                        if auth.user?.isOwner == true {
                            trainerConnectionSection
                        }
                        roleSection
                        appSection
                        dangerSection
                    }
                    .padding(.top, EQSpacing.md)
                    .padding(.bottom, EQSpacing.xxl)
                }
            }
            .navigationTitle("Profile")
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing { saveChanges() }
                        else { beginEdit() }
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { auth.logout() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: Sections

    private var profileHeader: some View {
        VStack(spacing: EQSpacing.md) {
            InitialsAvatar(
                text: auth.user?.displayName ?? "?",
                size: 90,
                background: Color.eqSaddleBrown
            )
            .eqShadow(radius: 12)

            if let name = auth.user?.full_name, !name.isEmpty {
                Text(name)
                    .font(.eqSerif(.title3, weight: .bold))
                    .foregroundStyle(Color.eqDarkBrown)
            }
            Text(auth.user?.email ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)

            if let role = auth.user?.user_type {
                EQBadge(
                    text: role == "owner" ? "Horse Owner" : "Trainer",
                    color: Color.eqSaddleBrown
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EQSpacing.lg)
        .padding(.horizontal, EQSpacing.md)
    }

    private var accountSection: some View {
        ProfileSection(title: "Account") {
            if isEditing {
                EQTextField(label: "Full Name", placeholder: "Your name", text: $fullName)
                    .padding(.horizontal, EQSpacing.md)
            } else {
                ProfileRow(label: "Name", value: auth.user?.full_name ?? "Not set")
                ProfileRow(label: "Email", value: auth.user?.email ?? "")
            }
        }
    }

    private var roleSection: some View {
        ProfileSection(title: "Role") {
            ProfileRow(
                label: "Account Type",
                value: auth.user?.user_type == "owner" ? "Horse Owner" : "Trainer"
            )
            Button {
                showRoleChange = true
            } label: {
                HStack {
                    Text("Change Role")
                        .font(.subheadline)
                        .foregroundStyle(Color.eqSaddleBrown)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.eqLightTan)
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $showRoleChange) {
            RoleSelectView()
        }
    }

    private var trainerCodeSection: some View {
        ProfileSection(title: "Your Trainer Code") {
            VStack(spacing: EQSpacing.md) {
                Text("Share this code with owners so they can connect to your account")
                    .font(.caption)
                    .foregroundStyle(Color.eqMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EQSpacing.md)
                    .padding(.top, EQSpacing.sm)

                if let code = auth.user?.trainer_code, !code.isEmpty {
                    HStack(spacing: EQSpacing.sm) {
                        Text(code)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.eqDarkBrown)
                            .tracking(5)

                        Button {
                            UIPasteboard.general.string = code
                            codeCopied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                await MainActor.run { codeCopied = false }
                            }
                        } label: {
                            Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.title3)
                                .foregroundStyle(codeCopied ? Color.green : Color.eqSaddleBrown)
                        }
                    }
                    .padding(.vertical, EQSpacing.md)
                } else {
                    Button {
                        isGeneratingCode = true
                        Task {
                            do {
                                try await auth.generateCodeIfNeeded()
                            } catch {
                                await MainActor.run { self.error = error.localizedDescription }
                            }
                            await MainActor.run { isGeneratingCode = false }
                        }
                    } label: {
                        if isGeneratingCode {
                            ProgressView()
                                .tint(Color.eqSaddleBrown)
                        } else {
                            Text("Generate Code")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.eqSaddleBrown)
                        }
                    }
                    .disabled(isGeneratingCode)
                    .padding(.vertical, EQSpacing.md)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var trainerConnectionSection: some View {
        ProfileSection(title: "My Trainer") {
            if auth.user?.trainer_id != nil {
                ProfileRow(label: "Connected", value: "Trainer linked")
            } else {
                HStack {
                    Text("Not connected")
                        .font(.subheadline)
                        .foregroundStyle(Color.eqMuted)
                    Spacer()
                    NavigationLink {
                        TrainerCodeEntryView()
                    } label: {
                        Text("Add Trainer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.eqSaddleBrown)
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 12)
            }
        }
    }

    private var appSection: some View {
        ProfileSection(title: "App") {
            ProfileRow(label: "Version", value: "1.0.0")
        }
    }

    private var dangerSection: some View {
        VStack(spacing: EQSpacing.sm) {
            if let err = error {
                ErrorBanner(message: err) { error = nil }
                    .padding(.horizontal, EQSpacing.md)
            }
            Button(role: .destructive) {
                showLogoutAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.right.square")
                    Text("Sign Out")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: EQRadius.md))
                .padding(.horizontal, EQSpacing.md)
            }
        }
    }

    // MARK: Helpers

    private func beginEdit() {
        fullName = auth.user?.full_name ?? ""
        withAnimation { isEditing = true }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                try await auth.updateProfile(fullName: fullName)
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
            withAnimation { isEditing = false }
        }
    }
}

// MARK: - Profile Section

private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eqMuted)
                .padding(.horizontal, EQSpacing.md)
                .padding(.leading, EQSpacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.eqWarmWhite)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .strokeBorder(Color.eqLightTan, lineWidth: 1)
            )
            .padding(.horizontal, EQSpacing.md)
        }
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.eqMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.eqDarkBrown)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            EQDivider().padding(.leading, EQSpacing.md)
        }
    }
}
