import Foundation

struct Message: Identifiable, Codable {
    var id: UUID = UUID()
    let text: String
    let isUser: Bool
    var timestamp: Date = Date()
    var order: Order? = nil
}
