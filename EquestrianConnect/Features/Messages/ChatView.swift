import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let vm: MessagesViewModel
    @Environment(AuthManager.self) private var auth
    @State private var messageText = ""
    @State private var isSending = false
    @State private var error: String?

    private var myEmail: String { auth.user?.email ?? "" }
    private var otherEmail: String { conversation.otherParticipant(currentEmail: myEmail) }
    private var messages: [Message] { vm.messages[conversation.id] ?? [] }

    var body: some View {
        ZStack {
            Color.eqWarmWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                if let err = error {
                    ErrorBanner(message: err) { error = nil }
                }

                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: EQSpacing.sm) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromMe: message.sender_email == myEmail
                                )
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

                // Input Bar
                EQDivider()
                inputBar
            }
        }
        .navigationTitle(otherEmail)
        .navigationBarTitleDisplayMode(.inline)
        .eqNavAppearance()
        .task {
            await vm.loadMessages(conversationId: conversation.id)
            vm.startPolling(conversationId: conversation.id)
        }
        .onDisappear { vm.stopPolling() }
    }

    private var inputBar: some View {
        HStack(spacing: EQSpacing.sm) {
            TextField("Message…", text: $messageText, axis: .vertical)
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
                send()
            } label: {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? AnyShapeStyle(Color.eqLightTan) : AnyShapeStyle(LinearGradient.eqHero))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, EQSpacing.md)
        .padding(.vertical, EQSpacing.sm)
        .background(Color.eqWarmWhite)
    }

    private func send() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        HapticFeedback.impact(.medium)
        messageText = ""
        isSending = true
        Task {
            do {
                try await vm.sendMessage(
                    conversationId: conversation.id,
                    content: content,
                    senderEmail: myEmail,
                    recipientEmail: otherEmail
                )
                HapticFeedback.success()
            } catch {
                self.error = error.localizedDescription
                messageText = content  // restore on failure
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isSending = false
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: Message
    let isFromMe: Bool

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
                        .clipShape(
                            RoundedRectangle(cornerRadius: EQRadius.md, style: .continuous)
                        )
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
