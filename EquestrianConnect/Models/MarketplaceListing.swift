import Foundation

struct MarketplaceListing: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var type: String           // horse | tack | equipment | trailer | other
    var price: Double?
    var price_negotiable: Bool?
    var description: String?
    var images: [String]?
    var videos: [String]?
    var location: String?
    var seller_email: String?
    var seller_name: String?
    var seller_phone: String?
    var status: String?        // active | sold | pending
    var breed: String?
    var age: Int?
    var gender: String?
    var discipline: String?
    var height: String?
    var featured: Bool?
    var created_date: String?

    var firstImage: String? { images?.first }
    var priceString: String {
        if let p = price { return p.currencyString }
        return "Price on request"
    }

    static let listingTypes: [(value: String, label: String)] = [
        ("horse",     "Horse"),
        ("tack",      "Tack"),
        ("equipment", "Equipment"),
        ("trailer",   "Trailer"),
        ("other",     "Other")
    ]

    static func == (lhs: MarketplaceListing, rhs: MarketplaceListing) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
