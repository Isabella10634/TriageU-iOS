import SwiftUI
import SwiftData

@main
struct TriageUApp: App {

    var body: some Scene {

        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: TriageActivity.self
        )
    }
}
