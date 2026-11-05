import Foundation
import SwiftData

/// Cliente mínimo de Supabase (PostgREST) sin dependencias externas.
/// SwiftData sigue siendo la caché local; Supabase es la copia remota.
struct ActivityDTO: Codable {
    let id: UUID
    let deviceId: String
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

    enum CodingKeys: String, CodingKey {
        case id, title, subject, type, preparation, priority, completed
        case deviceId = "device_id"
        case dueDate = "due_date"
        case weightPercent = "weight_percent"
        case durationMin = "duration_min"
        case createdAt = "created_at"
    }
}

enum SupabaseService {

    /// Identificador anónimo por instalación (sin login).
    static let deviceId: String = {
        let key = "triageu.deviceId"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    private static let table = "activities"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
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

    private static func request(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) throws -> URLRequest {
        var comps = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("rest/v1/\(path)"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = query.isEmpty ? nil : query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
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

    static func upsert(_ activity: TriageActivity) async {
        guard SupabaseConfig.isConfigured else { return }
        let dto = ActivityDTO(
            id: activity.id, deviceId: deviceId, title: activity.title,
            subject: activity.subject, type: activity.type, dueDate: activity.dueDate,
            weightPercent: activity.weightPercent, preparation: activity.preparation,
            durationMin: activity.durationMin, priority: activity.priority,
            completed: activity.completed, createdAt: activity.createdAt
        )
        do {
            let body = try encoder.encode(dto)
            let req = try request(
                path: table, method: "POST", body: body,
                extraHeaders: ["Prefer": "resolution=merge-duplicates,return=minimal"]
            )
            _ = try await send(req)
        } catch {
            print("Supabase upsert error:", error.localizedDescription)
        }
    }

    static func delete(id: UUID) async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            let req = try request(
                path: table, method: "DELETE",
                query: [
                    .init(name: "id", value: "eq.\(id.uuidString.lowercased())"),
                    .init(name: "device_id", value: "eq.\(deviceId)")
                ]
            )
            _ = try await send(req)
        } catch {
            print("Supabase delete error:", error.localizedDescription)
        }
    }

    static func fetchAll() async -> [ActivityDTO] {
        guard SupabaseConfig.isConfigured else { return [] }
        do {
            let req = try request(
                path: table, method: "GET",
                query: [
                    .init(name: "select", value: "*"),
                    .init(name: "device_id", value: "eq.\(deviceId)")
                ]
            )
            return try decoder.decode([ActivityDTO].self, from: try await send(req))
        } catch {
            print("Supabase fetch error:", error.localizedDescription)
            return []
        }
    }

    /// Descarga lo remoto y lo mezcla en SwiftData; sube lo local que falte.
    @MainActor
    static func sync(context: ModelContext) async {
        guard SupabaseConfig.isConfigured else { return }
        let remote = await fetchAll()
        let local = (try? context.fetch(FetchDescriptor<TriageActivity>())) ?? []
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let remoteIds = Set(remote.map(\.id))

        for dto in remote where localById[dto.id] == nil {
            let a = TriageActivity(
                title: dto.title, subject: dto.subject, type: dto.type,
                dueDate: dto.dueDate, weightPercent: dto.weightPercent,
                preparation: dto.preparation, durationMin: dto.durationMin,
                priority: dto.priority, completed: dto.completed
            )
            a.id = dto.id
            a.createdAt = dto.createdAt
            context.insert(a)
        }
        try? context.save()

        for a in local where !remoteIds.contains(a.id) {
            await upsert(a)
        }
    }
}
