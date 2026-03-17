import Foundation

// MARK: - Errors

enum Base44Error: LocalizedError {
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

// MARK: - API Response Types

struct LoginResponse: Decodable {
    let access_token: String?
    let user: User?
}

struct EmptyResponse: Decodable {}

// MARK: - Base44 Client

final class Base44Client {
    static let shared = Base44Client()

    let appId = "695f71cb4f1b571a35a55ba2"
    private let baseURL = "https://base44.app/api"

    private init() {}

    // MARK: Token (memory-cached to avoid blocking Keychain reads on hot paths)

    private var _cachedToken: String? = nil

    var token: String? {
        get {
            if let cached = _cachedToken { return cached }
            let value = KeychainHelper.shared.get(key: "base44_token")
            _cachedToken = value
            return value
        }
        set {
            _cachedToken = newValue
            if let v = newValue {
                KeychainHelper.shared.set(key: "base44_token", value: v)
            } else {
                KeychainHelper.shared.delete(key: "base44_token")
            }
        }
    }

    private var defaultHeaders: [String: String] {
        var h: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-App-Id": appId
        ]
        if let t = token { h["Authorization"] = "Bearer \(t)" }
        return h
    }

    // MARK: Helpers

    private static func extractErrorMessage(from data: Data) -> String? {
        struct APIError: Decodable { let message: String?; let detail: String? }
        guard let parsed = try? JSONDecoder().decode(APIError.self, from: data) else { return nil }
        return parsed.message ?? parsed.detail
    }

    // MARK: Core Request

    private func request<T: Decodable>(
        method: String,
        path: String,
        queryParams: [String: String] = [:],
        body: (any Encodable)? = nil
    ) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !queryParams.isEmpty {
            components.percentEncodedQueryItems = queryParams.map {
                URLQueryItem(
                    name: $0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key,
                    value: $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value
                )
            }
        }

        guard let url = components.url else { throw Base44Error.unknown }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        for (k, v) in defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw Base44Error.unknown }

        switch http.statusCode {
        case 200...299:
            break
        default:
            // Always try to extract the real message from the response body first
            let apiMsg = Base44Client.extractErrorMessage(from: data)
            if http.statusCode == 401 || http.statusCode == 403 {
                if let msg = apiMsg {
                    throw Base44Error.httpError(statusCode: http.statusCode, message: msg)
                }
                throw Base44Error.unauthorized
            }
            if http.statusCode == 404 { throw Base44Error.notFound }
            throw Base44Error.httpError(statusCode: http.statusCode, message: apiMsg)
        }

        // Handle empty body
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Base44Error.decodingError(underlying: error)
        }
    }

    // MARK: Void Request

    private func requestVoid(method: String, path: String, body: (any Encodable)? = nil) async throws {
        let _: EmptyResponse = try await request(method: method, path: path, body: body)
    }

    // MARK: Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        struct LoginBody: Encodable {
            let email: String
            let password: String
        }
        return try await request(
            method: "POST",
            path: "/apps/\(appId)/auth/login",
            body: LoginBody(email: email, password: password)
        )
    }

    func verifyOTP(email: String, otpCode: String) async throws -> LoginResponse {
        struct Body: Encodable { let email: String; let otp_code: String }
        return try await request(
            method: "POST",
            path: "/apps/\(appId)/auth/verify-otp",
            body: Body(email: email, otp_code: otpCode)
        )
    }

    func resendOTP(email: String) async throws {
        struct Body: Encodable { let email: String }
        try await requestVoid(method: "POST", path: "/apps/\(appId)/auth/resend-otp",
                              body: Body(email: email))
    }

    func register(email: String, password: String, fullName: String) async throws -> LoginResponse {
        struct RegisterBody: Encodable {
            let email: String
            let password: String
            let full_name: String
        }
        return try await request(
            method: "POST",
            path: "/apps/\(appId)/auth/register",
            body: RegisterBody(email: email, password: password, full_name: fullName)
        )
    }

    func me() async throws -> User {
        return try await request(method: "GET", path: "/apps/\(appId)/entities/User/me")
    }

    func updateMe(_ user: User) async throws -> User {
        return try await request(
            method: "PUT",
            path: "/apps/\(appId)/entities/User/me",
            body: user
        )
    }

    // MARK: Entity CRUD

    func list<T: Decodable>(
        entity: String,
        sort: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        var params: [String: String] = [:]
        if let sort   { params["sort"]  = sort }
        if let limit  { params["limit"] = String(limit) }
        return try await request(method: "GET", path: "/apps/\(appId)/entities/\(entity)", queryParams: params)
    }

    func filter<T: Decodable>(
        entity: String,
        query: [String: String],
        sort: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        var params: [String: String] = [:]
        if let qData = try? JSONSerialization.data(withJSONObject: query),
           let qStr = String(data: qData, encoding: .utf8) {
            params["q"] = qStr
        }
        if let sort  { params["sort"]  = sort }
        if let limit { params["limit"] = String(limit) }
        return try await request(method: "GET", path: "/apps/\(appId)/entities/\(entity)", queryParams: params)
    }

    func get<T: Decodable>(entity: String, id: String) async throws -> T {
        return try await request(method: "GET", path: "/apps/\(appId)/entities/\(entity)/\(id)")
    }

    func create<T: Codable>(entity: String, data: T) async throws -> T {
        return try await request(method: "POST", path: "/apps/\(appId)/entities/\(entity)", body: data)
    }

    func update<T: Codable>(entity: String, id: String, data: T) async throws -> T {
        return try await request(method: "PUT", path: "/apps/\(appId)/entities/\(entity)/\(id)", body: data)
    }

    func delete(entity: String, id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/apps/\(appId)/entities/\(entity)/\(id)")
    }

    // MARK: File Upload

    func uploadFile(imageData: Data, mimeType: String = "image/jpeg") async throws -> String {
        struct UploadResponse: Decodable { let file_url: String? ; let url: String? }

        var req = URLRequest(url: URL(string: "\(baseURL)/apps/\(appId)/integrations/core/upload-file")!)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(appId, forHTTPHeaderField: "X-App-Id")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(UploadResponse.self, from: data)
        return resp.file_url ?? resp.url ?? ""
    }
}
