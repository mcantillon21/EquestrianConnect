import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var horses: [Horse] = []
    var upcomingEvents: [CalendarEvent] = []
    var recentConversations: [Conversation] = []
    var isLoading = false
    var error: String?

    private let client = Base44Client.shared

    func load(userEmail: String) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock(isTrainer: false) }
        return
        #endif
        await MainActor.run { isLoading = true; error = nil }
        async let horsesTask: [Horse] = try client.filter(
            entity: "Horse",
            query: ["owner_email": userEmail],
            sort: "name",
            limit: 50
        )
        async let eventsTask: [CalendarEvent] = try client.filter(
            entity: "CalendarEvent",
            query: ["user_email": userEmail],
            sort: "start_date",
            limit: 10
        )
        async let convsTask: [Conversation] = try client.list(
            entity: "Conversation",
            sort: "-last_message_date",
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

    func loadTrainer(trainerEmail: String) async {
        #if targetEnvironment(simulator)
        await MainActor.run { loadSimulatorMock(isTrainer: true) }
        return
        #endif
        await MainActor.run { isLoading = true; error = nil }
        async let horsesTask: [Horse] = try client.filter(
            entity: "Horse",
            query: ["trainer_email": trainerEmail],
            sort: "name",
            limit: 50
        )
        async let eventsTask: [CalendarEvent] = try client.filter(
            entity: "CalendarEvent",
            query: ["user_email": trainerEmail],
            sort: "start_date",
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

    // MARK: - Simulator Mock

    #if targetEnvironment(simulator)
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

        let imgMidnight = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Applebite-Gentlemen.jpg/400px-Applebite-Gentlemen.jpg"
        let imgArrow = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Mare_and_foal_%28Kvetina-Marie%29.jpg/400px-Mare_and_foal_%28Kvetina-Marie%29.jpg"
        let imgStorm = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/WCLV07m.JPG/400px-WCLV07m.JPG"
        let imgRuby = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Halterstandingshotarabianone.jpg/400px-Halterstandingshotarabianone.jpg"

        if isTrainer {
            horses = [
                Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                      breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                      gender: "mare", registration_number: nil, discipline: "Dressage",
                      owner_email: "jordan@eq.app", trainer_email: "preview@eq.app",
                      profile_image: imgMidnight, total_earnings: nil, created_date: nil),
                Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                      breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                      gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                      owner_email: "sarah@eq.app", trainer_email: "preview@eq.app",
                      profile_image: imgArrow, total_earnings: nil, created_date: nil),
                Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                      breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                      gender: "stallion", registration_number: nil, discipline: "Jumping",
                      owner_email: "mike@eq.app", trainer_email: "preview@eq.app",
                      profile_image: imgStorm, total_earnings: nil, created_date: nil),
                Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                      breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                      gender: "mare", registration_number: nil, discipline: "Endurance",
                      owner_email: "lisa@eq.app", trainer_email: "preview@eq.app",
                      profile_image: imgRuby, total_earnings: nil, created_date: nil),
            ]
        } else {
            horses = [
                Horse(id: "h1", name: "Midnight Star", barn_name: "Midnight",
                      breed: "Thoroughbred", color: "Black", date_of_birth: "2018-04-15",
                      gender: "mare", registration_number: nil, discipline: "Dressage",
                      owner_email: "preview@eq.app", trainer_email: nil,
                      profile_image: imgMidnight, total_earnings: nil, created_date: nil),
                Horse(id: "h2", name: "Golden Arrow", barn_name: "Arrow",
                      breed: "Quarter Horse", color: "Palomino", date_of_birth: "2015-07-22",
                      gender: "gelding", registration_number: nil, discipline: "Western Pleasure",
                      owner_email: "preview@eq.app", trainer_email: nil,
                      profile_image: imgArrow, total_earnings: nil, created_date: nil),
                Horse(id: "h3", name: "Storm Chaser", barn_name: nil,
                      breed: "Warmblood", color: "Dapple Grey", date_of_birth: "2019-01-10",
                      gender: "stallion", registration_number: nil, discipline: "Jumping",
                      owner_email: "preview@eq.app", trainer_email: nil,
                      profile_image: imgStorm, total_earnings: nil, created_date: nil),
                Horse(id: "h4", name: "Ruby Red", barn_name: "Ruby",
                      breed: "Arabian", color: "Chestnut", date_of_birth: "2017-09-03",
                      gender: "mare", registration_number: nil, discipline: "Endurance",
                      owner_email: "preview@eq.app", trainer_email: nil,
                      profile_image: imgRuby, total_earnings: nil, created_date: nil),
            ]
        }

        upcomingEvents = [
            CalendarEvent(id: "e1", title: "Farrier Visit", type: "farrier",
                          start_date: future(1), end_date: nil, all_day: false,
                          location: "Rolling Hills Barn", description: nil,
                          horse_ids: ["h1", "h2"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e2", title: "Dressage Lesson", type: "lesson",
                          start_date: future(3), end_date: nil, all_day: false,
                          location: "Arena B", description: nil,
                          horse_ids: ["h1"], user_email: "preview@eq.app",
                          is_recurring: true, recurrence_frequency: "weekly",
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e4", title: "Vet Check-Up — Storm", type: "vet_appointment",
                          start_date: future(7), end_date: nil, all_day: false,
                          location: "On-site", description: nil,
                          horse_ids: ["h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e5", title: "Spring Horse Show", type: "horse_show",
                          start_date: future(12), end_date: nil, all_day: true,
                          location: "County Equestrian Center", description: nil,
                          horse_ids: ["h1", "h2", "h3"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
            CalendarEvent(id: "e6", title: "50-Mile Endurance Ride", type: "horse_show",
                          start_date: future(21), end_date: nil, all_day: true,
                          location: "Pine Ridge Trail", description: nil,
                          horse_ids: ["h4"], user_email: "preview@eq.app",
                          is_recurring: false, recurrence_frequency: nil,
                          recurrence_count: nil, recurrence_parent_id: nil, created_date: nil),
        ]

        recentConversations = [
            Conversation(id: "c1",
                         participants: ["preview@eq.app", "sarah.trainer@barn.com"],
                         horse_id: nil, last_message: "See you Thursday at 9am!",
                         last_message_date: past(2),
                         unread_count: 2, created_date: nil),
            Conversation(id: "c2",
                         participants: ["preview@eq.app", "dr.miller@vetclinic.com"],
                         horse_id: "h3", last_message: "Storm's bloodwork came back clean",
                         last_message_date: past(20),
                         unread_count: 0, created_date: nil),
            Conversation(id: "c3",
                         participants: ["preview@eq.app", "mike.barn@rollinghills.com"],
                         horse_id: nil, last_message: "Hay delivery confirmed for Friday",
                         last_message_date: past(48),
                         unread_count: 0, created_date: nil),
        ]

        isLoading = false
    }
    #endif
}
