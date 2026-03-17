import SwiftUI

@main
struct EquestrianApp: App {
    @State private var auth = AuthManager()

    init() {
        // Eliminate the ~300ms scroll-view touch delay that makes buttons
        // feel sluggish. iOS holds touches inside UIScrollView to disambiguate
        // scroll vs tap — disabling this makes taps register on the first frame.
        UIScrollView.appearance().delaysContentTouches = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
        }
    }
}
