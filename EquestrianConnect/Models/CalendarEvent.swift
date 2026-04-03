import Foundation

struct CalendarEvent: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var type: String           // horse_show | vet_appointment | farrier | training | lesson | other
    var start_date: String
    var end_date: String?
    var all_day: Bool?
    var location: String?
    var description: String?
    var horse_ids: [String]?
    var user_id: String?
    var is_recurring: Bool?
    var recurrence_frequency: String?  // daily | weekly | monthly | yearly
    var recurrence_count: Int?
    var recurrence_parent_id: String?
    var created_date: String?

    var startDate: Date? { start_date.toDate() }

    static let eventTypes: [(value: String, label: String)] = [
        ("horse_show",       "Horse Show"),
        ("vet_appointment",  "Vet Appointment"),
        ("farrier",          "Farrier"),
        ("training",         "Training"),
        ("lesson",           "Lesson"),
        ("other",            "Other")
    ]

    static let recurrenceOptions: [(value: String, label: String)] = [
        ("daily",   "Daily"),
        ("weekly",  "Weekly"),
        ("monthly", "Monthly"),
        ("yearly",  "Yearly")
    ]

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Training Log

struct TrainingLog: Codable, Identifiable, Hashable {
    var id: String
    var horse_id: String
    var date: String           // yyyy-MM-dd
    var user_id: String?
    var created_date: String?

    static func == (lhs: TrainingLog, rhs: TrainingLog) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
