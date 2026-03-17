import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = DashboardViewModel()
    @State private var horsesVM = HorsesViewModel()
    @State private var messagesVM = MessagesViewModel()
    @State private var selectedEvent: CalendarEvent?
    @State private var selectedConv: Conversation?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView()
                        .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            HeroHeader()
                            content
                                .padding(.horizontal, EQSpacing.md)
                                .padding(.top, EQSpacing.lg)
                                .padding(.bottom, EQSpacing.xxl)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.eqSmooth, value: vm.isLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Equestrian Connect")
                        .font(.eqFont(15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    InitialsAvatar(
                        text: auth.user?.displayName ?? "?",
                        size: 32,
                        background: Color.eqLeather.opacity(0.6)
                    )
                }
            }
            .eqNavAppearance()
            .navigationDestination(for: Horse.self) { horse in
                HorseProfileView(horse: horse, vm: horsesVM)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event, vm: CalendarViewModel())
            }
            .sheet(item: $selectedConv) { conv in
                NavigationStack {
                    ChatView(conversation: conv, vm: messagesVM)
                }
            }
            .task {
                guard let user = auth.user else { return }
                if user.isTrainer {
                    await vm.loadTrainer(trainerEmail: user.email)
                } else {
                    await vm.load(userEmail: user.email)
                }
            }
            .refreshable {
                guard let user = auth.user else { return }
                if user.isTrainer {
                    await vm.loadTrainer(trainerEmail: user.email)
                } else {
                    await vm.load(userEmail: user.email)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: EQSpacing.lg) {

            // Stats Strip — one container, two columns
            statsStrip

            // Horses
            if !vm.horses.isEmpty {
                let isTrainer = auth.user?.isTrainer == true
                groupedSection(
                    title: isTrainer ? "Client Horses" : "My Horses",
                    moreCount: vm.horses.count > 3 ? vm.horses.count : nil,
                    moreDestination: AnyView(HorsesView())
                ) {
                    let horses = Array(vm.horses.prefix(3))
                    ForEach(horses) { horse in
                        NavigationLink(value: horse) {
                            DashboardHorseRow(horse: horse, showOwner: isTrainer)
                        }
                        .buttonStyle(.eqPress)
                        if horse.id != horses.last?.id {
                            EQDivider().padding(.leading, 56)
                        }
                    }
                }
            }

            // Upcoming Events
            if !vm.upcomingEvents.isEmpty {
                groupedSection(title: "Upcoming Events") {
                    let events = Array(vm.upcomingEvents.prefix(3))
                    ForEach(events) { event in
                        Button { selectedEvent = event } label: {
                            DashboardEventRow(event: event)
                        }
                        .buttonStyle(.eqPress)
                        if event.id != events.last?.id {
                            EQDivider().padding(.leading, EQSpacing.md)
                        }
                    }
                }
            }

            // Messages
            if !vm.recentConversations.isEmpty {
                groupedSection(title: "Recent Messages") {
                    ForEach(vm.recentConversations) { conv in
                        Button { selectedConv = conv } label: {
                            DashboardConvRow(conv: conv, currentEmail: auth.user?.email ?? "")
                        }
                        .buttonStyle(.eqPress)
                        if conv.id != vm.recentConversations.last?.id {
                            EQDivider().padding(.leading, 62)
                        }
                    }
                }
            }

            if vm.horses.isEmpty && vm.upcomingEvents.isEmpty {
                EmptyStateView(
                    icon: "figure.equestrian.sports",
                    title: "Welcome to Equestrian Connect",
                    subtitle: "Add your first horse to get started"
                )
                .frame(height: 300)
            }
        }
    }

    // MARK: Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(vm.horses.count)",
                label: auth.user?.isTrainer == true ? "Client Horses" : "My Horses"
            )
            Rectangle()
                .fill(Color.eqTaupe.opacity(0.5))
                .frame(width: 0.5)
                .padding(.vertical, 12)
            statItem(
                value: "\(vm.upcomingEvents.count)",
                label: "Upcoming"
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                .strokeBorder(Color.eqTaupe.opacity(0.5), lineWidth: 1)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.eqFont(34, weight: .bold))
                .foregroundStyle(Color.eqInk)
            Text(label)
                .font(.eqFont(11, weight: .regular))
                .foregroundStyle(Color.eqMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EQSpacing.md)
    }

    // MARK: Grouped Section Helper

    @ViewBuilder
    private func groupedSection<Content: View>(
        title: String,
        moreCount: Int? = nil,
        moreDestination: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: EQSpacing.xs) {
            EQSectionRow(title: title)
            VStack(spacing: 0) {
                content()
                if let count = moreCount, let dest = moreDestination {
                    EQDivider()
                    NavigationLink(destination: dest) {
                        Text("View all \(count)")
                            .font(.eqFont(13, weight: .medium))
                            .foregroundStyle(Color.eqLeather)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.eqPress)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                    .strokeBorder(Color.eqTaupe.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Hero Header

private struct HeroHeader: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Layered dark gradient — depth without flat black
            Color(red: 0.07, green: 0.055, blue: 0.04)
            RadialGradient(
                colors: [Color.eqBark.opacity(0.6), .clear],
                center: .init(x: 0.08, y: 1.4),
                startRadius: 0,
                endRadius: 240
            )
            LinearGradient(
                colors: [Color.black.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.5)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(dateString)
                    .font(.eqFont(11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .kerning(0.3)
                Text(auth.user?.full_name?.components(separatedBy: " ").first ?? "Rider")
                    .font(.eqFont(36, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.5)
            }
            .padding(.horizontal, EQSpacing.lg)
            .padding(.bottom, EQSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - Dashboard Horse Row

private struct DashboardHorseRow: View {
    let horse: Horse
    var showOwner: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let img = horse.profile_image, !img.isEmpty {
                AsyncImage(url: URL(string: img)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: horsePlaceholder
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                horsePlaceholder
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(horse.displayName)
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                if showOwner, let owner = horse.owner_email {
                    Text("Owner: \(owner)")
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                } else if let breed = horse.breed {
                    Text("\(breed) · \(horse.genderLabel)")
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                }
            }

            Spacer()

            if let breed = horse.breed, showOwner {
                Text(breed)
                    .font(.eqFont(11, weight: .regular))
                    .foregroundStyle(Color.eqMuted.opacity(0.7))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.eqTaupe)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 12)
    }

    private var horsePlaceholder: some View {
        ZStack {
            Circle().fill(Color.eqParchment)
            Text(horse.displayName.prefix(1).uppercased())
                .font(.eqFont(16, weight: .semibold))
                .foregroundStyle(Color.eqLeather)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Dashboard Event Row

private struct DashboardEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.type.eventTypeColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                Text(event.start_date.toDisplayDate(format: "MMM d · h:mm a"))
                    .font(.eqFont(12, weight: .regular))
                    .foregroundStyle(Color.eqMuted)
            }

            Spacer()

            Text(event.type.eventTypeLabel)
                .font(.eqFont(10, weight: .medium))
                .foregroundStyle(event.type.eventTypeColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(event.type.eventTypeColor.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Dashboard Conversation Row

private struct DashboardConvRow: View {
    let conv: Conversation
    let currentEmail: String

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(
                text: conv.otherParticipant(currentEmail: currentEmail),
                size: 38
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(conv.otherParticipant(currentEmail: currentEmail))
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                if let last = conv.last_message {
                    Text(last)
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let unread = conv.unread_count, unread > 0 {
                ZStack {
                    Circle().fill(Color.eqLeather)
                    Text("\(unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 18, height: 18)
            }
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 12)
    }
}
