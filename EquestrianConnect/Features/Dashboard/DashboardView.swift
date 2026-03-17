import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(MessagesViewModel.self) private var messagesVM
    @State private var vm = DashboardViewModel()
    @State private var horsesVM = HorsesViewModel()
    @State private var selectedEvent: CalendarEvent?
    @State private var selectedConv: Conversation?

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm off-white base — makes white cards float
                Color(red: 0.963, green: 0.952, blue: 0.937).ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView().transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            HeroHeader()
                            dashboardContent
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

    // MARK: - Content

    @ViewBuilder
    private var dashboardContent: some View {
        VStack(spacing: EQSpacing.xl) {

            // Stats
            statsRow
                .padding(.horizontal, EQSpacing.md)
                .padding(.top, EQSpacing.md)

            // Horses — horizontal card scroll
            if !vm.horses.isEmpty {
                horsesSection
            }

            // Events — individual floating cards
            if !vm.upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: EQSpacing.sm) {
                    DashSectionHeader(title: "Upcoming Events")
                        .padding(.horizontal, EQSpacing.md)
                    ForEach(Array(vm.upcomingEvents.prefix(3))) { event in
                        Button { selectedEvent = event } label: {
                            DashEventCard(event: event)
                        }
                        .buttonStyle(.eqPress)
                        .padding(.horizontal, EQSpacing.md)
                    }
                }
            }

            // Messages — individual floating cards
            if !vm.recentConversations.isEmpty {
                VStack(alignment: .leading, spacing: EQSpacing.sm) {
                    DashSectionHeader(title: "Messages")
                        .padding(.horizontal, EQSpacing.md)
                    ForEach(vm.recentConversations) { conv in
                        Button { selectedConv = conv } label: {
                            DashConvCard(conv: conv, currentEmail: auth.user?.email ?? "")
                        }
                        .buttonStyle(.eqPress)
                        .padding(.horizontal, EQSpacing.md)
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
        .padding(.bottom, EQSpacing.xxl)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: EQSpacing.sm) {
            DashStatCard(
                icon: "figure.equestrian.sports",
                value: "\(vm.horses.count)",
                label: auth.user?.isTrainer == true ? "Client Horses" : "My Horses"
            )
            DashStatCard(
                icon: "calendar",
                value: "\(vm.upcomingEvents.count)",
                label: "Upcoming Events"
            )
        }
    }

    // MARK: - Horses Section

    private var horsesSection: some View {
        let isTrainer = auth.user?.isTrainer == true
        return VStack(alignment: .leading, spacing: EQSpacing.sm) {
            HStack(alignment: .center) {
                Text(isTrainer ? "Client Horses" : "My Horses")
                    .font(.eqFont(18, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                Spacer()
                if vm.horses.count > 4 {
                    NavigationLink(destination: HorsesView()) {
                        HStack(spacing: 3) {
                            Text("See all")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.eqFont(13, weight: .medium))
                        .foregroundStyle(Color.eqLeather)
                    }
                }
            }
            .padding(.horizontal, EQSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EQSpacing.sm) {
                    ForEach(Array(vm.horses.prefix(6))) { horse in
                        NavigationLink(value: horse) {
                            DashHorseCard(horse: horse, showOwner: isTrainer)
                        }
                        .buttonStyle(.eqPress)
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 6) // shadow room
            }
        }
    }
}

// MARK: - Hero Header

private struct HeroHeader: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(red: 0.07, green: 0.055, blue: 0.04)
            // Warm radial glow bottom-left
            RadialGradient(
                colors: [Color.eqBark.opacity(0.75), .clear],
                center: .init(x: 0.04, y: 1.4),
                startRadius: 0,
                endRadius: 320
            )
            // Top shadow for depth
            LinearGradient(
                colors: [Color.black.opacity(0.28), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.55)
            )
            // Right warmth
            LinearGradient(
                colors: [.clear, Color.eqLeather.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.eqFont(13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.50))
                Text(auth.user?.full_name?.components(separatedBy: " ").first ?? "Rider")
                    .font(.eqFont(42, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1.0)
                Text(dateString)
                    .font(.eqFont(12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .padding(.top, 3)
            }
            .padding(.horizontal, EQSpacing.lg)
            .padding(.bottom, EQSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 175)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Stat Card

private struct DashStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: EQSpacing.xs) {
            // Icon chip
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.eqLeather)
                .frame(width: 34, height: 34)
                .background(Color.eqLeather.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer()

            Text(value)
                .font(.eqFont(40, weight: .bold))
                .foregroundStyle(Color.eqInk)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.eqFont(12, weight: .regular))
                .foregroundStyle(Color.eqMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EQSpacing.md)
        .frame(height: 126)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .shadow(color: Color.eqInk.opacity(0.07), radius: 16, x: 0, y: 5)
    }
}

// MARK: - Horse Card (Airbnb listing card style)

private struct DashHorseCard: View {
    let horse: Horse
    var showOwner: Bool = false

    private let cardW: CGFloat = 160
    private let cardH: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed photo
            Group {
                if let img = horse.profile_image, !img.isEmpty {
                    AsyncImage(url: URL(string: img)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            photoPlaceholder
                        }
                    }
                } else {
                    photoPlaceholder
                }
            }
            .frame(width: cardW, height: cardH)
            .clipped()

            // Gradient scrim + text overlay
            VStack(alignment: .leading, spacing: 3) {
                if showOwner, let owner = horse.owner_email {
                    Text(owner.components(separatedBy: "@").first?.capitalized ?? owner)
                        .font(.eqFont(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                } else if let discipline = horse.discipline {
                    Text(discipline.uppercased())
                        .font(.eqFont(9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .kerning(0.8)
                        .lineLimit(1)
                }
                Text(horse.displayName)
                    .font(.eqFont(15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let breed = horse.breed {
                    Text("\(breed) · \(horse.ageString)")
                        .font(.eqFont(11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: cardW, height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .shadow(color: Color.eqInk.opacity(0.12), radius: 18, x: 0, y: 7)
    }

    private var photoPlaceholder: some View {
        ZStack {
            LinearGradient.eqHero
            VStack(spacing: 6) {
                Text(horse.displayName.prefix(2).uppercased())
                    .font(.eqFont(48, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                if let discipline = horse.discipline {
                    Text(discipline.uppercased())
                        .font(.eqFont(9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .kerning(1.5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Card

private struct DashEventCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 0) {
            // Left color bar
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(event.type.eventTypeColor)
                .frame(width: 5)
                .padding(.vertical, 16)
                .padding(.leading, EQSpacing.md)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.eqMuted)
                    Text(event.start_date.toDisplayDate(format: "MMM d · h:mm a"))
                        .font(.eqFont(12, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 18)

            Spacer()

            // Right: type badge + icon
            VStack(alignment: .trailing, spacing: 7) {
                Text(event.type.eventTypeLabel)
                    .font(.eqFont(10, weight: .semibold))
                    .foregroundStyle(event.type.eventTypeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.type.eventTypeColor.opacity(0.10), in: Capsule())
                Image(systemName: event.type.eventTypeIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(event.type.eventTypeColor.opacity(0.45))
            }
            .padding(.trailing, EQSpacing.md)
            .padding(.vertical, 18)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .shadow(color: Color.eqInk.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Conversation Card

private struct DashConvCard: View {
    let conv: Conversation
    let currentEmail: String

    private var displayName: String {
        let other = conv.otherParticipant(currentEmail: currentEmail)
        return other.components(separatedBy: "@").first?.capitalized ?? other
    }

    var body: some View {
        HStack(spacing: EQSpacing.sm) {
            InitialsAvatar(text: displayName, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.eqFont(15, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                if let last = conv.last_message {
                    Text(last)
                        .font(.eqFont(13, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let unread = conv.unread_count, unread > 0 {
                Text("\(unread)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 22, minHeight: 22)
                    .padding(.horizontal, 3)
                    .background(Color.eqLeather, in: Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.eqTaupe)
            }
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, EQSpacing.sm + 2)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
        .shadow(color: Color.eqInk.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Section Header

private struct DashSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.eqFont(18, weight: .semibold))
            .foregroundStyle(Color.eqInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
