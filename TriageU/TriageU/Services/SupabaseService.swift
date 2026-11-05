import Foundation
import SwiftData

struct ActivityDTO: Codable {
    let id: UUID
    var title: String
    var subject: String
    var type: String
    var dueDate: Date
    var hasDueTime: Bool
    var weightPercent: Int?
    var preparation: Int
    var durationMin: Int
    var priority: String
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, subject, type, preparation, priority, completed
        case dueDate = "due_date"
        case hasDueTime = "has_due_time"
        case weightPercent = "weight_percent"
        case durationMin = "duration_min"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SubjectDTO: Codable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case colorHex = "color_hex"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Cliente mínimo de Supabase (PostgREST). Las escrituras pasan por `SyncQueue`.
enum SupabaseService {

    enum Table: String, Codable { case activities, subjects }

    // MARK: - Codificación

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Fecha inválida: \(s)")
            )
        }
        return d
    }()

    // MARK: - IDs ya sincronizados (para propagar borrados entre dispositivos)

    private static func syncedKey(_ t: Table, _ userId: String) -> String {
        "triageu.synced.\(t.rawValue).\(userId)"
    }

    @MainActor
    private static func syncedIds(_ t: Table) -> Set<UUID> {
        guard let uid = AuthManager.shared.session?.userId else { return [] }
        let raw = UserDefaults.standard.stringArray(forKey: syncedKey(t, uid)) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    @MainActor
    private static func setSyncedIds(_ t: Table, _ ids: Set<UUID>) {
        guard let uid = AuthManager.shared.session?.userId else { return }
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: syncedKey(t, uid))
    }

    @MainActor
    static func markSynced(_ t: Table, id: UUID, synced: Bool) {
        var ids = syncedIds(t)
        if synced { ids.insert(id) } else { ids.remove(id) }
        setSyncedIds(t, ids)
    }

    // MARK: - HTTP

    private static func request(
        table: Table,
        method: String,
        token: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) -> URLRequest {
        var comps = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(table.rawValue)"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = query.isEmpty ? nil : query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        req.timeoutInterval = 20
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        extraHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return req
    }

    private static func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Supabase", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return data
    }

    private static func token() async throws -> String {
        guard SupabaseConfig.isConfigured, let t = await AuthManager.shared.validToken() else {
            throw NSError(domain: "Supabase", code: 401)
        }
        return t
    }

    // MARK: - Operaciones remotas (lanzan error si fallan)

    static func push<T: Encodable>(_ dto: T, table: Table) async throws {
        let req = request(
            table: table, method: "POST", token: try await token(),
            body: try encoder.encode(dto),
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=minimal"]
        )
        _ = try await send(req)
    }

    static func deleteRemote(table: Table, id: UUID) async throws {
        let req = request(
            table: table, method: "DELETE", token: try await token(),
            query: [.init(name: "id", value: "eq.\(id.uuidString.lowercased())")]
        )
        _ = try await send(req)
    }

    static func fetch<T: Decodable>(_ type: T.Type, table: Table) async throws -> [T] {
        let req = request(
            table: table, method: "GET", token: try await token(),
            query: [.init(name: "select", value: "*")]
        )
        return try decoder.decode([T].self, from: try await send(req))
    }

    // MARK: - DTO <-> modelo

    @MainActor
    static func dto(for a: TriageActivity) -> ActivityDTO {
        ActivityDTO(
            id: a.id, title: a.title, subject: a.subject, type: a.type,
            dueDate: a.dueDate, hasDueTime: a.hasDueTime, weightPercent: a.weightPercent,
            preparation: a.preparation, durationMin: a.durationMin, priority: a.priority,
            completed: a.completed, createdAt: a.createdAt, updatedAt: a.updatedAt
        )
    }

    @MainActor
    static func dto(for s: Subject) -> SubjectDTO {
        SubjectDTO(id: s.id, name: s.name, colorHex: s.colorHex,
                   createdAt: s.createdAt, updatedAt: s.updatedAt)
    }

    // MARK: - API usada por la app (encola; nunca falla)

    @MainActor static func upsert(_ activity: TriageActivity) async {
        SyncQueue.shared.enqueue(.activities, id: activity.id, op: .upsert)
    }

    @MainActor static func delete(id: UUID) async {
        SyncQueue.shared.enqueue(.activities, id: id, op: .delete)
    }

    @MainActor static func upsert(_ subject: Subject) async {
        SyncQueue.shared.enqueue(.subjects, id: subject.id, op: .upsert)
    }

    @MainActor static func deleteSubject(id: UUID) async {
        SyncQueue.shared.enqueue(.subjects, id: id, op: .delete)
    }

    // MARK: - Sincronización completa

    /// Última escritura gana (`updated_at`). Devuelve false si no se pudo contactar al servidor.
    @MainActor
    @discardableResult
    static func sync(context: ModelContext) async -> Bool {
        guard SupabaseConfig.isConfigured, AuthManager.shared.isSignedIn else { return false }
        SyncQueue.shared.context = context
        await SyncQueue.shared.flush()

        guard let remoteSubjects = try? await fetch(SubjectDTO.self, table: .subjects),
              let remoteActivities = try? await fetch(ActivityDTO.self, table: .activities)
        else { return false }

        syncSubjects(remoteSubjects, context: context)
        syncActivities(remoteActivities, context: context)
        try? context.save()
        await SyncQueue.shared.flush()
        return true
    }

    private static let tolerance: TimeInterval = 1   // la nube guarda otra precisión

    @MainActor
    private static func syncActivities(_ remote: [ActivityDTO], context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<TriageActivity>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let remoteIds = Set(remote.map(\.id))
        let known = syncedIds(.activities)
        let queue = SyncQueue.shared

        var changed: [TriageActivity] = []

        for dto in remote {
            if queue.hasPendingDelete(.activities, id: dto.id) { continue }   // no resucitar
            if let existing = localById[dto.id] {
                let delta = dto.updatedAt.timeIntervalSince(existing.updatedAt)
                if delta > tolerance {
                    apply(dto, to: existing)
                    changed.append(existing)
                } else if delta < -tolerance {
                    queue.enqueue(.activities, id: existing.id, op: .upsert)
                }
            } else {
                let a = TriageActivity(
                    title: dto.title, subject: dto.subject, type: dto.type,
                    dueDate: dto.dueDate, weightPercent: dto.weightPercent,
                    preparation: dto.preparation, durationMin: dto.durationMin,
                    priority: dto.priority, completed: dto.completed,
                    hasDueTime: dto.hasDueTime
                )
                a.id = dto.id
                a.createdAt = dto.createdAt
                a.updatedAt = dto.updatedAt
                context.insert(a)
                changed.append(a)
            }
        }

        for a in local where !remoteIds.contains(a.id) {
            if known.contains(a.id) {
                NotificationService.cancel(id: a.id)
                context.delete(a)
            } else {
                queue.enqueue(.activities, id: a.id, op: .upsert)
            }
        }

        setSyncedIds(.activities, remoteIds)
        Task { for a in changed { await NotificationService.schedule(for: a) } }
    }

    @MainActor
    private static func syncSubjects(_ remote: [SubjectDTO], context: ModelContext) {
        let local = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let remoteIds = Set(remote.map(\.id))
        let known = syncedIds(.subjects)
        let queue = SyncQueue.shared

        for dto in remote {
            if queue.hasPendingDelete(.subjects, id: dto.id) { continue }
            if let existing = localById[dto.id] {
                let delta = dto.updatedAt.timeIntervalSince(existing.updatedAt)
                if delta > tolerance {
                    existing.name = dto.name
                    existing.colorHex = dto.colorHex
                    existing.updatedAt = dto.updatedAt
                } else if delta < -tolerance {
                    queue.enqueue(.subjects, id: existing.id, op: .upsert)
                }
            } else {
                let s = Subject(id: dto.id, name: dto.name, colorHex: dto.colorHex)
                s.createdAt = dto.createdAt
                s.updatedAt = dto.updatedAt
                context.insert(s)
            }
        }

        for s in local where !remoteIds.contains(s.id) {
            if known.contains(s.id) {
                context.delete(s)
            } else {
                queue.enqueue(.subjects, id: s.id, op: .upsert)
            }
        }
        setSyncedIds(.subjects, remoteIds)
    }

    @MainActor
    private static func apply(_ dto: ActivityDTO, to a: TriageActivity) {
        a.title = dto.title
        a.subject = dto.subject
        a.type = dto.type
        a.dueDate = dto.dueDate
        a.hasDueTime = dto.hasDueTime
        a.weightPercent = dto.weightPercent
        a.preparation = dto.preparation
        a.durationMin = dto.durationMin
        a.priority = dto.priority
        a.completed = dto.completed
        a.updatedAt = dto.updatedAt
    }

    /// Crea las materias iniciales una sola vez por usuario (o en modo local).
    @MainActor
    static func seedSubjectsIfNeeded(context: ModelContext, serverReachable: Bool) {
        let userKey = AuthManager.shared.session?.userId ?? "local"
        let flag = "triageu.subjectsSeeded.\(userKey)"
        if SupabaseConfig.isConfigured && AuthManager.shared.isSignedIn && !serverReachable { return }
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        if existing.isEmpty {
            for d in SubjectDefaults.all {
                let s = Subject(id: d.id, name: d.name, colorHex: d.colorHex)
                context.insert(s)
                SyncQueue.shared.enqueue(.subjects, id: s.id, op: .upsert)
            }
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    /// Borra todo lo local (al cerrar sesión).
    @MainActor
    static func wipeLocal(context: ModelContext) {
        try? context.delete(model: TriageActivity.self)
        try? context.delete(model: Subject.self)
        try? context.save()
    }
}
