import Foundation

// MARK: - Request Models

struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct VerifyMFARequest: Encodable {
    let mfaToken: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case mfaToken = "mfa_token"
        case code
    }
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case newPassword = "new_password"
    }
}

// MARK: - Response Models

struct AuthResponse: Decodable {
    let token: String?
    let accessToken: String?
    let jwtToken: String?
    let mfaRequired: Bool?
    let mfaToken: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case token
        case accessToken = "access_token"
        case jwtToken = "jwt"
        case mfaRequired = "mfa_required"
        case mfaToken = "mfa_token"
        case message
    }

    /// Flexible property that extracts whatever token key backend returned
    var validToken: String? {
        if let token = token, !token.isEmpty { return token }
        if let accessToken = accessToken, !accessToken.isEmpty { return accessToken }
        if let jwtToken = jwtToken, !jwtToken.isEmpty { return jwtToken }
        return nil
    }
}

struct GenericResponse: Decodable {
    let message: String?
}
