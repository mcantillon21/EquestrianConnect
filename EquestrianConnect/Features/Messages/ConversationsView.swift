import SwiftUI

struct ConversationsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(MessagesViewModel.self) private var vm
    @State private var showNewConv = false
    @State private var selectedConv: Conversation?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()

                if vm.isLoading {
                    EQLoadingView()
                } else if vm.conversations.isEmpty {
                    EmptyStateView(
                        icon: "message.fill",
                        title: "No Messages",
                        subtitle: "Start a conversation with a trainer or fellow owner",
                        actionTitle: "New Message",
                        action: { showNewConv = true }
                    )
                } else {
                    List {
                        ForEach(vm.conversations) { conv in
                            ConversationRow(
                                conv: conv,
                                currentUserId: auth.user?.id ?? ""
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedConv = conv }
                            .listRowBackground(Color.eqWarmWhite)
                            .listRowSeparatorTint(Color.eqLightTan)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Messages")
            .eqNavAppearance()
            .eqMoreMenu()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewConv = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showNewConv) {
                NewConversationView(vm: vm) { conv in
                    selectedConv = conv
                }
            }
            .navigationDestination(item: $selectedConv) { conv in
                ChatView(conversation: conv, vm: vm)
            }
            .task { await vm.loadConversations(currentUserId: auth.user?.id ?? "") }
            .refreshable { await vm.loadConversations(currentUserId: auth.user?.id ?? "") }
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conv: Conversation
    let currentUserId: String

    var body: some View {
        HStack(spacing: EQSpacing.md) {
            InitialsAvatar(
                text: conv.displayName(currentUserId: currentUserId),
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conv.displayName(currentUserId: currentUserId))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eqDarkBrown)
                    Spacer()
                    if let date = conv.last_message_date {
                        Text(date.toDisplayDate(format: "MMM d"))
                            .font(.caption)
                            .foregroundStyle(Color.eqMuted)
                    }
                }
                if let last = conv.last_message {
                    Text(last)
                        .font(.subheadline)
                        .foregroundStyle(Color.eqMuted)
                        .lineLimit(1)
                }
            }

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
        .padding(.vertical, EQSpacing.sm)
    }
}

// MARK: - New Conversation

private struct NewConversationView: View {
    let vm: MessagesViewModel
    let onCreated: (Conversation) -> Void
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isCreating = false
    @State private var error: String?
    @State private var suggestedContacts: [User] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: EQSpacing.lg) {
                        if let err = error {
                            ErrorBanner(message: err) { error = nil }
                                .padding(.horizontal, EQSpacing.md)
                        }

                        // Suggested contacts
                        if !suggestedContacts.isEmpty {
                            VStack(alignment: .leading, spacing: EQSpacing.sm) {
                                Text("SUGGESTED")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqMuted)
                                    .padding(.horizontal, EQSpacing.md)
                                ForEach(suggestedContacts) { contact in
                                    Button {
                                        startWith(userId: contact.id)
                                    } label: {
                                        HStack(spacing: EQSpacing.md) {
                                            InitialsAvatar(text: contact.displayName, size: 44)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.displayName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Color.eqDarkBrown)
                                                Text(contact.user_type == "trainer" ? "Trainer" : "Horse Owner")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.eqMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.eqLightTan)
                                        }
                                        .padding(.horizontal, EQSpacing.md)
                                        .padding(.vertical, 10)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
                                        .padding(.horizontal, EQSpacing.md)
                                    }
                                    .buttonStyle(.eqPress)
                                }
                            }

                            HStack {
                                Rectangle().fill(Color.eqLightTan).frame(height: 1)
                                Text("or")
                                    .font(.caption)
                                    .foregroundStyle(Color.eqMuted)
                                    .padding(.horizontal, EQSpacing.xs)
                                Rectangle().fill(Color.eqLightTan).frame(height: 1)
                            }
                            .padding(.horizontal, EQSpacing.md)
                        }

                        // Email search
                        VStack(alignment: .leading, spacing: EQSpacing.sm) {
                            if !suggestedContacts.isEmpty {
                                Text("FIND BY EMAIL")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eqMuted)
                                    .padding(.horizontal, EQSpacing.md)
                            }
                            EQTextField(
                                label: "Email Address",
                                placeholder: "name@example.com",
                                text: $email,
                                icon: "envelope",
                                keyboard: .emailAddress
                            )
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, EQSpacing.md)

                            EQPrimaryButton(title: "Start Conversation", isLoading: isCreating) {
                                start()
                            }
                            .padding(.horizontal, EQSpacing.md)
                        }
                    }
                    .padding(.top, EQSpacing.lg)
                    .padding(.bottom, EQSpacing.xxl)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .eqNavAppearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .task { await loadSuggested() }
        }
    }

    private func loadSuggested() async {
        guard let user = auth.user else { return }
        guard !isDemoMode else { return }
        #if targetEnvironment(simulator)
        return
        #endif
        var contacts: [User] = []
        // For owners: load their trainer
        if user.isOwner, let trainerId = user.trainer_id, !trainerId.isEmpty {
            if let trainer: User = try? await SupabaseClient.shared.get(table: "profiles", id: trainerId) {
                contacts.append(trainer)
            }
        }
        // For trainers: load recent horse owners they manage
        if user.isTrainer {
            let horses: [Horse] = (try? await SupabaseClient.shared.filter(
                table: "horses",
                query: [URLQueryItem(name: "trainer_id", value: "eq.\(user.id)")],
                limit: 20
            )) ?? []
            let ownerIds = Array(Set(horses.compactMap { $0.owner_id }.filter { !$0.isEmpty && !$0.contains("@") }))
            if !ownerIds.isEmpty, let profiles = try? await SupabaseClient.shared.getProfiles(ids: ownerIds) {
                contacts.append(contentsOf: profiles)
            }
        }
        await MainActor.run { suggestedContacts = contacts }
    }

    private func start() {
        guard email.isValidEmail else {
            error = "Please enter a valid email."
            return
        }
        guard let me = auth.user else { return }
        isCreating = true
        Task {
            do {
                let conv = try await vm.startConversation(withEmail: email, currentUserId: me.id)
                dismiss()
                onCreated(conv)
            } catch SupabaseError.notFound {
                self.error = "No user found with that email."
            } catch {
                self.error = error.localizedDescription
            }
            isCreating = false
        }
    }

    private func startWith(userId: String) {
        guard let me = auth.user else { return }
        isCreating = true
        Task {
            do {
                let conv = try await vm.startConversation(with: userId, currentUserId: me.id)
                dismiss()
                onCreated(conv)
            } catch {
                self.error = error.localizedDescription
            }
            isCreating = false
        }
    }
}
