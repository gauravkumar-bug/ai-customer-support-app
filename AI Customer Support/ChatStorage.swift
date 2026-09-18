import Foundation

/// Thread-safe local storage for chat history and session management
final class ChatStorage: Sendable {
    
    // MARK: - Constants
    
    private static let messagesFileName = "chat_history.json"
    private static let sessionIDKey = "chat_session_id"
    
    // MARK: - File Path Resolution
    
    private static var fileURL: URL {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        
        let folderURL = applicationSupport.appendingPathComponent(
            "AICustomerSupport",
            isDirectory: true
        )
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
        }
        
        return folderURL.appendingPathComponent(messagesFileName)
    }
    
    // MARK: - Save Messages
    
    static func saveMessages(_ messages: [Message]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(messages)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ ChatStorage Save Error:", error.localizedDescription)
        }
    }
    
    // MARK: - Load Messages
    
    static func loadMessages() -> [Message] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode([Message].self, from: data)
        } catch {
            print("❌ ChatStorage Load Error:", error.localizedDescription)
            return []
        }
    }
    
    // MARK: - Clear Messages
    
    static func clearMessages() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("❌ ChatStorage Clear Error:", error.localizedDescription)
        }
    }
    
    // MARK: - Session ID Management
    
    static func getSessionID() -> String {
        if let existingID = UserDefaults.standard.string(forKey: sessionIDKey) {
            return existingID
        }
        return resetSession()
    }
    
    @discardableResult
    static func resetSession() -> String {
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: sessionIDKey)
        return newID
    }
    
    /// Clears both stored messages and resets session ID (useful during Logout)
    static func clearAll() {
        clearMessages()
        UserDefaults.standard.removeObject(forKey: sessionIDKey)
    }
}
