import Foundation

// MARK: - Chat Request
struct ChatRequest: Encodable {
    let message: String
    let sessionID: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case sessionID = "session_id"
    }
}

// MARK: - Chat Response
struct ChatResponse: Decodable {
    let response: String
    let order: Order?
}
