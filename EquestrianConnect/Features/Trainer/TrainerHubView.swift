import SwiftUI

struct TrainerHubView: View {
    @Environment(AuthManager.self) private var auth
    @State private var horses: [Horse] = []
    @State private var ownerNames: [String: String] = [:]
    @State private var upcomingEvents: [CalendarEvent] = []
    @State private var trainingLogs: [TrainingLog] = []
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var error: String?

    private var ownerGroups: [(id: String, name: String, horses: [Horse])] {
        // Group by all owner IDs (combining owner_id + owner_ids)
        var groups: [String: [Horse]] = [:]
        for horse in horses {
            let ids = horse.allOwnerIds
            if ids.isEmpty {
                groups["", default: []].append(horse)
            } else {
                for oid in ids {
                    groups[oid, default: []].append(horse)
                }
            }
        }
        return groups.map { ownerId, hs in
            let name: String
            if ownerId.isEmpty {
                name = "No Owner"
            } else if let resolved = ownerNames[ownerId] {
                name = resolved
            } else if ownerId.contains("@") {
                name = String(ownerId.split(separator: "@").first ?? Substring(ownerId)).capitalized
            } else {
                name = ownerId
            }
            return (id: ownerId, name: name, horses: hs.sorted { $0.name < $1.name })
        }.sorted { $0.name < $1.name }
    }

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
                                        icon: "person.2.fill",
                                        value: "\(ownerGroups.count)",
                                        label: "Clients"
                                    )
                                    EQStatCard(
                                        icon: "checkmark.circle.fill",
                                        value: "\(todayRidden)/\(horses.count)",
                                        label: "Ridden Today",
                                        color: .eqChocolate
                                    )
                                }

                                // Today's Training — grouped by owner
                                if !ownerGroups.isEmpty {
                                    VStack(spacing: EQSpacing.sm) {
                                        EQSectionRow(title: "Today's Training")
                                        ForEach(ownerGroups, id: \.id) { group in
                                            OwnerTrainingSection(
                                                ownerName: group.name,
                                                ownerId: group.id,
                                                horses: group.horses,
                                                trainingLogs: trainingLogs,
                                                trainerId: auth.user?.id ?? ""
                                            ) { log in
                                                if let log {
                                                    trainingLogs.append(log)
                                                } else if let last = trainingLogs.last {
                                                    let today = Date().iso8601DateString
                                                    trainingLogs.removeAll {
                                                        group.horses.map(\.id).contains($0.horse_id) && $0.date == today
                                                    }
                                                    _ = last
                                                }
                                            } onRemove: { horseId in
                                                let today = Date().iso8601DateString
                                                trainingLogs.removeAll { $0.horse_id == horseId && $0.date == today }
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
                                            HubConvRow(conv: conv, currentUserId: auth.user?.id ?? "")
                                        }
                                    }
                                }

                                if horses.isEmpty && upcomingEvents.isEmpty {
                                    EmptyStateView(
                                        icon: "chart.bar.fill",
                                        title: "Your Hub is Ready",
                                        subtitle: "Once owners connect using your trainer code and assign horses to you, their training will appear here."
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
            }
            .eqNavAppearance()
            .eqMoreMenu()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @MainActor
    private func load() async {
        guard let user = auth.user else { return }
        let userId = user.id
        let userEmail = user.email ?? ""

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
        var trainerOrParts = "(trainer_id.eq.\(userId)"
        if !userEmail.isEmpty { trainerOrParts += ",trainer_id.eq.\(userEmail)" }
        trainerOrParts += ",trainer_ids.cs.{\(userId)}"
        if !userEmail.isEmpty { trainerOrParts += ",trainer_ids.cs.{\(userEmail)}" }
        trainerOrParts += ")"
        async let horsesTask: [Horse] = try SupabaseClient.shared.filter(
            table: "horses", query: [URLQueryItem(name: "or", value: trainerOrParts)], order: "name.asc", limit: 100
        )
        async let eventsTask: [CalendarEvent] = try SupabaseClient.shared.filter(
            table: "calendar_events", query: [URLQueryItem(name: "user_id", value: "eq.\(userId)")], order: "start_date.asc", limit: 20
        )
        async let logsTask: [TrainingLog] = try SupabaseClient.shared.filter(
            table: "training_logs", query: [URLQueryItem(name: "user_id", value: "eq.\(userId)")], order: "date.desc", limit: 200
        )
        async let convsTask: [Conversation] = try SupabaseClient.shared.list(
            table: "conversations", order: "last_message_date.desc", limit: 10
        )
        do {
            let (h, e, l, c) = try await (horsesTask, eventsTask, logsTask, convsTask)
            horses = h
            upcomingEvents = e.filter { ($0.start_date.toDate() ?? .distantPast) >= Date() }
            trainingLogs = l
            conversations = c
            await resolveOwnerNames()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func resolveOwnerNames() async {
        let allIds = Array(Set(horses.flatMap { $0.allOwnerIds }.filter { !$0.isEmpty }))
        guard !allIds.isEmpty else { return }
        let emails = allIds.filter { $0.contains("@") }
        let uuids  = allIds.filter { !$0.contains("@") }
        var map: [String: String] = [:]
        if let profiles = try? await SupabaseClient.shared.getProfiles(ids: uuids) {
            for p in profiles { map[p.id] = p.firstName }
        }
        if let profiles = try? await SupabaseClient.shared.getProfilesByEmail(emails: emails) {
            for p in profiles { map[p.email] = p.firstName }
        }
        await MainActor.run { ownerNames = map }
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

        let imgMidnight = "https://images.unsplash.com/photo-1670212433014-b2435aca06a4?w=400&fit=crop"
        let imgArrow    = "https://images.unsplash.com/photo-1517326451550-8612522c096e?w=400&fit=crop"
        let imgStorm    = "https://images.unsplash.com/photo-1641226469021-f81abb75108c?w=400&fit=crop"
        let imgRuby     = "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=400&fit=crop"

        horses = [
            Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                  breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                  gender: "mare", registration_number: nil, discipline: "Dressage",
                  owner_id: "jordan@demo.com", trainer_id: "preview-trainer",
                  profile_image: imgMidnight, total_earnings: nil, created_date: nil),
            Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                  breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                  gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                  owner_id: "sarah@demo.com", trainer_id: "preview-trainer",
                  profile_image: imgArrow, total_earnings: nil, created_date: nil),
            Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                  breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                  gender: "stallion", registration_number: nil, discipline: "Jumping",
                  owner_id: "mike@demo.com", trainer_id: "preview-trainer",
                  profile_image: imgStorm, total_earnings: nil, created_date: nil),
            Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                  breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                  gender: "mare", registration_number: nil, discipline: "Endurance",
                  owner_id: "lisa@demo.com", trainer_id: "preview-trainer",
                  profile_image: imgRuby, total_earnings: nil, created_date: nil),
        ]

        upcomingEvents = [
            CalendarEvent(id: "e1", title: "Farrier Visit", type: "farrier",
                          start_date: future(1), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: nil,
                          horse_ids: ["h1", "h2"], user_id: "preview-trainer",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e2", title: "Dressage Lesson — Midnight", type: "lesson",
                          start_date: future(3), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_id: "preview-trainer",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e3", title: "Spring Horse Show", type: "horse_show",
                          start_date: future(12), end_date: nil, all_day: true,
                          location: "County Equestrian Center", description: nil,
                          horse_ids: ["h1", "h2", "h3"], user_id: "preview-trainer",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
        ]

        trainingLogs = [
            TrainingLog(id: "l1", horse_id: "h1", date: now.iso8601DateString,
                        user_id: "preview-trainer", created_date: nil),
        ]

        var c1 = Conversation(id: "c1", participants: ["preview-trainer", "jordan@demo.com"],
                              horse_id: "h1", last_message: "How did Midnight do in her lesson?",
                              last_message_date: past(1), unread_count: 2, created_date: nil)
        c1.other_name = "Jordan"
        var c2 = Conversation(id: "c2", participants: ["preview-trainer", "sarah@demo.com"],
                              horse_id: "h2", last_message: "Arrow is ready for the show!",
                              last_message_date: past(5), unread_count: 1, created_date: nil)
        c2.other_name = "Sarah"
        var c3 = Conversation(id: "c3", participants: ["preview-trainer", "mike@demo.com"],
                              horse_id: "h3", last_message: "Can we reschedule Tuesday's session?",
                              last_message_date: past(24), unread_count: 0, created_date: nil)
        c3.other_name = "Mike"
        conversations = [c1, c2, c3]

        isLoading = false
    }
}

// MARK: - Owner Training Section

private struct OwnerTrainingSection: View {
    let ownerName: String
    let ownerId: String
    let horses: [Horse]
    let trainingLogs: [TrainingLog]
    let trainerId: String
    let onAdd: (TrainingLog?) -> Void
    let onRemove: (String) -> Void

    @Environment(MessagesViewModel.self) private var messagesVM
    @Environment(AuthManager.self) private var auth
    @State private var selectedConv: Conversation?

    var body: some View {
        VStack(spacing: 0) {
            // Owner header
            HStack(spacing: EQSpacing.sm) {
                InitialsAvatar(text: ownerName, size: 28, background: Color.eqMutedBrown)
                Text(ownerName)
                    .font(.eqFont(13, weight: .semibold))
                    .foregroundStyle(Color.eqSaddleBrown)
                Spacer()
                Text("\(ridden)/\(horses.count) ridden")
                    .font(.caption)
                    .foregroundStyle(Color.eqMuted)
                Button {
                    Task { await openChat() }
                } label: {
                    Image(systemName: "message")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.eqSaddleBrown)
                        .padding(6)
                        .background(Color.eqMutedBrown, in: Circle())
                }
            }
            .padding(.horizontal, EQSpacing.md)
            .padding(.vertical, EQSpacing.xs)
            .sheet(item: $selectedConv) { conv in
                NavigationStack { ChatView(conversation: conv, vm: messagesVM) }
            }

            VStack(spacing: EQSpacing.xs) {
                ForEach(horses) { horse in
                    TrainingCheckRow(
                        horse: horse,
                        isRidden: trainingLogs.contains(where: {
                            $0.horse_id == horse.id && $0.date == Date().iso8601DateString
                        }),
                        trainerId: trainerId
                    ) { log in
                        if let log {
                            onAdd(log)
                        } else {
                            onRemove(horse.id)
                        }
                    }
                }
            }
        }
        .padding(.bottom, EQSpacing.xs)
    }

    private var ridden: Int {
        let today = Date().iso8601DateString
        return horses.filter { horse in
            trainingLogs.contains { $0.horse_id == horse.id && $0.date == today }
        }.count
    }

    private func openChat() async {
        guard let myId = auth.user?.id else { return }
        let conv: Conversation?
        if ownerId.contains("@") {
            conv = try? await messagesVM.startConversation(withEmail: ownerId, currentUserId: myId)
        } else {
            conv = try? await messagesVM.startConversation(with: ownerId, currentUserId: myId)
        }
        await MainActor.run { if let conv { selectedConv = conv } }
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

struct TrainingCheckRow: View {
    let horse: Horse
    let isRidden: Bool
    let trainerId: String
    let onToggle: (TrainingLog?) -> Void

    @State private var isBusy = false

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
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
            if let logs: [TrainingLog] = try? await SupabaseClient.shared.filter(
                table: "training_logs",
                query: [URLQueryItem(name: "horse_id", value: "eq.\(horse.id)"),
                        URLQueryItem(name: "date", value: "eq.\(today)")]
            ), let existing = logs.first {
                try? await SupabaseClient.shared.delete(table: "training_logs", id: existing.id)
            }
            onToggle(nil)
        } else {
            let log = TrainingLog(id: UUID().uuidString, horse_id: horse.id, date: today, user_id: trainerId)
            let created: TrainingLog? = try? await SupabaseClient.shared.create(table: "training_logs", data: log)
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
    let currentUserId: String

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
                InitialsAvatar(text: conv.other_name ?? conv.otherParticipant(currentUserId: currentUserId), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.other_name ?? conv.otherParticipant(currentUserId: currentUserId))
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
