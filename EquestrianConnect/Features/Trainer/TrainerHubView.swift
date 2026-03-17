import SwiftUI

struct TrainerHubView: View {
    @Environment(AuthManager.self) private var auth
    @State private var horses: [Horse] = []
    @State private var upcomingEvents: [CalendarEvent] = []
    @State private var trainingLogs: [TrainingLog] = []
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var error: String?

    private var todayRidden: Int {
        let today = Date().iso8601DateString
        return trainingLogs.filter { $0.date == today }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if isLoading {
                    EQLoadingView()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            TrainerHeroHeader()

                            VStack(spacing: EQSpacing.lg) {
                                // Stats row
                                HStack(spacing: EQSpacing.sm) {
                                    EQStatCard(
                                        icon: "figure.equestrian.sports",
                                        value: "\(horses.count)",
                                        label: "Client Horses"
                                    )
                                    EQStatCard(
                                        icon: "checkmark.circle.fill",
                                        value: "\(todayRidden)/\(horses.count)",
                                        label: "Ridden Today",
                                        color: .eqChocolate
                                    )
                                }

                                // Today's Training
                                if !horses.isEmpty {
                                    VStack(spacing: EQSpacing.sm) {
                                        EQSectionRow(title: "Today's Training")
                                        ForEach(horses) { horse in
                                            TrainingCheckRow(
                                                horse: horse,
                                                isRidden: trainingLogs.contains(where: {
                                                    $0.horse_id == horse.id && $0.date == Date().iso8601DateString
                                                }),
                                                trainerEmail: auth.user?.email ?? ""
                                            ) { log in
                                                if let log {
                                                    trainingLogs.append(log)
                                                } else {
                                                    let today = Date().iso8601DateString
                                                    trainingLogs.removeAll { $0.horse_id == horse.id && $0.date == today }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Upcoming Events
                                if !upcomingEvents.isEmpty {
                                    VStack(spacing: EQSpacing.sm) {
                                        EQSectionRow(title: "Upcoming Events")
                                        ForEach(upcomingEvents.prefix(3)) { event in
                                            HubEventRow(event: event)
                                        }
                                    }
                                }

                                // Client Messages
                                if !conversations.isEmpty {
                                    VStack(spacing: EQSpacing.sm) {
                                        EQSectionRow(title: "Recent Messages")
                                        ForEach(conversations.prefix(3)) { conv in
                                            HubConvRow(conv: conv, currentEmail: auth.user?.email ?? "")
                                        }
                                    }
                                }

                                if horses.isEmpty && upcomingEvents.isEmpty {
                                    EmptyStateView(
                                        icon: "chart.bar.fill",
                                        title: "Your Hub is Ready",
                                        subtitle: "Once owners assign their horses to you, they'll appear here for daily tracking."
                                    )
                                    .frame(height: 280)
                                }
                            }
                            .padding(.horizontal, EQSpacing.md)
                            .padding(.bottom, EQSpacing.xxl)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Trainer Hub")
                        .font(.eqSerif(.headline, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    InitialsAvatar(
                        text: auth.user?.displayName ?? "?",
                        size: 34,
                        background: Color.eqSandyBrown
                    )
                }
            }
            .eqNavAppearance()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @MainActor
    private func load() async {
        guard let email = auth.user?.email else { return }

        #if targetEnvironment(simulator)
        loadMock()
        return
        #endif
        if isDemoMode {
            loadMock()
            return
        }

        isLoading = true
        error = nil
        async let horsesTask: [Horse] = try Base44Client.shared.filter(
            entity: "Horse", query: ["trainer_email": email], sort: "name", limit: 100
        )
        async let eventsTask: [CalendarEvent] = try Base44Client.shared.filter(
            entity: "CalendarEvent", query: ["user_email": email], sort: "start_date", limit: 20
        )
        async let logsTask: [TrainingLog] = try Base44Client.shared.filter(
            entity: "TrainingLog", query: ["user_email": email], sort: "-date", limit: 200
        )
        async let convsTask: [Conversation] = try Base44Client.shared.list(
            entity: "Conversation", sort: "-last_message_date", limit: 10
        )
        do {
            let (h, e, l, c) = try await (horsesTask, eventsTask, logsTask, convsTask)
            horses = h
            upcomingEvents = e.filter { ($0.start_date.toDate() ?? .distantPast) >= Date() }
            trainingLogs = l
            conversations = c
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func loadMock() {
        let cal = Calendar.current
        let now = Date()
        func future(_ days: Int) -> String {
            cal.date(byAdding: .day, value: days, to: now)!.iso8601DateString
        }
        func past(_ hours: Int) -> String {
            cal.date(byAdding: .hour, value: -hours, to: now)!.iso8601DateString
        }

        horses = [
            Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                  breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                  gender: "mare", registration_number: nil, discipline: "Dressage",
                  owner_email: "jordan@eq.app", trainer_email: "preview@eq.app",
                  profile_image: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Applebite-Gentlemen.jpg/400px-Applebite-Gentlemen.jpg",
                  total_earnings: nil, created_date: nil),
            Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                  breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                  gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                  owner_email: "sarah@eq.app", trainer_email: "preview@eq.app",
                  profile_image: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Mare_and_foal_%28Kvetina-Marie%29.jpg/400px-Mare_and_foal_%28Kvetina-Marie%29.jpg",
                  total_earnings: nil, created_date: nil),
            Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                  breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                  gender: "stallion", registration_number: nil, discipline: "Jumping",
                  owner_email: "mike@eq.app", trainer_email: "preview@eq.app",
                  profile_image: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/WCLV07m.JPG/400px-WCLV07m.JPG",
                  total_earnings: nil, created_date: nil),
            Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                  breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                  gender: "mare", registration_number: nil, discipline: "Endurance",
                  owner_email: "lisa@eq.app", trainer_email: "preview@eq.app",
                  profile_image: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Halterstandingshotarabianone.jpg/400px-Halterstandingshotarabianone.jpg",
                  total_earnings: nil, created_date: nil),
        ]

        upcomingEvents = [
            CalendarEvent(id: "e1", title: "Farrier Visit", type: "farrier",
                          start_date: future(1), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: nil,
                          horse_ids: ["h1", "h2"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e2", title: "Dressage Lesson — Midnight", type: "lesson",
                          start_date: future(3), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e3", title: "Spring Horse Show", type: "horse_show",
                          start_date: future(12), end_date: nil, all_day: true,
                          location: "County Equestrian Center", description: nil,
                          horse_ids: ["h1", "h2", "h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
        ]

        // Pre-mark Midnight as ridden today for a realistic demo
        trainingLogs = [
            TrainingLog(id: "l1", horse_id: "h1", date: now.iso8601DateString,
                        user_email: "preview@eq.app", created_date: nil),
        ]

        conversations = [
            Conversation(id: "c1", participants: ["preview@eq.app", "jordan@eq.app"],
                         horse_id: "h1", last_message: "How did Midnight do in her lesson?",
                         last_message_date: past(1), unread_count: 2, created_date: nil),
            Conversation(id: "c2", participants: ["preview@eq.app", "sarah@eq.app"],
                         horse_id: "h2", last_message: "Arrow is ready for the show!",
                         last_message_date: past(5), unread_count: 1, created_date: nil),
            Conversation(id: "c3", participants: ["preview@eq.app", "mike@eq.app"],
                         horse_id: "h3", last_message: "Can we reschedule Tuesday's session?",
                         last_message_date: past(24), unread_count: 0, created_date: nil),
        ]

        isLoading = false
    }
}

// MARK: - Trainer Hero Header

private struct TrainerHeroHeader: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.eqDarkBrown, Color(red: 0.25, green: 0.12, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 150)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundStyle(Color.eqSandyBrown.opacity(0.8))
                Text(auth.user?.full_name?.components(separatedBy: " ").first ?? "Trainer")
                    .font(.eqSerif(.title, weight: .bold))
                    .foregroundStyle(.white)
                Text(Date().formatted("EEEE, MMMM d"))
                    .font(.caption)
                    .foregroundStyle(Color.eqSandyBrown.opacity(0.7))
            }
            .padding(EQSpacing.md)
        }
    }
}

// MARK: - Training Check Row

private struct TrainingCheckRow: View {
    let horse: Horse
    let isRidden: Bool
    let trainerEmail: String
    let onToggle: (TrainingLog?) -> Void

    @State private var isBusy = false

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
                // Horse avatar
                Group {
                    if let img = horse.profile_image, !img.isEmpty {
                        AsyncImage(url: URL(string: img)) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: placeholder
                            }
                        }
                    } else {
                        placeholder
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(horse.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqDarkBrown)
                    if let breed = horse.breed {
                        Text(breed)
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                    }
                }

                Spacer()

                Button {
                    guard !isBusy else { return }
                    Task { await toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRidden ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isRidden ? Color.eqSaddleBrown : Color.eqLightTan)
                        Text(isRidden ? "Ridden" : "Mark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isRidden ? Color.eqSaddleBrown : Color.eqMuted)
                    }
                }
                .disabled(isBusy)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.eqMutedBrown)
            Image(systemName: "figure.equestrian.sports")
                .font(.caption)
                .foregroundStyle(Color.eqSaddleBrown)
        }
    }

    private func toggle() async {
        isBusy = true
        let today = Date().iso8601DateString
        if isRidden {
            // Find and delete the log
            if let logs: [TrainingLog] = try? await Base44Client.shared.filter(
                entity: "TrainingLog",
                query: ["horse_id": horse.id],
                limit: 50
            ), let existing = logs.first(where: { $0.date == today }) {
                try? await Base44Client.shared.delete(entity: "TrainingLog", id: existing.id)
            }
            onToggle(nil)
        } else {
            let log = TrainingLog(id: UUID().uuidString, horse_id: horse.id, date: today, user_email: trainerEmail)
            let created: TrainingLog? = try? await Base44Client.shared.create(entity: "TrainingLog", data: log)
            onToggle(created)
        }
        isBusy = false
    }
}

// MARK: - Hub Event Row

private struct HubEventRow: View {
    let event: CalendarEvent

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                        .fill(event.type.eventTypeColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: event.type.eventTypeIcon)
                        .font(.body)
                        .foregroundStyle(event.type.eventTypeColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqDarkBrown)
                    Text(event.start_date.toDisplayDate(format: "EEE, MMM d · h:mm a"))
                        .font(.caption)
                        .foregroundStyle(Color.eqMuted)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Hub Conversation Row

private struct HubConvRow: View {
    let conv: Conversation
    let currentEmail: String

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
                InitialsAvatar(text: conv.otherParticipant(currentEmail: currentEmail), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.otherParticipant(currentEmail: currentEmail))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqDarkBrown)
                    if let last = conv.last_message {
                        Text(last)
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let unread = conv.unread_count, unread > 0 {
                    ZStack {
                        Circle().fill(Color.eqSaddleBrown)
                        Text("\(unread)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 20, height: 20)
                }
            }
        }
    }
}
