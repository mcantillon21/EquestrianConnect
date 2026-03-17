import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    var id: String
    var participants: [String]
    var horse_id: String?
    var last_message: String?
    var last_message_date: String?
    var unread_count: Int?
    var created_date: String?

    func otherParticipant(currentEmail: String) -> String {
        participants.first(where: { $0 != currentEmail }) ?? participants.first ?? ""
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Message: Codable, Identifiable, Hashable {
    var id: String
    var conversation_id: String
    var sender_email: String
    var recipient_email: String?
    var content: String?
    var video_url: String?
    var horse_id: String?
    var created_date: String?

    static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
