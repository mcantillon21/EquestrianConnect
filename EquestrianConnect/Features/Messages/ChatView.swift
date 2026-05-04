import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let vm: MessagesViewModel
    @Environment(AuthManager.self) private var auth
    @State private var error: String?

    private var myId: String { auth.user?.id ?? "" }
    private var otherId: String { conversation.otherParticipant(currentUserId: myId) }
    private var messages: [Message] { vm.messages[conversation.id] ?? [] }

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                if let err = error {
                    ErrorBanner(message: err) { error = nil }
                }

                // Messages list — isolated struct so input bar state never triggers its re-render
                MessagesList(messages: messages)

                // Input bar — owns its own @State so typing only re-renders this view
                EQDivider()
                ChatInputBar { content in
                    try await vm.sendMessage(
                        conversationId: conversation.id,
                        content: content,
                        senderId: myId,
                        recipientId: otherId
                    )
                } onError: { msg in
                    error = msg
                }
            }
        }
        .navigationTitle(conversation.displayName(currentUserId: myId))
        .navigationBarTitleDisplayMode(.inline)
        .eqNavAppearance()
        .task {
            await vm.loadMessages(conversationId: conversation.id)
            vm.startPolling(conversationId: conversation.id)
        }
        .onDisappear { vm.stopPolling() }
    }
}

// MARK: - Messages List
// Separate struct — only re-renders when messages array changes, never during typing.

private struct MessagesList: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: EQSpacing.sm) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, EQSpacing.md)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Input Bar
// Owns messageText as @State — typing only re-renders this view, not the message list.

private struct ChatInputBar: View {
    let onSend: (String) async throws -> Void
    let onError: (String) -> Void

    @State private var text = ""
    @State private var isSending = false

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: EQSpacing.sm) {
            TextField("Message…", text: $text, axis: .vertical)
                .font(.body)
                .foregroundStyle(Color.eqDarkBrown)
                .padding(.horizontal, EQSpacing.md)
                .padding(.vertical, 10)
                .background(Color.eqCream)
                .clipShape(RoundedRectangle(cornerRadius: EQRadius.pill, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EQRadius.pill, style: .continuous)
                        .strokeBorder(Color.eqLightTan, lineWidth: 1)
                )
                .lineLimit(4)

            Button {
                Task { await send() }
            } label: {
                ZStack {
                    Circle()
                        .fill(isEmpty ? AnyShapeStyle(Color.eqLightTan) : AnyShapeStyle(LinearGradient.eqHero))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(isEmpty || isSending)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, EQSpacing.sm)
        .background(Color.eqWarmWhite)
    }

    private func send() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        HapticFeedback.impact(.medium)
        text = ""
        isSending = true
        do {
            try await onSend(content)
            HapticFeedback.success()
        } catch {
            text = content  // restore on failure
            onError(error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isSending = false
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: Message
    @Environment(AuthManager.self) private var auth

    private var isFromMe: Bool {
        message.sender_id == (auth.user?.id ?? "")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: EQSpacing.sm) {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                if let content = message.content {
                    Text(content)
                        .font(.body)
                        .foregroundStyle(isFromMe ? .white : Color.eqDarkBrown)
                        .padding(.horizontal, EQSpacing.md)
                        .padding(.vertical, EQSpacing.sm)
                        .background(
                            isFromMe
                                ? AnyShapeStyle(LinearGradient.eqHero)
                                : AnyShapeStyle(Color.eqCream)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous))
                        .overlay(
                            !isFromMe ? RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                                .strokeBorder(Color.eqLightTan, lineWidth: 1) : nil
                        )
                }
                if let date = message.created_date {
                    Text(date.toDisplayDate(format: "h:mm a"))
                        .font(.caption2)
                        .foregroundStyle(Color.eqMuted)
                }
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
    }
}
