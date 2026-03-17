import SwiftUI

// Accessible from the More tab (debug builds only).
// Shows every user who has signed up via Base44.
struct AdminUsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var error: String?

    private let client = Base44Client.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if isLoading {
                    EQLoadingView()
                } else if let err = error {
                    VStack(spacing: EQSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.eqLeather)
                        Text(err)
                            .font(.eqFont(14, weight: .regular))
                            .foregroundStyle(Color.eqMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, EQSpacing.lg)
                        Button("Retry") { Task { await load() } }
                            .font(.eqFont(15, weight: .semibold))
                            .foregroundStyle(Color.eqSaddleBrown)
                    }
                } else if users.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Users Found",
                        subtitle: "No registered users were returned by the server."
                    )
                } else {
                    List {
                        Section {
                            ForEach(users) { user in
                                UserRow(user: user)
                                    .listRowBackground(Color.eqWarmWhite)
                                    .listRowSeparatorTint(Color.eqLightTan)
                            }
                        } header: {
                            Text("\(users.count) registered user\(users.count == 1 ? "" : "s")")
                                .font(.eqFont(12, weight: .regular))
                                .foregroundStyle(Color.eqMuted)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("All Users")
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        do {
            users = try await client.list(entity: "User", sort: "-created_date", limit: 200)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Row

private struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: EQSpacing.md) {
            InitialsAvatar(text: user.displayName, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.full_name ?? "(no name)")
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqDarkBrown)
                Text(user.email)
                    .font(.eqFont(13, weight: .regular))
                    .foregroundStyle(Color.eqMuted)
            }

            Spacer()

            rolePill
        }
        .padding(.vertical, EQSpacing.sm)
    }

    @ViewBuilder
    private var rolePill: some View {
        if let role = user.user_type, !role.isEmpty {
            Text(role.capitalized)
                .font(.eqFont(11, weight: .semibold))
                .foregroundStyle(role == "trainer" ? Color.eqSaddleBrown : Color.eqLeather)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (role == "trainer" ? Color.eqSaddleBrown : Color.eqLeather).opacity(0.12),
                    in: Capsule()
                )
        } else {
            Text("No role")
                .font(.eqFont(11, weight: .regular))
                .foregroundStyle(Color.eqMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.eqLightTan.opacity(0.5), in: Capsule())
        }
    }
}
