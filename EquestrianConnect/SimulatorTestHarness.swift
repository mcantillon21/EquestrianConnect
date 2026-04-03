#if targetEnvironment(simulator)
import SwiftUI

// MARK: - Test Harness
// Set `currentScreen` to a screen key, rebuild, and screenshot.
// Set to "" to run the normal app.

struct SimulatorTestHarness: View {
    static var currentScreen: String = ""

    // MARK: Mock Data

    static let horse = Horse(
        id: "test-h1",
        name: "Midnight Star",
        barn_name: "Midnight",
        breed: "Thoroughbred",
        color: "Bay",
        date_of_birth: "2019-04-15",
        gender: "mare",
        registration_number: "USEF-123456",
        discipline: "Dressage",
        owner_id: "preview-owner",
        total_earnings: 45250
    )

    static let event = CalendarEvent(
        id: "test-e1",
        title: "Farrier Visit",
        type: "farrier",
        start_date: "2026-03-16T17:00:00-07:00",
        end_date: "2026-03-16T18:00:00-07:00",
        all_day: false,
        location: "Rolling Hills Barn",
        description: "Routine shoeing for Midnight Star and Golden Arrow.",
        horse_ids: ["test-h1"],
        user_id: "preview-owner"
    )

    static let conversation = Conversation(
        id: "test-c1",
        participants: ["preview-owner", "sarah-id"],
        last_message: "See you Thursday at 9am! Midnight is looking great.",
        last_message_date: "2026-03-15",
        unread_count: 2
    )

    // MARK: Body

    var body: some View {
        let auth = AuthManager()
        switch Self.currentScreen {
        case "horse_profile":
            NavigationStack {
                HorseProfileView(horse: Self.horse, vm: HorsesViewModel())
            }
            .environment(auth)
        case "horse_form":
            HorseFormView(vm: HorsesViewModel())
                .environment(auth)
        case "event_detail":
            EventDetailView(event: Self.event, vm: CalendarViewModel())
                .environment(auth)
        case "event_form":
            EventFormView(vm: CalendarViewModel(), defaultDate: Date())
                .environment(auth)
        case "chat":
            NavigationStack {
                ChatView(conversation: Self.conversation, vm: preloadedMessagesVM())
            }
            .environment(auth)
        case "marketplace":
            NavigationStack { MarketplaceView() }
                .environment(auth)
        case "feed":
            NavigationStack { FeedView() }
                .environment(auth)
        case "profile":
            NavigationStack { ProfileView() }
                .environment(auth)
        default:
            Text("Unknown screen: \(Self.currentScreen)")
        }
    }

    private func preloadedMessagesVM() -> MessagesViewModel {
        let vm = MessagesViewModel()
        let msgs = [
            Message(id: "m1", conversation_id: "test-c1", sender_id: "sarah-id", content: "How is Midnight doing?", created_date: "2026-03-15T08:00:00-07:00"),
            Message(id: "m2", conversation_id: "test-c1", sender_id: "preview-owner", content: "She's doing great! Ready for Thursday.", created_date: "2026-03-15T08:05:00-07:00"),
            Message(id: "m3", conversation_id: "test-c1", sender_id: "sarah-id", content: "See you Thursday at 9am! Midnight is looking great.", created_date: "2026-03-15T08:10:00-07:00")
        ]
        vm.messages["test-c1"] = msgs
        return vm
    }
}
#endif
