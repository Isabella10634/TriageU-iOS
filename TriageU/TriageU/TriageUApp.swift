import SwiftUI
import SwiftData

@main
struct TriageUApp: App {

    var body: some Scene {

        WindowGroup {
            SyncRoot()
        }
        .modelContainer(
            for: TriageActivity.self
        )
    }
}

private struct SyncRoot: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .task { await SupabaseService.sync(context: modelContext) }
    }
}
