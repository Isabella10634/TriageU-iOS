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
            for: [TriageActivity.self, Subject.self]
        )
    }
}

private struct SyncRoot: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var activities: [TriageActivity]
    @Query private var subjects: [Subject]

    private let auth = AuthManager.shared

    /// Sin credenciales de Supabase la app funciona solo en local, sin login.
    private var needsLogin: Bool {
        SupabaseConfig.isConfigured && !auth.isSignedIn
    }

    /// Cambia cuando algo relevante para el widget cambia.
    private var widgetSignature: [String] {
        activities.map { "\($0.id)|\($0.updatedAt.timeIntervalSince1970)|\($0.completed)" }
        + subjects.map { "\($0.id)|\($0.updatedAt.timeIntervalSince1970)" }
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
            SyncQueue.shared.context = modelContext
            await NotificationService.requestAuthorization()

            let reachable = await SupabaseService.sync(context: modelContext)
            SupabaseService.seedSubjectsIfNeeded(context: modelContext, serverReachable: reachable)

            let all = (try? modelContext.fetch(FetchDescriptor<TriageActivity>())) ?? []
            await NotificationService.rescheduleAll(all)
            WidgetBridge.update(activities: all, subjects: subjects)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SupabaseService.sync(context: modelContext) }
            }
        }
        .onChange(of: widgetSignature) {
            WidgetBridge.update(activities: activities, subjects: subjects)
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            // Al cerrar sesión se limpia el caché local para no mezclar cuentas.
            if !signedIn && SupabaseConfig.isConfigured {
                NotificationService.cancelAll()
                SyncQueue.shared.clear()
                SupabaseService.wipeLocal(context: modelContext)
                WidgetBridge.clear()
            }
        }
    }
}
