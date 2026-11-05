import Foundation
import SwiftData

/// Cliente mínimo de Supabase (PostgREST) sin dependencias externas.
/// SwiftData es la caché local; Supabase es la copia remota por usuario (RLS).
struct ActivityDTO: Codable {
    let id: UUID
    var title: String
    var subject: String
    var type: String
    var dueDate: Date
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
        case weightPercent = "weight_percent"
        case durationMin = "duration_min"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum SupabaseService {

    private static let table = "activities"

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

    private static func syncedKey(_ userId: String) -> String { "triageu.synced.\(userId)" }

    @MainActor
    private static func syncedIds() -> Set<UUID> {
        guard let uid = AuthManager.shared.session?.userId else { return [] }
        let raw = UserDefaults.standard.stringArray(forKey: syncedKey(uid)) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    @MainActor
    private static func setSyncedIds(_ ids: Set<UUID>) {
        guard let uid = AuthManager.shared.session?.userId else { return }
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: syncedKey(uid))
    }

    // MARK: - HTTP

    private static func request(
        method: String,
        token: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) -> URLRequest {
        var comps = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = query.isEmpty ? nil : query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
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

    // MARK: - Operaciones

    @discardableResult
    static func upsert(_ activity: TriageActivity) async -> Bool {
        guard SupabaseConfig.isConfigured, let token = await AuthManager.shared.validToken() else { return false }
        let dto = ActivityDTO(
            id: activity.id, title: activity.title,
            subject: activity.subject, type: activity.type, dueDate: activity.dueDate,
            weightPercent: activity.weightPercent, preparation: activity.preparation,
            durationMin: activity.durationMin, priority: activity.priority,
            completed: activity.completed, createdAt: activity.createdAt,
            updatedAt: activity.updatedAt
        )
        do {
            let req = request(
                method: "POST", token: token, body: try encoder.encode(dto),
                extraHeaders: ["Prefer": "resolution=merge-duplicates,return=minimal"]
            )
            _ = try await send(req)
            await MainActor.run { setSyncedIds(syncedIds().union([dto.id])) }
            return true
        } catch {
            print("Supabase upsert error:", error.localizedDescription)
            return false
        }
    }

    static func delete(id: UUID) async {
        guard SupabaseConfig.isConfigured, let token = await AuthManager.shared.validToken() else { return }
        do {
            let req = request(
                method: "DELETE", token: token,
                query: [.init(name: "id", value: "eq.\(id.uuidString.lowercased())")]
            )
            _ = try await send(req)
            await MainActor.run { setSyncedIds(syncedIds().subtracting([id])) }
        } catch {
            print("Supabase delete error:", error.localizedDescription)
        }
    }

    /// nil = error de red/servidor (no tocar datos locales).
    static func fetchAll() async -> [ActivityDTO]? {
        guard SupabaseConfig.isConfigured, let token = await AuthManager.shared.validToken() else { return nil }
        do {
            let req = request(method: "GET", token: token, query: [.init(name: "select", value: "*")])
            return try decoder.decode([ActivityDTO].self, from: try await send(req))
        } catch {
            print("Supabase fetch error:", error.localizedDescription)
            return nil
        }
    }

    /// Mezcla remoto y local (última escritura gana, por `updated_at`):
    /// - remoto que no está en local → se crea localmente
    /// - ambos existen → gana el más reciente (se aplica o se sube)
    /// - local que estaba sincronizado y ya no está en remoto → se borró en otro dispositivo
    /// - local nuevo → se sube
    @MainActor
    static func sync(context: ModelContext) async {
        guard SupabaseConfig.isConfigured, AuthManager.shared.isSignedIn,
              let remote = await fetchAll() else { return }

        let local = (try? context.fetch(FetchDescriptor<TriageActivity>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let remoteIds = Set(remote.map(\.id))
        let known = syncedIds()
        let tolerance: TimeInterval = 1   // la nube guarda menos precisión que Date

        var toUpload: [TriageActivity] = []
        var changed: [TriageActivity] = []

        for dto in remote {
            if let existing = localById[dto.id] {
                let delta = dto.updatedAt.timeIntervalSince(existing.updatedAt)
                if delta > tolerance {
                    apply(dto, to: existing)
                    changed.append(existing)
                } else if delta < -tolerance {
                    toUpload.append(existing)
                }
            } else {
                let a = TriageActivity(
                    title: dto.title, subject: dto.subject, type: dto.type,
                    dueDate: dto.dueDate, weightPercent: dto.weightPercent,
                    preparation: dto.preparation, durationMin: dto.durationMin,
                    priority: dto.priority, completed: dto.completed
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
                toUpload.append(a)
            }
        }
        try? context.save()

        setSyncedIds(remoteIds)
        for a in toUpload { await upsert(a) }
        for a in changed { await NotificationService.schedule(for: a) }
    }

    @MainActor
    private static func apply(_ dto: ActivityDTO, to a: TriageActivity) {
        a.title = dto.title
        a.subject = dto.subject
        a.type = dto.type
        a.dueDate = dto.dueDate
        a.weightPercent = dto.weightPercent
        a.preparation = dto.preparation
        a.durationMin = dto.durationMin
        a.priority = dto.priority
        a.completed = dto.completed
        a.updatedAt = dto.updatedAt
    }

    /// Borra todo lo local (al cerrar sesión).
    @MainActor
    static func wipeLocal(context: ModelContext) {
        try? context.delete(model: TriageActivity.self)
        try? context.save()
    }
}
