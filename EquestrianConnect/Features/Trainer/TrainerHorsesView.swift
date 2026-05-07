import SwiftUI

struct TrainerHorsesView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = HorsesViewModel()
    @State private var ownerNames: [String: String] = [:]
    @State private var showAddSheet = false

    private var ownerGroups: [(id: String, displayName: String, horses: [Horse])] {
        var groups: [String: [Horse]] = [:]
        for horse in vm.horses {
            let ids = horse.allOwnerIds
            if ids.isEmpty {
                groups["", default: []].append(horse)
            } else {
                for oid in ids {
                    groups[oid, default: []].append(horse)
                }
            }
        }
        return groups.map { ownerId, horses in
            let name: String
            if ownerId.isEmpty {
                name = "No Owner Assigned"
            } else if let resolved = ownerNames[ownerId] {
                name = resolved
            } else if ownerId.contains("@") {
                name = String(ownerId.split(separator: "@").first ?? Substring(ownerId)).capitalized
            } else {
                name = ownerId
            }
            return (id: ownerId, displayName: name, horses: horses.sorted { $0.name < $1.name })
        }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView()
                } else if ownerGroups.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Clients Yet",
                        subtitle: "Add a horse and assign an owner, or have owners add you as their trainer.",
                        actionTitle: "Add Horse",
                        action: { showAddSheet = true }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(ownerGroups, id: \.id) { group in
                                NavigationLink {
                                    OwnerHorsesView(
                                        ownerName: group.displayName,
                                        ownerId: group.id,
                                        horses: group.horses,
                                        vm: vm
                                    )
                                } label: {
                                    OwnerRow(
                                        name: group.displayName,
                                        horseCount: group.horses.count
                                    )
                                }
                                .buttonStyle(.eqPress)
                                if group.id != ownerGroups.last?.id {
                                    EQDivider().padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: EQRadius.lg, style: .continuous))
                        .shadow(color: Color.eqInk.opacity(0.06), radius: 14, x: 0, y: 5)
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.vertical, EQSpacing.md)
                    }
                }
            }
            .navigationTitle("Clients")
            .eqNavAppearance()
            .eqMoreMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                HorseFormView(vm: vm)
            }
            .navigationDestination(for: Horse.self) { horse in
                HorseProfileView(horse: horse, vm: vm)
            }
            .task {
                guard let user = auth.user else { return }
                await vm.load(userId: user.id, userEmail: user.email ?? "", isTrainer: true)
                await resolveOwnerNames()
            }
            .refreshable {
                guard let user = auth.user else { return }
                await vm.load(userId: user.id, userEmail: user.email ?? "", isTrainer: true)
                await resolveOwnerNames()
            }
        }
    }

    private func resolveOwnerNames() async {
        guard !isDemoMode else { return }
        #if targetEnvironment(simulator)
        return
        #endif
        let allIds = Array(Set(vm.horses.flatMap { $0.allOwnerIds }.filter { !$0.isEmpty }))
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
}

// MARK: - Owner Row

private struct OwnerRow: View {
    let name: String
    let horseCount: Int

    var body: some View {
        HStack(spacing: EQSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.eqMutedBrown)
                    .frame(width: 48, height: 48)
                Text(name.prefix(2).uppercased())
                    .font(.eqFont(16, weight: .bold))
                    .foregroundStyle(Color.eqSaddleBrown)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.eqFont(16, weight: .semibold))
                    .foregroundStyle(Color.eqInk)
                Text("\(horseCount) \(horseCount == 1 ? "horse" : "horses")")
                    .font(.eqFont(13, weight: .regular))
                    .foregroundStyle(Color.eqMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eqLightTan)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Owner Horses Detail View

struct OwnerHorsesView: View {
    let ownerName: String
    let ownerId: String
    let horses: [Horse]
    let vm: HorsesViewModel
    @Environment(MessagesViewModel.self) private var messagesVM
    @Environment(AuthManager.self) private var auth
    @State private var showAddSheet = false
    @State private var selectedConv: Conversation?

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: EQSpacing.sm) {
                    ForEach(horses) { horse in
                        NavigationLink {
                            HorseProfileView(horse: horse, vm: vm)
                        } label: {
                            TrainerHorseCard(horse: horse)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, EQSpacing.md)
            }
        }
        .navigationTitle(ownerName)
        .navigationBarTitleDisplayMode(.large)
        .eqNavAppearance()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: EQSpacing.sm) {
                    Button {
                        Task { await openChat() }
                    } label: {
                        Image(systemName: "message")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HorseFormView(vm: vm)
        }
        .sheet(item: $selectedConv) { conv in
            NavigationStack { ChatView(conversation: conv, vm: messagesVM) }
        }
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

// MARK: - Trainer Horse Card

struct TrainerHorseCard: View {
    let horse: Horse
    @State private var todayRidden = false

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
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(horse.name)
                        .font(.eqSerif(.headline, weight: .bold))
                        .foregroundStyle(Color.eqDarkBrown)

                    HStack(spacing: EQSpacing.xs) {
                        if let breed = horse.breed {
                            Text(breed)
                                .font(.caption)
                                .foregroundStyle(Color.eqMuted)
                            Text("·").font(.caption).foregroundStyle(Color.eqMuted)
                        }
                        Text(horse.genderLabel)
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                    }

                    if let discipline = horse.discipline {
                        Text(discipline)
                            .font(.caption)
                            .foregroundStyle(Color.eqSaddleBrown)
                    }
                }

                Spacer()

                VStack(spacing: EQSpacing.xs) {
                    Image(systemName: todayRidden ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(todayRidden ? Color.eqSaddleBrown : Color.eqLightTan)
                    Text(todayRidden ? "Ridden" : "Today")
                        .font(.caption2)
                        .foregroundStyle(Color.eqMuted)
                }
            }
        }
        .task { await checkToday() }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EQRadius.sm, style: .continuous)
                .fill(Color.eqMutedBrown)
            Image(systemName: "figure.equestrian.sports")
                .font(.title2)
                .foregroundStyle(Color.eqSaddleBrown)
        }
    }

    private func checkToday() async {
        guard !isDemoMode else { return }
        #if targetEnvironment(simulator)
        return
        #endif
        let today = Date().iso8601DateString
        if let logs: [TrainingLog] = try? await SupabaseClient.shared.filter(
            table: "training_logs",
            query: [URLQueryItem(name: "horse_id", value: "eq.\(horse.id)"),
                    URLQueryItem(name: "date", value: "eq.\(today)")]
        ) {
            await MainActor.run { todayRidden = !logs.isEmpty }
        }
    }
}
