import Foundation
import Observation

@Observable
final class MessagesViewModel {
    var conversations: [Conversation] = []
    var messages: [String: [Message]] = [:]  // keyed by conversation_id
    var isLoading = false
    var error: String?

    private let client = Base44Client.shared
    private var pollingTask: Task<Void, Never>?

    @MainActor
    func loadConversations() async {
        #if targetEnvironment(simulator)
        loadSimulatorMock()
        return
        #endif
        if isDemoMode {
            loadSimulatorMock()
            return
        }
        isLoading = true
        error = nil
        do {
            conversations = try await client.list(
                entity: "Conversation",
                sort: "-last_message_date",
                limit: 50
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func loadSimulatorMock() {
        let cal = Calendar.current
        let now = Date()
        func past(_ hours: Int) -> String {
            cal.date(byAdding: .hour, value: -hours, to: now)!.iso8601String
        }
        conversations = [
            Conversation(id: "c1",
                         participants: ["preview@eq.app", "Sarah Johnson"],
                         horse_id: "h1",
                         last_message: "See you Thursday at 9am! Midnight looked great yesterday.",
                         last_message_date: past(2),
                         unread_count: 2, created_date: nil),
            Conversation(id: "c2",
                         participants: ["preview@eq.app", "Dr. Miller"],
                         horse_id: "h3",
                         last_message: "Storm's bloodwork came back completely clean.",
                         last_message_date: past(20),
                         unread_count: 0, created_date: nil),
            Conversation(id: "c3",
                         participants: ["preview@eq.app", "Mike Thompson"],
                         horse_id: nil,
                         last_message: "Hay delivery confirmed for Friday morning.",
                         last_message_date: past(48),
                         unread_count: 0, created_date: nil),
        ]
        messages["c1"] = [
            Message(id: "m1", conversation_id: "c1", sender_email: "Sarah Johnson",
                    recipient_email: "preview@eq.app",
                    content: "Hi! How did Midnight feel after last week's show?",
                    video_url: nil, horse_id: "h1", created_date: past(72)),
            Message(id: "m2", conversation_id: "c1", sender_email: "preview@eq.app",
                    recipient_email: "Sarah Johnson",
                    content: "She was a little stiff the first day but back to normal by Wednesday.",
                    video_url: nil, horse_id: "h1", created_date: past(70)),
            Message(id: "m3", conversation_id: "c1", sender_email: "Sarah Johnson",
                    recipient_email: "preview@eq.app",
                    content: "That's totally normal after a show weekend. I'd ice her legs tonight.",
                    video_url: nil, horse_id: "h1", created_date: past(68)),
            Message(id: "m4", conversation_id: "c1", sender_email: "preview@eq.app",
                    recipient_email: "Sarah Johnson",
                    content: "Will do! Are we still on for the lateral work Thursday?",
                    video_url: nil, horse_id: "h1", created_date: past(6)),
            Message(id: "m5", conversation_id: "c1", sender_email: "Sarah Johnson",
                    recipient_email: "preview@eq.app",
                    content: "Yes! I want to work on the half-pass. See you Thursday at 9am — Midnight looked great yesterday.",
                    video_url: nil, horse_id: "h1", created_date: past(2)),
        ]
        messages["c2"] = [
            Message(id: "m6", conversation_id: "c2", sender_email: "preview@eq.app",
                    recipient_email: "Dr. Miller",
                    content: "Hi Dr. Miller, just checking in on Storm's bloodwork from last week.",
                    video_url: nil, horse_id: "h3", created_date: past(96)),
            Message(id: "m7", conversation_id: "c2", sender_email: "Dr. Miller",
                    recipient_email: "preview@eq.app",
                    content: "Results are in! Everything looks excellent — iron, CBC, and metabolic panel all normal.",
                    video_url: nil, horse_id: "h3", created_date: past(72)),
            Message(id: "m8", conversation_id: "c2", sender_email: "Dr. Miller",
                    recipient_email: "preview@eq.app",
                    content: "Storm's bloodwork came back completely clean. He's in great shape for the spring season.",
                    video_url: nil, horse_id: "h3", created_date: past(20)),
        ]
        messages["c3"] = [
            Message(id: "m9", conversation_id: "c3", sender_email: "preview@eq.app",
                    recipient_email: "Mike Thompson",
                    content: "Hey Mike, can we get an extra 10 bales of timothy this week? Ruby is going through it fast.",
                    video_url: nil, horse_id: nil, created_date: past(72)),
            Message(id: "m10", conversation_id: "c3", sender_email: "Mike Thompson",
                    recipient_email: "preview@eq.app",
                    content: "No problem. I'll add it to the order. Timothy or orchard grass mix?",
                    video_url: nil, horse_id: nil, created_date: past(70)),
            Message(id: "m11", conversation_id: "c3", sender_email: "preview@eq.app",
                    recipient_email: "Mike Thompson",
                    content: "Timothy please. Thanks!",
                    video_url: nil, horse_id: nil, created_date: past(69)),
            Message(id: "m12", conversation_id: "c3", sender_email: "Mike Thompson",
                    recipient_email: "preview@eq.app",
                    content: "Hay delivery confirmed for Friday morning.",
                    video_url: nil, horse_id: nil, created_date: past(48)),
        ]
        isLoading = false
    }

    func loadMessages(conversationId: String) async {
        do {
            let msgs: [Message] = try await client.filter(
                entity: "Message",
                query: ["conversation_id": conversationId],
                sort: "created_date",
                limit: 100
            )
            await MainActor.run { messages[conversationId] = msgs }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc }
        }
    }

    @MainActor
    func sendMessage(conversationId: String, content: String, senderEmail: String, recipientEmail: String) async throws {
        let msg = Message(
            id: UUID().uuidString,
            conversation_id: conversationId,
            sender_email: senderEmail,
            recipient_email: recipientEmail,
            content: content,
            created_date: Date().iso8601String
        )
        let created: Message = try await client.create(entity: "Message", data: msg)
        messages[conversationId, default: []].append(created)

        // Update conversation's last message
        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[idx].last_message = content
            conversations[idx].last_message_date = Date().iso8601String
        }
    }

    @MainActor
    func startConversation(with otherEmail: String, currentEmail: String, horseId: String? = nil) async throws -> Conversation {
        // Check if conversation already exists
        if let existing = conversations.first(where: {
            $0.participants.contains(currentEmail) && $0.participants.contains(otherEmail)
        }) {
            return existing
        }
        let conv = Conversation(
            id: UUID().uuidString,
            participants: [currentEmail, otherEmail],
            horse_id: horseId
        )
        let created: Conversation = try await client.create(entity: "Conversation", data: conv)
        conversations.insert(created, at: 0)
        return created
    }

    func startPolling(conversationId: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                guard !Task.isCancelled else { break }
                await loadMessages(conversationId: conversationId)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
