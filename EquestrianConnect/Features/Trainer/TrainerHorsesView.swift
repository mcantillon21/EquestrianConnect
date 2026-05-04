import SwiftUI

struct TrainerHorsesView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = HorsesViewModel()
    @State private var selectedOwner = ""
    @State private var showAddSheet = false

    private var owners: [String] {
        let emails = vm.horses.compactMap { $0.owner_id }
        return Array(Set(emails)).sorted()
    }

    private var filtered: [Horse] {
        guard !selectedOwner.isEmpty else { return vm.filtered }
        return vm.filtered.filter { $0.owner_id == selectedOwner }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Owner filter pills
                    if !owners.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: EQSpacing.sm) {
                                OwnerPill(label: "All", isSelected: selectedOwner.isEmpty) {
                                    selectedOwner = ""
                                }
                                ForEach(owners, id: \.self) { email in
                                    OwnerPill(
                                        label: email.components(separatedBy: "@").first?.capitalized ?? email,
                                        isSelected: selectedOwner == email
                                    ) {
                                        selectedOwner = email
                                    }
                                }
                            }
                            .padding(.horizontal, EQSpacing.md)
                            .padding(.vertical, EQSpacing.sm)
                        }
                        EQDivider()
                    }

                    if vm.isLoading {
                        EQLoadingView()
                    } else if filtered.isEmpty {
                        EmptyStateView(
                            icon: "figure.equestrian.sports",
                            title: "No Client Horses",
                            subtitle: vm.searchText.isEmpty
                                ? "Owners can assign horses to you by adding your email as their trainer."
                                : "No horses match your search."
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: EQSpacing.sm) {
                                ForEach(filtered) { horse in
                                    NavigationLink(value: horse) {
                                        TrainerHorseCard(horse: horse)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, EQSpacing.md)
                            .padding(.vertical, EQSpacing.md)
                        }
                    }
                }
            }
            .navigationTitle("Client Horses")
            .eqNavAppearance()
            .eqMoreMenu()
            .searchable(text: $vm.searchText, prompt: "Search horses…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
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
                guard let id = auth.user?.id else { return }
                await vm.load(userId: id, isTrainer: true)
            }
            .refreshable {
                guard let id = auth.user?.id else { return }
                await vm.load(userId: id, isTrainer: true)
            }
        }
    }
}

// MARK: - Owner Filter Pill

private struct OwnerPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.eqSaddleBrown)
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AnyShapeStyle(Color.eqSaddleBrown) : AnyShapeStyle(Color.eqMutedBrown),
                    in: Capsule()
                )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Trainer Horse Card

private struct TrainerHorseCard: View {
    let horse: Horse
    @State private var todayRidden = false

    var body: some View {
        EQCard {
            HStack(spacing: EQSpacing.md) {
                // Photo
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

                    if let owner = horse.owner_id {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption2)
                                .foregroundStyle(Color.eqSaddleBrown)
                            Text(owner.components(separatedBy: "@").first ?? owner)
                                .font(.caption)
                                .foregroundStyle(Color.eqSaddleBrown)
                        }
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
        let today = Date().iso8601DateString
        if let logs: [TrainingLog] = try? await SupabaseClient.shared.filter(
            table: "training_logs",
            query: [URLQueryItem(name: "horse_id", value: "eq.\(horse.id)"),
                    URLQueryItem(name: "date", value: "eq.\(today)")]
        ) {
            todayRidden = !logs.isEmpty
        }
    }
}
