import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var auth
    @State private var selectedTab = 0
    @State private var messagesVM = MessagesViewModel()

    var body: some View {
        Group {
            if auth.user?.isTrainer == true {
                TrainerTabView(selectedTab: $selectedTab, messagesVM: messagesVM)
            } else {
                OwnerTabView(selectedTab: $selectedTab, messagesVM: messagesVM)
            }
        }
        .environment(messagesVM)
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
            .font: UIFont(name: "AvenirNext-Medium", size: 9) ?? .systemFont(ofSize: 9, weight: .medium)
        ]
        normal.selected.iconColor = UIColor(Color.eqStraw)
        normal.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.eqStraw),
            .font: UIFont(name: "AvenirNext-DemiBold", size: 9) ?? .systemFont(ofSize: 9, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance = normal
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Owner Tabs

private struct OwnerTabView: View {
    @Binding var selectedTab: Int
    let messagesVM: MessagesViewModel

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            HorsesView()
                .tabItem { Label("Horses", systemImage: "figure.equestrian.sports") }
                .tag(1)
            FeedView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }
                .tag(2)
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(3)
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .badge(messagesVM.totalUnreadCount > 0 ? messagesVM.totalUnreadCount : 0)
                .tag(4)
            MarketplaceView()
                .tabItem { Label("Marketplace", systemImage: "tag.fill") }
                .tag(5)
        }
        .tint(Color.eqSandyBrown)
        .onChange(of: selectedTab) { _, _ in HapticFeedback.selection() }
    }
}

// MARK: - Trainer Tabs

private struct TrainerTabView: View {
    @Binding var selectedTab: Int
    let messagesVM: MessagesViewModel

    var body: some View {
        TabView(selection: $selectedTab) {
            TrainerHubView()
                .tabItem { Label("Hub", systemImage: "chart.bar.fill") }
                .tag(0)
            TrainerHorsesView()
                .tabItem { Label("Horses", systemImage: "figure.equestrian.sports") }
                .tag(1)
            FeedView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }
                .tag(2)
            CalendarView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(3)
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
                .badge(messagesVM.totalUnreadCount > 0 ? messagesVM.totalUnreadCount : 0)
                .tag(4)
            MarketplaceView()
                .tabItem { Label("Marketplace", systemImage: "tag.fill") }
                .tag(5)
        }
        .tint(Color.eqSandyBrown)
        .onChange(of: selectedTab) { _, _ in HapticFeedback.selection() }
    }
}

