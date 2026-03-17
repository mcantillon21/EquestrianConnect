import SwiftUI

struct HorseProfileView: View {
    let horse: Horse
    let vm: HorsesViewModel
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var selectedTab = "overview"
    @Environment(\.dismiss) private var dismiss

    private let tabs = ["overview", "health", "training", "earnings"]

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HorseHeroHeader(horse: horse)

                    // Tab Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                Button {
                                    withAnimation(.eqSnap) {
                                        selectedTab = tab
                                    }
                                    HapticFeedback.selection()
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(tab.capitalized)
                                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                            .foregroundStyle(selectedTab == tab ? Color.eqSaddleBrown : Color.eqMuted)
                                        Rectangle()
                                            .fill(selectedTab == tab ? Color.eqSaddleBrown : Color.clear)
                                            .frame(height: 2)
                                    }
                                    .padding(.horizontal, EQSpacing.md)
                                    .padding(.vertical, EQSpacing.sm)
                                }
                            }
                        }
                    }
                    .background(Color.eqWarmWhite)
                    .overlay(alignment: .bottom) {
                        EQDivider()
                    }

                    // Tab Content
                    Group {
                        switch selectedTab {
                        case "overview":  OverviewTab(horse: horse)
                        case "health":    HealthTab(horse: horse)
                        case "training":  TrainingTab(horse: horse)
                        case "earnings":  EarningsTab(horse: horse)
                        default:          EmptyView()
                        }
                    }
                    .padding(.horizontal, EQSpacing.md)
                    .padding(.vertical, EQSpacing.md)
                }
            }
        }
        .navigationTitle(horse.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .eqNavAppearance()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.white)
                }
                Menu {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Horse", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            HorseFormView(vm: vm, editingHorse: horse)
        }
        .alert("Delete \(horse.name)?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await vm.delete(horse)
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Hero Header

private struct HorseHeroHeader: View {
    let horse: Horse

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Group {
                if let img = horse.profile_image, !img.isEmpty {
                    AsyncImage(url: URL(string: img)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            LinearGradient.eqBrown
                        }
                    }
                } else {
                    LinearGradient.eqBrown
                }
            }
            .frame(height: 260)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .eqDarkBrown.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)

            // Info overlay
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(horse.name)
                        .font(.eqSerif(.title, weight: .bold))
                        .foregroundStyle(.white)
                    if let barnName = horse.barn_name {
                        Text("\"\(barnName)\"")
                            .font(.subheadline)
                            .foregroundStyle(Color.eqSandyBrown)
                            .italic()
                    }
                }
                Spacer()
                if let disc = horse.discipline {
                    EQBadge(text: disc)
                }
            }
            .padding(EQSpacing.md)
        }
    }
}

// MARK: - Overview Tab

private struct OverviewTab: View {
    let horse: Horse

    private let fields: [(String, String?)] = []

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            EQCard {
                VStack(spacing: 0) {
                    ForEach(details, id: \.0) { label, value in
                        if let v = value, !v.isEmpty {
                            HStack {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.eqMuted)
                                Spacer()
                                Text(v)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.eqDarkBrown)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 10)
                            EQDivider()
                        }
                    }
                }
                .padding(.vertical, -8)
            }
        }
    }

    private var details: [(String, String?)] {
        [
            ("Breed",               horse.breed),
            ("Color",               horse.color),
            ("Gender",              horse.gender.map { $0.capitalized }),
            ("Date of Birth",       horse.date_of_birth?.toDisplayDate()),
            ("Age",                 horse.age.map { "\($0) years" }),
            ("Discipline",          horse.discipline),
            ("Registration #",      horse.registration_number),
            ("Owner",               horse.owner_email),
            ("Trainer",             horse.trainer_email),
        ]
    }
}

// MARK: - Health Tab (placeholder)

private struct HealthTab: View {
    let horse: Horse

    var body: some View {
        EmptyStateView(
            icon: "cross.case.fill",
            title: "Health Records",
            subtitle: "Vet records, farrier visits, and health notes will appear here"
        )
        .frame(height: 300)
    }
}

// MARK: - Training Tab

private struct TrainingTab: View {
    let horse: Horse
    @State private var logs: [TrainingLog] = []
    @State private var isLoading = false
    @State private var isTodayLogged = false
    @Environment(AuthManager.self) private var auth

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            // Mark as Ridden Today
            EQCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Training")
                            .font(.eqSerif(.subheadline, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                        Text(Date().formatted("EEEE, MMM d"))
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                    }
                    Spacer()
                    Button {
                        Task { await toggleToday() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isTodayLogged ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isTodayLogged ? Color.eqSaddleBrown : Color.eqLightTan)
                            Text(isTodayLogged ? "Ridden" : "Mark Ridden")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(isTodayLogged ? Color.eqSaddleBrown : Color.eqMuted)
                        }
                    }
                    .disabled(isLoading)
                }
            }

            if logs.isEmpty {
                EmptyStateView(
                    icon: "figure.equestrian.sports",
                    title: "No Training Logs",
                    subtitle: "Mark sessions as completed to build a training history"
                )
                .frame(height: 200)
            } else {
                VStack(spacing: EQSpacing.xs) {
                    ForEach(logs.prefix(30)) { log in
                        EQCard(padding: EQSpacing.sm) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.eqSaddleBrown)
                                Text(log.date.toDisplayDate())
                                    .font(.subheadline)
                                    .foregroundStyle(Color.eqDarkBrown)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .task { await loadLogs() }
    }

    private func loadLogs() async {
        isLoading = true
        do {
            logs = try await Base44Client.shared.filter(
                entity: "TrainingLog",
                query: ["horse_id": horse.id],
                sort: "-date",
                limit: 30
            )
            let today = Date().iso8601DateString
            isTodayLogged = logs.contains(where: { $0.date == today })
        } catch {}
        isLoading = false
    }

    private func toggleToday() async {
        let today = Date().iso8601DateString
        if isTodayLogged {
            if let log = logs.first(where: { $0.date == today }) {
                try? await Base44Client.shared.delete(entity: "TrainingLog", id: log.id)
                logs.removeAll { $0.date == today }
                isTodayLogged = false
            }
        } else {
            let new = TrainingLog(
                id: UUID().uuidString,
                horse_id: horse.id,
                date: today,
                user_email: auth.user?.email
            )
            if let created: TrainingLog = try? await Base44Client.shared.create(entity: "TrainingLog", data: new) {
                logs.insert(created, at: 0)
                isTodayLogged = true
            }
        }
    }
}

// MARK: - Earnings Tab

private struct EarningsTab: View {
    let horse: Horse

    var body: some View {
        VStack(spacing: EQSpacing.md) {
            if let earnings = horse.total_earnings {
                EQCard {
                    VStack(spacing: EQSpacing.sm) {
                        Text("Total Earnings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.eqMuted)
                        Text(earnings.currencyString)
                            .font(.eqSerif(.title, weight: .bold))
                            .foregroundStyle(Color.eqDarkBrown)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EQSpacing.sm)
                }
            }
            EmptyStateView(
                icon: "dollarsign.circle.fill",
                title: "Earnings History",
                subtitle: "Show earnings and prize money history here"
            )
            .frame(height: 200)
        }
    }
}
