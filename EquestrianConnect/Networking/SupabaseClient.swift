import Foundation

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case unauthorized
    case notFound
    case httpError(statusCode: Int, message: String?)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .notFound:
            return "The requested item was not found."
        case .httpError(_, let msg):
            return msg ?? "An error occurred. Please try again."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .decodingError(let e):
            return "Data error: \(e.localizedDescription)"
        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

// MARK: - Auth Response Types

struct AuthResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let user: AuthUser?
}

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

struct EmptyResponse: Decodable {}

// MARK: - Supabase Client

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let projectRef: String
    private let anonKey: String

    private var baseURL: String { "https://\(projectRef).supabase.co" }
    private var restURL: String { "\(baseURL)/rest/v1" }
    private var authURL: String { "\(baseURL)/auth/v1" }
    private var storageURL: String { "\(baseURL)/storage/v1" }

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let ref = (info["SupabaseProjectRef"] as? String) ?? ""
        let key = (info["SupabaseAnonKey"] as? String) ?? ""
        if ref.isEmpty || ref.hasPrefix("$(") || key.isEmpty || key.hasPrefix("$(") {
            fatalError("""
            Missing Supabase config. Copy Config/Supabase.xcconfig.example to \
            Config/Supabase.xcconfig, fill in SUPABASE_PROJECT_REF and \
            SUPABASE_ANON_KEY, then rebuild.
            """)
        }
        self.projectRef = ref
        self.anonKey = key
    }

    // MARK: - Token Management

    private var _cachedToken: String?

    var accessToken: String? {
        get {
            if let cached = _cachedToken { return cached }
            let value = KeychainHelper.shared.get(key: "supabase_access_token")
            _cachedToken = value
            return value
        }
        set {
            _cachedToken = newValue
            if let v = newValue {
                KeychainHelper.shared.set(key: "supabase_access_token", value: v)
            } else {
                KeychainHelper.shared.delete(key: "supabase_access_token")
            }
        }
    }

    var refreshToken: String? {
        get { KeychainHelper.shared.get(key: "supabase_refresh_token") }
        set {
            if let v = newValue {
                KeychainHelper.shared.set(key: "supabase_refresh_token", value: v)
            } else {
                KeychainHelper.shared.delete(key: "supabase_refresh_token")
            }
        }
    }

    // MARK: - Decoder

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Auth: Magic Link (OTP)

    /// Send a magic link / OTP to the user's email
    func signInWithOtp(email: String) async throws {
        var req = URLRequest(url: URL(string: "\(authURL)/otp")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data)
            throw SupabaseError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: msg ?? "Failed to send magic link"
            )
        }
    }

    /// Verify the OTP code sent to email
    func verifyOtp(email: String, token: String) async throws -> AuthResponse {
        struct Body: Encodable { let email: String; let token: String; let type: String }
        var req = URLRequest(url: URL(string: "\(authURL)/verify")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(Body(email: email, token: token, type: "email"))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data)
            throw SupabaseError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: msg ?? "Invalid verification code"
            )
        }
        return try Self.decoder.decode(AuthResponse.self, from: data)
    }

    /// Get the current user from the access token
    func getAuthUser() async throws -> AuthUser {
        guard let token = accessToken else { throw SupabaseError.unauthorized }
        var req = URLRequest(url: URL(string: "\(authURL)/user")!)
        req.httpMethod = "GET"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.unauthorized
        }
        return try Self.decoder.decode(AuthUser.self, from: data)
    }

    /// Refresh the session using the refresh token
    func refreshSession() async throws -> AuthResponse {
        guard let rt = refreshToken else { throw SupabaseError.unauthorized }
        var req = URLRequest(url: URL(string: "\(authURL)/token?grant_type=refresh_token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["refresh_token": rt])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.unauthorized
        }
        let auth = try Self.decoder.decode(AuthResponse.self, from: data)
        if let at = auth.access_token { accessToken = at }
        if let rt = auth.refresh_token { refreshToken = rt }
        return auth
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: - REST Helpers

    private var restHeaders: [String: String] {
        var h: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
        if let t = accessToken { h["Authorization"] = "Bearer \(t)" }
        return h
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        struct APIError: Decodable {
            let message: String?
            let msg: String?
            let error_description: String?
        }
        guard let e = try? JSONDecoder().decode(APIError.self, from: data) else { return nil }
        return e.message ?? e.msg ?? e.error_description
    }

    // MARK: - Generic REST Request

    private func restRequest<T: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        var components = URLComponents(string: "\(restURL)/\(path)")!
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let url = components.url else { throw SupabaseError.unknown }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        for (k, v) in restHeaders { req.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.unknown }

        switch http.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw SupabaseError.unauthorized
        case 404, 406:
            throw SupabaseError.notFound
        default:
            let msg = Self.extractErrorMessage(from: data)
            throw SupabaseError.httpError(statusCode: http.statusCode, message: msg)
        }

        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }

        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw SupabaseError.decodingError(underlying: error)
        }
    }

    // MARK: - CRUD Operations

    /// List all rows from a table, with optional ordering and limit.
    func list<T: Decodable>(
        table: String,
        order: String? = nil,
        limit: Int? = nil,
        extraQuery: [URLQueryItem] = []
    ) async throws -> [T] {
        var qi = extraQuery
        if let order { qi.append(URLQueryItem(name: "order", value: order)) }
        if let limit { qi.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await restRequest(method: "GET", path: table, queryItems: qi)
    }

    /// Filter rows using PostgREST query parameters.
    func filter<T: Decodable>(
        table: String,
        query: [URLQueryItem],
        order: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        var qi = query
        if let order { qi.append(URLQueryItem(name: "order", value: order)) }
        if let limit { qi.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await restRequest(method: "GET", path: table, queryItems: qi)
    }

    /// Get a single row by ID.
    func get<T: Decodable>(table: String, id: String) async throws -> T {
        let qi = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let results: [T] = try await restRequest(
            method: "GET", path: table, queryItems: qi,
            extraHeaders: ["Accept": "application/json"]
        )
        guard let first = results.first else { throw SupabaseError.notFound }
        return first
    }

    /// Insert a new row.
    func create<T: Codable>(table: String, data: T) async throws -> T {
        let results: [T] = try await restRequest(method: "POST", path: table, body: data)
        guard let first = results.first else { throw SupabaseError.unknown }
        return first
    }

    /// Update a row by ID.
    func update<T: Codable>(table: String, id: String, data: T) async throws -> T {
        let qi = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let results: [T] = try await restRequest(method: "PATCH", path: table, queryItems: qi, body: data)
        guard let first = results.first else { throw SupabaseError.unknown }
        return first
    }

    /// Delete a row by ID.
    func delete(table: String, id: String) async throws {
        let qi = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let _: EmptyResponse = try await restRequest(
            method: "DELETE", path: table, queryItems: qi,
            extraHeaders: ["Prefer": "return=minimal"]
        )
    }

    // MARK: - Profile (current user)

    func getProfile() async throws -> User {
        guard accessToken != nil else { throw SupabaseError.unauthorized }
        let authUser = try await getAuthUser()
        let qi = [URLQueryItem(name: "id", value: "eq.\(authUser.id)")]
        let results: [User] = try await restRequest(method: "GET", path: "profiles", queryItems: qi)
        guard let profile = results.first else { throw SupabaseError.notFound }
        return profile
    }

    /// Fetch the current user's profile, or create one if none exists yet.
    /// Handles the new-signup case where no Supabase DB trigger auto-creates `profiles` rows.
    func fetchOrCreateProfile() async throws -> User {
        guard accessToken != nil else { throw SupabaseError.unauthorized }
        let authUser = try await getAuthUser()
        let qi = [URLQueryItem(name: "id", value: "eq.\(authUser.id)")]
        let results: [User] = try await restRequest(method: "GET", path: "profiles", queryItems: qi)
        if let existing = results.first { return existing }
        let seed = User(
            id: authUser.id,
            email: authUser.email ?? "",
            full_name: nil,
            user_type: nil,
            profile_image: nil,
            created_date: nil
        )
        return try await create(table: "profiles", data: seed)
    }

    func updateProfile(_ user: User) async throws -> User {
        let qi = [URLQueryItem(name: "id", value: "eq.\(user.id)")]
        let results: [User] = try await restRequest(method: "PATCH", path: "profiles", queryItems: qi, body: user)
        guard let first = results.first else { throw SupabaseError.unknown }
        return first
    }

    // MARK: - File Upload (Supabase Storage)

    func uploadFile(imageData: Data, bucket: String = "uploads", mimeType: String = "image/jpeg") async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let urlStr = "\(storageURL)/object/\(bucket)/\(fileName)"

        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "POST"
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = imageData

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Upload failed"
            )
        }
        return "\(storageURL)/object/public/\(bucket)/\(fileName)"
    }
}
