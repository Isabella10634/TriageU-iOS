import Foundation
import Observation

/// Autenticación con Supabase Auth (correo + contraseña) vía REST.
@MainActor
@Observable
final class AuthManager {

    static let shared = AuthManager()

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userId: String
        var email: String
    }

    private(set) var session: Session?
    var isLoading = false
    var errorMessage: String?
    var infoMessage: String?

    var isSignedIn: Bool { session != nil }

    private let keychainKey = "session"

    private init() {
        if let data = Keychain.load(key: keychainKey),
           let saved = try? JSONDecoder().decode(Session.self, from: data) {
            session = saved
        }
    }

    // MARK: - Acciones públicas

    func signIn(email: String, password: String) async {
        await authenticate(path: "token?grant_type=password", email: email, password: password)
    }

    func signUp(email: String, password: String) async {
        await authenticate(path: "signup", email: email, password: password)
    }

    func signOut() {
        session = nil
        Keychain.delete(key: keychainKey)
    }

    /// Devuelve un access token vigente (renovándolo si hace falta).
    func validToken() async -> String? {
        guard let current = session else { return nil }
        if current.expiresAt.timeIntervalSinceNow > 60 { return current.accessToken }
        return await refresh(current)
    }

    // MARK: - Internos

    private struct TokenResponse: Decodable {
        struct User: Decodable { let id: String; let email: String? }
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Int?
        let user: User?
    }

    private struct ErrorResponse: Decodable {
        let msg: String?
        let message: String?
        let errorDescription: String?
    }

    private func post(_ path: String, body: [String: String]) async throws -> (Data, Int) {
        var req = URLRequest(url: URL(string: SupabaseConfig.url.absoluteString + "/auth/v1/" + path)!)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func authenticate(path: String, email: String, password: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, password.count >= 6 else {
            errorMessage = "Escribe tu correo y una contraseña de al menos 6 caracteres."
            return
        }
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            let (data, status) = try await post(path, body: ["email": cleanEmail, "password": password])
            guard (200..<300).contains(status) else {
                let err = try? decoder().decode(ErrorResponse.self, from: data)
                errorMessage = Self.translate(err?.msg ?? err?.message ?? err?.errorDescription)
                return
            }
            let res = try decoder().decode(TokenResponse.self, from: data)
            guard let access = res.accessToken, let refresh = res.refreshToken, let user = res.user else {
                infoMessage = "Cuenta creada. Revisa tu correo para confirmarla y luego inicia sesión."
                return
            }
            store(Session(
                accessToken: access,
                refreshToken: refresh,
                expiresAt: Date().addingTimeInterval(TimeInterval(res.expiresIn ?? 3600)),
                userId: user.id,
                email: user.email ?? cleanEmail
            ))
        } catch {
            errorMessage = "No se pudo conectar. Revisa tu conexión."
        }
    }

    private func refresh(_ current: Session) async -> String? {
        do {
            let (data, status) = try await post(
                "token?grant_type=refresh_token",
                body: ["refresh_token": current.refreshToken]
            )
            guard (200..<300).contains(status) else {
                // Refresh token inválido: sesión caducada.
                if status == 400 || status == 401 || status == 403 { signOut() }
                return nil
            }
            let res = try decoder().decode(TokenResponse.self, from: data)
            guard let access = res.accessToken, let refresh = res.refreshToken else { return nil }
            var updated = current
            updated.accessToken = access
            updated.refreshToken = refresh
            updated.expiresAt = Date().addingTimeInterval(TimeInterval(res.expiresIn ?? 3600))
            store(updated)
            return access
        } catch {
            // Sin red: usa el token actual por si aún sirve.
            return current.accessToken
        }
    }

    private func store(_ new: Session) {
        session = new
        if let data = try? JSONEncoder().encode(new) {
            Keychain.save(data, key: keychainKey)
        }
    }

    private static func translate(_ message: String?) -> String {
        guard let m = message?.lowercased() else { return "Ocurrió un error. Inténtalo de nuevo." }
        if m.contains("invalid login") { return "Correo o contraseña incorrectos." }
        if m.contains("already registered") { return "Ese correo ya tiene una cuenta." }
        if m.contains("not confirmed") { return "Confirma tu correo antes de iniciar sesión." }
        if m.contains("password") { return "La contraseña debe tener al menos 6 caracteres." }
        return message ?? "Ocurrió un error."
    }
}
