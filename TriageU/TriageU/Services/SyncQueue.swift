import Foundation
import Network
import Observation
import SwiftData

/// Cola persistente de cambios pendientes de subir a Supabase.
/// Los cambios se guardan en disco, se reintentan al volver la red, al abrir
/// la app y cada 30 s mientras haya pendientes.
@MainActor
@Observable
final class SyncQueue {

    static let shared = SyncQueue()

    enum Op: String, Codable { case upsert, delete }

    struct Item: Codable, Equatable {
        var table: SupabaseService.Table
        var id: UUID
        var op: Op
        var userId: String
        var attempts: Int = 0
        var queuedAt: Date = Date()
    }

    private(set) var items: [Item] = []
    private(set) var isFlushing = false
    var context: ModelContext?

    private let storageKey = "triageu.syncQueue"
    private let monitor = NWPathMonitor()
    private var retryTask: Task<Void, Never>?

    var pendingCount: Int {
        guard let uid = AuthManager.shared.session?.userId else { return 0 }
        return items.filter { $0.userId == uid }.count
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = saved
        }
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task { @MainActor in await SyncQueue.shared.flush() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "triageu.network"))
    }

    // MARK: - API

    func enqueue(_ table: SupabaseService.Table, id: UUID, op: Op) {
        guard SupabaseConfig.isConfigured,
              let uid = AuthManager.shared.session?.userId else { return }
        items.removeAll { $0.table == table && $0.id == id && $0.userId == uid }
        items.append(Item(table: table, id: id, op: op, userId: uid))
        persist()
        Task { await flush() }
    }

    func hasPendingDelete(_ table: SupabaseService.Table, id: UUID) -> Bool {
        items.contains { $0.table == table && $0.id == id && $0.op == .delete }
    }

    func clear() {
        items = []
        persist()
    }

    func flush() async {
        guard SupabaseConfig.isConfigured,
              let uid = AuthManager.shared.session?.userId,
              context != nil, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        for item in items where item.userId == uid {
            do {
                try await process(item)
                remove(item)
            } catch let error as NSError {
                if error.domain == NSURLErrorDomain { break }          // sin red
                if error.domain == "Supabase" {
                    if error.code == 401 { break }                      // sesión por renovar
                    if (400..<500).contains(error.code), ![408, 429].contains(error.code) {
                        remove(item)                                    // dato inválido: no reintentar
                        continue
                    }
                }
                bump(item)
            }
        }
        persist()
        scheduleRetryIfNeeded()
    }

    // MARK: - Internos

    private func process(_ item: Item) async throws {
        switch item.op {
        case .delete:
            try await SupabaseService.deleteRemote(table: item.table, id: item.id)
            SupabaseService.markSynced(item.table, id: item.id, synced: false)

        case .upsert:
            switch item.table {
            case .activities:
                guard let a = fetchActivity(item.id) else { return }
                try await SupabaseService.push(SupabaseService.dto(for: a), table: .activities)
            case .subjects:
                guard let s = fetchSubject(item.id) else { return }
                try await SupabaseService.push(SupabaseService.dto(for: s), table: .subjects)
            }
            SupabaseService.markSynced(item.table, id: item.id, synced: true)
        }
    }

    private func fetchActivity(_ id: UUID) -> TriageActivity? {
        let d = FetchDescriptor<TriageActivity>(predicate: #Predicate { $0.id == id })
        return try? context?.fetch(d).first
    }

    private func fetchSubject(_ id: UUID) -> Subject? {
        let d = FetchDescriptor<Subject>(predicate: #Predicate { $0.id == id })
        return try? context?.fetch(d).first
    }

    /// Solo quita el elemento si no fue reemplazado por un cambio más nuevo.
    private func remove(_ item: Item) {
        items.removeAll {
            $0.table == item.table && $0.id == item.id && $0.queuedAt == item.queuedAt
        }
    }

    private func bump(_ item: Item) {
        guard let i = items.firstIndex(where: {
            $0.table == item.table && $0.id == item.id && $0.queuedAt == item.queuedAt
        }) else { return }
        items[i].attempts += 1
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func scheduleRetryIfNeeded() {
        guard pendingCount > 0, retryTask == nil else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self else { return }
            self.retryTask = nil
            await self.flush()
        }
    }
}
