import Foundation

struct EarningEntry: Codable, Identifiable, Hashable {
    var id: String
    var horse_id: String
    var amount: Double
    var title: String
    var category: String?
    var date: String          // yyyy-MM-dd
    var notes: String?
    var created_date: String?

    static let categories = [
        "Show / Competition",
        "Prize Money",
        "Lesson Fee",
        "Training Fee",
        "Breeding Fee",
        "Sale",
        "Other"
    ]

    var categoryIcon: String {
        switch category {
        case "Show / Competition", "Prize Money": return "trophy.fill"
        case "Lesson Fee", "Training Fee":        return "figure.equestrian.sports"
        case "Breeding Fee":                       return "heart.fill"
        case "Sale":                               return "tag.fill"
        default:                                   return "dollarsign.circle.fill"
        }
    }
}
