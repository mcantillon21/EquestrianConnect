import SwiftUI

struct ConversationsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = MessagesViewModel()
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
                                currentEmail: auth.user?.email ?? ""
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
            .task { await vm.loadConversations() }
            .refreshable { await vm.loadConversations() }
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conv: Conversation
    let currentEmail: String

    var body: some View {
        HStack(spacing: EQSpacing.md) {
            InitialsAvatar(
                text: conv.otherParticipant(currentEmail: currentEmail),
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conv.otherParticipant(currentEmail: currentEmail))
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eqWarmWhite.ignoresSafeArea()
                VStack(spacing: EQSpacing.md) {
                    if let err = error {
                        ErrorBanner(message: err) { error = nil }
                    }
                    EQTextField(
                        label: "Contact Email",
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
                    Spacer()
                }
                .padding(.top, EQSpacing.lg)
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
        }
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
                let conv = try await vm.startConversation(with: email, currentEmail: me.email)
                dismiss()
                onCreated(conv)
            } catch {
                self.error = error.localizedDescription
            }
            isCreating = false
        }
    }
}
