import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var auth
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if auth.user?.isTrainer == true {
                TrainerTabView(selectedTab: $selectedTab)
            } else {
                OwnerTabView(selectedTab: $selectedTab)
            }
        }
        .onAppear { styleTabBar() }
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.055, blue: 0.04, alpha: 0.82)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.07)

        let normal = UITabBarItemAppearance()
        normal.normal.iconColor = UIColor(Color.eqTaupe.opacity(0.5))
        normal.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.eqTaupe.opacity(0.5)),
            .font: UIFont(name: "AvenirNext-Medium", size: 10) ?? .systemFont(ofSize: 10, weight: .medium)
        ]
        normal.selected.iconColor = UIColor(Color.eqStraw)
        normal.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.eqStraw),
            .font: UIFont(name: "AvenirNext-DemiBold", size: 10) ?? .systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance = normal
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Owner Tabs

private struct OwnerTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            HorsesView()
                .tabItem { Label("Horses", systemImage: "figure.equestrian.sports") }
                .tag(1)
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(2)
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .tag(3)
            OwnerMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .tint(Color.eqSandyBrown)
        .onChange(of: selectedTab) { _, _ in HapticFeedback.selection() }
    }
}

// MARK: - Trainer Tabs

private struct TrainerTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainerHubView()
                .tabItem { Label("Hub", systemImage: "chart.bar.fill") }
                .tag(0)
            TrainerHorsesView()
                .tabItem { Label("Horses", systemImage: "figure.equestrian.sports") }
                .tag(1)
            CalendarView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .tag(3)
            TrainerMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .tint(Color.eqSandyBrown)
        .onChange(of: selectedTab) { _, _ in HapticFeedback.selection() }
    }
}

// MARK: - Shared More View

private struct EQMoreView: View {
    @Environment(AuthManager.self) private var auth
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        profileBanner
                        VStack(spacing: EQSpacing.xl) {
                            discoverSection
                            accountSection
                            Text("Equestrian Connect · v1.0")
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted.opacity(0.6))
                        }
                        .padding(.top, EQSpacing.lg)
                        .padding(.bottom, EQSpacing.xxl)
                    }
                }
            }
            .navigationTitle("More")
            .eqNavAppearance()
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { auth.logout() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: Profile Banner

    private var profileBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Rich layered gradient
            Color(red: 0.07, green: 0.055, blue: 0.04)
            RadialGradient(
                colors: [Color.eqBark.opacity(0.65), .clear],
                center: .init(x: 0.05, y: 1.3),
                startRadius: 0,
                endRadius: 260
            )
            LinearGradient(
                colors: [Color.black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.5)
            )

            HStack(spacing: EQSpacing.md) {
                InitialsAvatar(
                    text: auth.user?.displayName ?? "?",
                    size: 60,
                    background: Color.eqLeather.opacity(0.5),
                    foreground: .white
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(auth.user?.full_name ?? "Rider")
                        .font(.eqFont(20, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-0.3)
                    Text(auth.user?.email ?? "")
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Spacer()
            }
            .padding(.horizontal, EQSpacing.lg)
            .padding(.bottom, EQSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipped()
    }

    // MARK: Discover Section

    private var discoverSection: some View {
        VStack(spacing: 0) {
            NavigationLink { MarketplaceView() } label: {
                MoreSimpleRow(icon: "tag", title: "Marketplace")
            }.buttonStyle(.eqPress)
            EQDivider().padding(.leading, EQSpacing.md)
            NavigationLink { FeedView() } label: {
                MoreSimpleRow(icon: "person.2", title: "Community Feed")
            }.buttonStyle(.eqPress)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous).strokeBorder(Color.eqTaupe.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, EQSpacing.md)
    }

    // MARK: Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            NavigationLink { ProfileView() } label: {
                MoreSimpleRow(icon: "person", title: "My Profile")
            }.buttonStyle(.eqPress)

            EQDivider().padding(.leading, EQSpacing.md)

            Button { showLogoutAlert = true } label: {
                MoreSimpleRow(icon: "arrow.right.square", title: "Sign Out", destructive: true)
            }.buttonStyle(.eqPress(.medium))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous).strokeBorder(Color.eqTaupe.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, EQSpacing.md)
    }
}

// MARK: - Owner More

private struct OwnerMoreView: View {
    var body: some View { EQMoreView() }
}

// MARK: - Trainer More

private struct TrainerMoreView: View {
    var body: some View { EQMoreView() }
}

// MARK: - More Simple Row

private struct MoreSimpleRow: View {
    let icon: String
    let title: String
    var destructive: Bool = false

    var body: some View {
        HStack(spacing: EQSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(destructive ? Color.red : Color.eqLeather)
                .frame(width: 24)
            Text(title)
                .font(.eqFont(15, weight: .regular))
                .foregroundStyle(destructive ? Color.red : Color.eqInk)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.eqTaupe)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
