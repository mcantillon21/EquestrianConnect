import Foundation

struct Post: Codable, Identifiable, Hashable {
    var id: String
    var author_email: String?
    var author_name: String?
    var caption: String?
    var media_type: String?    // photo | video
    var media_url: String?
    var horse_id: String?
    var horse_name: String?
    var tags: [String]?
    var for_sale: Bool?
    var price: Double?
    var location: String?
    var created_date: String?
    var like_count: Int?
    var comment_count: Int?

    static func == (lhs: Post, rhs: Post) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Like: Codable, Identifiable, Hashable {
    var id: String
    var post_id: String
    var user_email: String?
    var created_date: String?

    static func == (lhs: Like, rhs: Like) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
