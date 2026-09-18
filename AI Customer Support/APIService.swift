import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API Endpoint URL"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode backend response"
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Decodable {
    let id: Int?
    let name: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email
    }
}

// MARK: - Login / Auth Response Model
struct LoginResponse: Decodable {
    let token: String?
    let message: String?
    let mfaRequired: Bool?
    let mfaToken: String?
    let validToken: String?
    let tokenType: String?
    let user: UserProfile?

    init(token: String? = nil, message: String? = nil, mfaRequired: Bool? = nil, mfaToken: String? = nil, validToken: String? = nil, tokenType: String? = nil, user: UserProfile? = nil) {
        self.token = token
        self.message = message
        self.mfaRequired = mfaRequired
        self.mfaToken = mfaToken
        self.validToken = validToken
        self.tokenType = tokenType
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.token = try container.decodeIfPresent(String.self, forKey: .token)
            ?? container.decodeIfPresent(String.self, forKey: .access_token)

        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.mfaRequired = try container.decodeIfPresent(Bool.self, forKey: .mfaRequired)
        self.mfaToken = try container.decodeIfPresent(String.self, forKey: .mfaToken)
        self.validToken = try container.decodeIfPresent(String.self, forKey: .validToken)
        self.tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        self.user = try container.decodeIfPresent(UserProfile.self, forKey: .user)
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case access_token
        case message
        case mfaRequired = "mfa_required"
        case mfaToken = "mfa_token"
        case validToken = "valid_token"
        case tokenType = "token_type"
        case user
    }
}

final class APIService {
    static let shared = APIService()

    // Change this to your machine's LAN IP (e.g. "http://192.168.1.10:8000")
    // when running on a real device or a simulator that can't reach
    // 127.0.0.1 on your Mac. Can also be overridden at launch with
    // `-apiBaseURL http://...` for easy testing without recompiling.
    private let baseURL: String = {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        return "http://127.0.0.1:8000"
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Shared request helper

    private func makeRequest(
        path: String,
        method: String,
        body: Encodable? = nil,
        authorized: Bool = false
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authorized, let token = KeychainManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(GenericResponse.self, from: data))?.message
                ?? String(data: data, encoding: .utf8)
                ?? "Server returned an error."
            throw APIError.serverError(errorMsg)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    // MARK: - 1. Authentication & Password APIs

    func login(email: String, password: String) async throws -> LoginResponse {
        let request = try makeRequest(
            path: "/login",
            method: "POST",
            body: LoginRequest(email: email, password: password)
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func register(name: String, email: String, password: String) async throws -> LoginResponse {
        // NOTE: the current backend's /register only accepts
        // {email, password} - it ignores "name" entirely (there's no
        // "name" column on the users table). Sending it is harmless but
        // it will not be persisted until the backend is extended.
        let request = try makeRequest(
            path: "/register",
            method: "POST",
            body: RegisterRequest(name: name, email: email, password: password)
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func verifyMFA(email: String, otp: String) async throws -> LoginResponse {
        // The real backend's OTPVerifyRequest expects {email, otp} — not
        // {mfa_token, code}. It also doesn't return a fresh access_token
        // on success, just a {"status", "message"} confirmation, so this
        // returns a LoginResponse with just the message populated; the
        // caller is expected to already hold the original login/register
        // token from before MFA was triggered (or to call login() again).
        let request = try makeRequest(
            path: "/auth/verify-mfa",
            method: "POST",
            body: ["email": email, "otp": otp]
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func sendOTP(email: String) async throws -> LoginResponse {
        let request = try makeRequest(
            path: "/api/auth/send-otp",
            method: "POST",
            body: ["email": email]
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func googleSignIn(email: String, name: String) async throws -> LoginResponse {
        // IMPORTANT: this backend's /api/auth/google does NOT verify a
        // Google ID token server-side — it just takes whatever
        // {email, name} the client sends and creates/logs in that user.
        // (This is a real security gap in the backend — anyone who can
        // call this endpoint can log in as any email. Flagging this but
        // matching the existing behavior rather than silently changing
        // the backend's trust model.)
        let request = try makeRequest(
            path: "/api/auth/google",
            method: "POST",
            body: ["email": email, "name": name]
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func forgotPassword(email: String) async throws -> LoginResponse {
        let request = try makeRequest(
            path: "/auth/forgot-password",
            method: "POST",
            body: ForgotPasswordRequest(email: email)
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> LoginResponse {
        let request = try makeRequest(
            path: "/auth/reset-password",
            method: "POST",
            body: ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
        )
        return try await perform(request, as: LoginResponse.self)
    }

    func changePassword(current: String, new: String) async throws {
        let request = try makeRequest(
            path: "/change-password",
            method: "POST",
            body: ["current_password": current, "new_password": new],
            authorized: true
        )
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("No response from server.")
        }
        guard (200...299).contains(http.statusCode) else {
            var msg = "Could not change password."
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] {
                if let text = detail as? String {
                    msg = text
                } else {
                    msg = "Please check the details and try again."
                }
            }
            throw APIError.serverError(msg)
        }
    }

    // MARK: - 2. Send Chat Message

    func sendMessage(message: String, sessionID: String) async throws -> ChatResponse {
        let request = try makeRequest(
            path: "/chat",
            method: "POST",
            body: ChatRequest(message: message, sessionID: sessionID),
            authorized: true
        )
        return try await perform(request, as: ChatResponse.self)
    }

    // MARK: - 3. Clear Chat Session

    func clearChatSession(sessionID: String) async throws {
        let request = try makeRequest(
            path: "/chat/clear",
            method: "POST",
            body: ["session_id": sessionID],
            authorized: true
        )
        _ = try await session.data(for: request)
    }

    // MARK: - 4. Fetch Order Details

    private struct OrderEnvelope: Decodable {
        let order: Order
    }

    func fetchOrderDetails(orderID: String) async throws -> Order {
        let request = try makeRequest(
            path: "/orders/\(orderID)",
            method: "GET",
            authorized: true
        )
        // The real backend wraps the order in {"order": {...}}, not a
        // bare order object at the top level.
        let envelope = try await perform(request, as: OrderEnvelope.self)
        return envelope.order
    }
}

// MARK: - Type-erasure helper so makeRequest can accept any Encodable
// (including plain dictionaries like ["session_id": sessionID]).

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeClosure = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

extension Dictionary: Encodable where Key == String, Value == String {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in self {
            try container.encode(value, forKey: DynamicKey(stringValue: key)!)
        }
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
