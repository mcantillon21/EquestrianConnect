import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    var id: String
    var participants: [String]
    var horse_id: String?
    var last_message: String?
    var last_message_date: String?
    var unread_count: Int?
    var created_date: String?
    var other_name: String?  // resolved locally after profile lookup; never sent to/from server

    private enum CodingKeys: String, CodingKey {
        case id, participants, horse_id, last_message, last_message_date, unread_count, created_date
    }

    func otherParticipant(currentUserId: String) -> String {
        participants.first(where: { $0 != currentUserId }) ?? participants.first ?? ""
    }

    func displayName(currentUserId: String) -> String {
        other_name ?? otherParticipant(currentUserId: currentUserId)
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Message: Codable, Identifiable, Hashable {
    var id: String
    var conversation_id: String
    var sender_id: String
    var recipient_id: String?
    var content: String?
    var video_url: String?
    var horse_id: String?
    var created_date: String?

    static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
