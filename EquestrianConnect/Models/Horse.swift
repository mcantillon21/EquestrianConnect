import Foundation

struct Horse: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var barn_name: String?
    var breed: String?
    var color: String?
    var date_of_birth: String?
    var gender: String?            // stallion | mare | gelding
    var registration_number: String?
    var discipline: String?
    var owner_id: String?
    var trainer_id: String?
    var owner_ids: [String]?
    var trainer_ids: [String]?
    var profile_image: String?
    var total_earnings: Double?
    var created_date: String?

    var allOwnerIds: [String] {
        var result = owner_ids ?? []
        if let oid = owner_id, !oid.isEmpty, !result.contains(oid) { result.insert(oid, at: 0) }
        return result
    }
    var allTrainerIds: [String] {
        var result = trainer_ids ?? []
        if let tid = trainer_id, !tid.isEmpty, !result.contains(tid) { result.insert(tid, at: 0) }
        return result
    }

    var displayName: String { barn_name ?? name }
    var age: Int? {
        guard let dob = date_of_birth?.toDate() else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    var ageString: String { age.map { "\($0)y" } ?? "—" }
    var genderLabel: String {
        switch gender {
        case "stallion": return "Stallion"
        case "mare":     return "Mare"
        case "gelding":  return "Gelding"
        default:         return gender?.capitalized ?? "—"
        }
    }

    static func == (lhs: Horse, rhs: Horse) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Disciplines

extension Horse {
    static let disciplines = [
        "Cutting", "Cow Horse", "Dressage", "Jumping", "Eventing", "Western Pleasure", "Reining",
        "Trail", "Endurance", "Barrel Racing", "Polo", "Hunter", "Other"
    ]
    static let genders: [(value: String, label: String)] = [
        ("stallion", "Stallion"), ("mare", "Mare"), ("gelding", "Gelding")
    ]
    static let commonBreeds = [
        "Thoroughbred", "Quarter Horse", "Warmblood", "Arabian", "Appaloosa",
        "Paint", "Morgan", "Andalusian", "Friesian", "Tennessee Walker", "Other"
    ]
}
