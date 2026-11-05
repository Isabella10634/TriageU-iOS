import SwiftUI
import SwiftData

@main
struct TriageUApp: App {

    init() {
        NotificationService.configure()
    }

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

    private let auth = AuthManager.shared

    /// Sin credenciales de Supabase la app funciona solo en local, sin login.
    private var needsLogin: Bool {
        SupabaseConfig.isConfigured && !auth.isSignedIn
    }

    var body: some View {
        Group {
            if needsLogin {
                AuthView()
            } else {
                ContentView()
            }
        }
        .task(id: auth.session?.userId) {
            await NotificationService.requestAuthorization()

            if auth.isSignedIn {
                await SupabaseService.sync(context: modelContext)
            }
            let all = (try? modelContext.fetch(FetchDescriptor<TriageActivity>())) ?? []
            await NotificationService.rescheduleAll(all)
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            // Al cerrar sesión se limpia el caché local para no mezclar cuentas.
            if !signedIn && SupabaseConfig.isConfigured {
                NotificationService.cancelAll()
                SupabaseService.wipeLocal(context: modelContext)
            }
        }
    }
}
