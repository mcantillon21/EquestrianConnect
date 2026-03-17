import Foundation
import Observation

@Observable
final class CalendarViewModel {
    var events: [CalendarEvent] = []
    var selectedDate: Date = Date()
    var isLoading = false
    var error: String?

    var eventsForSelectedDate: [CalendarEvent] {
        let cal = Calendar.current
        return events.filter {
            guard let d = $0.start_date.toDate() else { return false }
            return cal.isDate(d, inSameDayAs: selectedDate)
        }
        .sorted { ($0.start_date.toDate() ?? Date()) < ($1.start_date.toDate() ?? Date()) }
    }

    var eventDates: Set<String> {
        Set(events.compactMap { $0.start_date.toDate()?.iso8601DateString })
    }

    private let client = Base44Client.shared

    func load(userEmail: String) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock() }
        return
        #endif
        await MainActor.run { isLoading = true; error = nil }
        do {
            let fetched: [CalendarEvent] = try await client.filter(
                entity: "CalendarEvent",
                query: ["user_email": userEmail],
                sort: "start_date",
                limit: 200
            )
            await MainActor.run { events = fetched; isLoading = false }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    #if targetEnvironment(simulator)
    @MainActor
    private func loadSimulatorMock() {
        let cal = Calendar.current
        let now = Date()
        func future(_ days: Int, hour: Int = 10, minute: Int = 0) -> String {
            var comps = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: days, to: now)!)
            comps.hour = hour; comps.minute = minute
            return cal.date(from: comps)!.iso8601String
        }
        func past(_ days: Int, hour: Int = 9, minute: Int = 0) -> String {
            var comps = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: -days, to: now)!)
            comps.hour = hour; comps.minute = minute
            return cal.date(from: comps)!.iso8601String
        }
        events = [
            // ── Past events (populate calendar history) ──
            CalendarEvent(id: "e_p1", title: "Dressage Lesson", type: "lesson",
                          start_date: past(4, hour: 8), end_date: nil, all_day: false,
                          location: "Arena B", description: "Lateral movements and half-pass",
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e_p2", title: "Jumping Clinic", type: "lesson",
                          start_date: past(6, hour: 14), end_date: nil, all_day: false,
                          location: "Arena A", description: "Grid work and course practice",
                          horse_ids: ["h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e_p3", title: "Training Session", type: "training",
                          start_date: past(3, hour: 7), end_date: nil, all_day: false,
                          location: "Main Arena", description: nil,
                          horse_ids: ["h2"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "daily",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e_p4", title: "Vet — Annual Vaccines", type: "vet_appointment",
                          start_date: past(10, hour: 10), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: "Flu, rhino, tetanus",
                          horse_ids: ["h1", "h2"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e_p5", title: "Winter Schooling Show", type: "horse_show",
                          start_date: past(14), end_date: nil, all_day: true,
                          location: "Meadowbrook Equestrian Center", description: nil,
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),

            // ── Today ──
            CalendarEvent(id: "e_t1", title: "Morning Training", type: "training",
                          start_date: future(0, hour: 7), end_date: nil, all_day: false,
                          location: "Main Arena", description: nil,
                          horse_ids: ["h2"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "daily",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),

            // ── Upcoming ──
            CalendarEvent(id: "e1", title: "Farrier Visit", type: "farrier",
                          start_date: future(1, hour: 9), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: "Full reset — Midnight, Arrow, and Ruby",
                          horse_ids: ["h1", "h2", "h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e2", title: "Dressage Lesson", type: "lesson",
                          start_date: future(3, hour: 8), end_date: nil, all_day: false,
                          location: "Arena B", description: "Focus on collected canter and flying changes",
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e3", title: "Trail Conditioning Ride", type: "training",
                          start_date: future(5, hour: 6, minute: 30), end_date: nil, all_day: false,
                          location: "Pine Ridge Trail", description: "20-mile conditioning for endurance season",
                          horse_ids: ["h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e4", title: "Vet Check-Up — Storm", type: "vet_appointment",
                          start_date: future(7, hour: 11), end_date: nil, all_day: false,
                          location: "On-site", description: "Annual wellness exam and joint evaluation",
                          horse_ids: ["h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e5", title: "Jumping Clinic", type: "lesson",
                          start_date: future(8, hour: 14), end_date: nil, all_day: false,
                          location: "Arena A", description: "1.0m and 1.10m course work",
                          horse_ids: ["h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e6", title: "Spring Horse Show", type: "horse_show",
                          start_date: future(12), end_date: nil, all_day: true,
                          location: "County Equestrian Center", description: "Classes: Prix St. Georges, 1.0m Open, Western Pleasure",
                          horse_ids: ["h1", "h2", "h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e7", title: "Dressage Lesson", type: "lesson",
                          start_date: future(10, hour: 8), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e8", title: "Farrier — Storm & Ruby", type: "farrier",
                          start_date: future(18, hour: 9), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: nil,
                          horse_ids: ["h3", "h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e9", title: "50-Mile Endurance Ride", type: "horse_show",
                          start_date: future(21), end_date: nil, all_day: true,
                          location: "Pine Ridge Endurance Park", description: "Sanctioned AERC ride",
                          horse_ids: ["h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e10", title: "Dressage Lesson", type: "lesson",
                          start_date: future(17, hour: 8), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e11", title: "Annual Vaccinations", type: "vet_appointment",
                          start_date: future(28, hour: 10), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: "EHV, flu, tetanus — all four horses",
                          horse_ids: ["h1", "h2", "h3", "h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e12", title: "Western Pleasure Show", type: "horse_show",
                          start_date: future(35), end_date: nil, all_day: true,
                          location: "Sundown Arena", description: nil,
                          horse_ids: ["h2"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
        ]
        isLoading = false
    }
    #endif

    @MainActor
    func createEvent(_ event: CalendarEvent) async throws {
        let created: CalendarEvent = try await client.create(entity: "CalendarEvent", data: event)
        events.append(created)
        events.sort { ($0.start_date.toDate() ?? Date()) < ($1.start_date.toDate() ?? Date()) }
    }

    @MainActor
    func updateEvent(_ event: CalendarEvent) async throws {
        let updated: CalendarEvent = try await client.update(entity: "CalendarEvent", id: event.id, data: event)
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = updated
        }
    }

    @MainActor
    func deleteEvent(_ event: CalendarEvent) async throws {
        try await client.delete(entity: "CalendarEvent", id: event.id)
        events.removeAll { $0.id == event.id }
    }
}
