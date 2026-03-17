import SwiftUI

struct HorsesView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = HorsesViewModel()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView()
                } else if vm.filtered.isEmpty {
                    EmptyStateView(
                        icon: "figure.equestrian.sports",
                        title: vm.searchText.isEmpty ? "No Horses Yet" : "No Results",
                        subtitle: vm.searchText.isEmpty ? "Add your first horse to start tracking care, training, and more." : "Try a different search.",
                        actionTitle: vm.searchText.isEmpty ? "Add Horse" : nil,
                        action: vm.searchText.isEmpty ? { showAddSheet = true } : nil
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(vm.filtered) { horse in
                                NavigationLink(value: horse) {
                                    HorseListCard(horse: horse)
                                }
                                .buttonStyle(.eqPress)
                                if horse.id != vm.filtered.last?.id {
                                    EQDivider().padding(.leading, 80)
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
            .navigationTitle("My Horses")
            .eqNavAppearance()
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
            .navigationDestination(for: Horse.self) { horse in
                HorseProfileView(horse: horse, vm: vm)
            }
            .sheet(isPresented: $showAddSheet) {
                HorseFormView(vm: vm)
            }
            .task {
                guard let user = auth.user else { return }
                await vm.load(userEmail: user.email, isTrainer: user.isTrainer)
            }
            .refreshable {
                guard let user = auth.user else { return }
                await vm.load(userEmail: user.email, isTrainer: user.isTrainer)
            }
        }
    }
}

// MARK: - Horse List Card

private struct HorseListCard: View {
    let horse: Horse

    var body: some View {
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
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(horse.name)
                    .font(.eqFont(16, weight: .semibold))
                    .foregroundStyle(Color.eqInk)

                HStack(spacing: EQSpacing.xs) {
                    if let breed = horse.breed {
                        Text(breed)
                            .font(.eqFont(13, weight: .regular))
                            .foregroundStyle(Color.eqMuted)
                        Text("·").font(.eqFont(13)).foregroundStyle(Color.eqMuted)
                    }
                    Text(horse.genderLabel)
                        .font(.eqFont(13, weight: .regular))
                        .foregroundStyle(Color.eqMuted)
                    if let age = horse.age {
                        Text("·").font(.eqFont(13)).foregroundStyle(Color.eqMuted)
                        Text("\(age)y")
                            .font(.eqFont(13, weight: .regular))
                            .foregroundStyle(Color.eqMuted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.eqTaupe)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, 13)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color.eqParchment)
            Text(horse.displayName.prefix(1).uppercased())
                .font(.eqFont(20, weight: .semibold))
                .foregroundStyle(Color.eqLeather)
        }
    }
}
