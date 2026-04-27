import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var horses: [Horse] = []
    var upcomingEvents: [CalendarEvent] = []
    var recentConversations: [Conversation] = []
    var isLoading = false
    var error: String?

    private let client = SupabaseClient.shared

    func load(userId: String) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock(isTrainer: false) }
        return
        #endif
        if isDemoMode {
            await MainActor.run { loadSimulatorMock(isTrainer: false) }
            return
        }
        await MainActor.run { isLoading = true; error = nil }
        async let horsesTask: [Horse] = try client.filter(
            table: "horses",
            query: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")],
            order: "name.asc",
            limit: 50
        )
        async let eventsTask: [CalendarEvent] = try client.filter(
            table: "calendar_events",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userId)")],
            order: "start_date.asc",
            limit: 10
        )
        async let convsTask: [Conversation] = try client.list(
            table: "conversations",
            order: "last_message_date.desc",
            limit: 5
        )
        do {
            let (h, e, c) = try await (horsesTask, eventsTask, convsTask)
            let now = Date()
            let upcoming = e.filter {
                guard let d = $0.start_date.toDate() else { return false }
                return d >= now
            }
            await MainActor.run {
                horses = h
                upcomingEvents = upcoming
                recentConversations = c
                isLoading = false
            }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    func loadTrainer(trainerId: String) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock(isTrainer: true) }
        return
        #endif
        if isDemoMode {
            await MainActor.run { loadSimulatorMock(isTrainer: true) }
            return
        }
        await MainActor.run { isLoading = true; error = nil }
        async let horsesTask: [Horse] = try client.filter(
            table: "horses",
            query: [URLQueryItem(name: "trainer_id", value: "eq.\(trainerId)")],
            order: "name.asc",
            limit: 50
        )
        async let eventsTask: [CalendarEvent] = try client.filter(
            table: "calendar_events",
            query: [URLQueryItem(name: "user_id", value: "eq.\(trainerId)")],
            order: "start_date.asc",
            limit: 10
        )
        do {
            let (h, e) = try await (horsesTask, eventsTask)
            let now = Date()
            let upcoming = e.filter {
                guard let d = $0.start_date.toDate() else { return false }
                return d >= now
            }
            await MainActor.run {
                horses = h
                upcomingEvents = upcoming
                isLoading = false
            }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run { self.error = desc; isLoading = false }
        }
    }

    // MARK: - Demo / Simulator Mock

    @MainActor
    private func loadSimulatorMock(isTrainer: Bool) {
        let cal = Calendar.current
        let now = Date()
        func future(_ days: Int) -> String {
            cal.date(byAdding: .day, value: days, to: now)!.iso8601DateString
        }
        func past(_ hours: Int) -> String {
            cal.date(byAdding: .hour, value: -hours, to: now)!.iso8601DateString
        }

        let imgMidnight = "https://images.unsplash.com/photo-1670212433014-b2435aca06a4?w=400&fit=crop"
        let imgArrow = "https://images.unsplash.com/photo-1517326451550-8612522c096e?w=400&fit=crop"
        let imgStorm = "https://images.unsplash.com/photo-1641226469021-f81abb75108c?w=400&fit=crop"
        let imgRuby = "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=400&fit=crop"

        if isTrainer {
            horses = [
                Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                      breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                      gender: "mare", registration_number: nil, discipline: "Dressage",
                      owner_id: "jordan-id", trainer_id: "preview-trainer",
                      profile_image: imgMidnight, total_earnings: nil, created_date: nil),
                Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                      breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                      gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                      owner_id: "sarah-id", trainer_id: "preview-trainer",
                      profile_image: imgArrow, total_earnings: nil, created_date: nil),
                Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                      breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                      gender: "stallion", registration_number: nil, discipline: "Jumping",
                      owner_id: "mike-id", trainer_id: "preview-trainer",
                      profile_image: imgStorm, total_earnings: nil, created_date: nil),
                Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                      breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                      gender: "mare", registration_number: nil, discipline: "Endurance",
                      owner_id: "lisa-id", trainer_id: "preview-trainer",
                      profile_image: imgRuby, total_earnings: nil, created_date: nil),
            ]
        } else {
            horses = [
                Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                      breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                      gender: "mare", registration_number: nil, discipline: "Dressage",
                      owner_id: "preview-owner", trainer_id: nil,
                      profile_image: imgMidnight, total_earnings: nil, created_date: nil),
                Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                      breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                      gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                      owner_id: "preview-owner", trainer_id: nil,
                      profile_image: imgArrow, total_earnings: nil, created_date: nil),
                Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                      breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                      gender: "stallion", registration_number: nil, discipline: "Jumping",
                      owner_id: "preview-owner", trainer_id: nil,
                      profile_image: imgStorm, total_earnings: nil, created_date: nil),
                Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                      breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                      gender: "mare", registration_number: nil, discipline: "Endurance",
                      owner_id: "preview-owner", trainer_id: nil,
                      profile_image: imgRuby, total_earnings: nil, created_date: nil),
            ]
        }

        upcomingEvents = [
            CalendarEvent(id: "e1", title: "Farrier Visit", type: "farrier",
                          start_date: future(1), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: nil,
                          horse_ids: ["h1", "h2"], user_id: "preview-owner",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e2", title: "Dressage Lesson", type: "lesson",
                          start_date: future(3), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_id: "preview-owner",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e4", title: "Vet Check-Up — Storm", type: "vet_appointment",
                          start_date: future(7), end_date: nil, all_day: false,
                          location: "On-site", description: nil,
                          horse_ids: ["h3"], user_id: "preview-owner",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e5", title: "Spring Horse Show", type: "horse_show",
                          start_date: future(12), end_date: nil, all_day: true,
                          location: "County Equestrian Center", description: nil,
                          horse_ids: ["h1", "h2", "h3"], user_id: "preview-owner",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e6", title: "50-Mile Endurance Ride", type: "horse_show",
                          start_date: future(21), end_date: nil, all_day: true,
                          location: "Pine Ridge Trail", description: nil,
                          horse_ids: ["h4"], user_id: "preview-owner",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
        ]

        if isTrainer {
            recentConversations = [
                Conversation(id: "c1",
                             participants: ["preview-trainer", "jordan-id"],
                             horse_id: "h1", last_message: "How did Midnight do in her lesson?",
                             last_message_date: past(1),
                             unread_count: 2, created_date: nil),
                Conversation(id: "c2",
                             participants: ["preview-trainer", "sarah-id"],
                             horse_id: "h2", last_message: "Arrow is ready for the show!",
                             last_message_date: past(5),
                             unread_count: 1, created_date: nil),
                Conversation(id: "c3",
                             participants: ["preview-trainer", "mike-id"],
                             horse_id: "h3", last_message: "Can we reschedule Tuesday's session?",
                             last_message_date: past(24),
                             unread_count: 0, created_date: nil),
            ]
        } else {
            recentConversations = [
                Conversation(id: "c1",
                             participants: ["preview-owner", "trainer-id"],
                             horse_id: nil, last_message: "See you Thursday at 9am!",
                             last_message_date: past(2),
                             unread_count: 2, created_date: nil),
                Conversation(id: "c2",
                             participants: ["preview-owner", "vet-id"],
                             horse_id: "h3", last_message: "Storm's bloodwork came back clean",
                             last_message_date: past(20),
                             unread_count: 0, created_date: nil),
                Conversation(id: "c3",
                             participants: ["preview-owner", "barn-id"],
                             horse_id: nil, last_message: "Hay delivery confirmed for Friday",
                             last_message_date: past(48),
                             unread_count: 0, created_date: nil),
            ]
        }

        isLoading = false
    }
}
