import Foundation

struct User: Codable, Identifiable, Hashable {
    var id: String
    var email: String
    var full_name: String?
    var user_type: String?  // "owner" | "trainer"
    var profile_image: String?
    var trainer_code: String?   // trainers: unique 6-char code owners use to connect
    var trainer_id: String?     // owners: their trainer's user ID
    var created_date: String?

    var displayName: String { full_name ?? email }
    var firstName: String { full_name?.components(separatedBy: " ").first ?? full_name ?? email.components(separatedBy: "@").first ?? email }
    var isOwner: Bool  { user_type == "owner" }
    var isTrainer: Bool { user_type == "trainer" }
    var hasRole: Bool { user_type != nil && !user_type!.isEmpty }

    static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
