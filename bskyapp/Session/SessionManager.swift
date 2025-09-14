import Foundation

// Global SessionManager class that can be accessed from anywhere in the app
class SessionManager {
    static let shared = SessionManager()
    
    private var currentSession: CreateSessionResponse?
    private var lastSessionTime: Date?
    private let sessionExpiryTime: TimeInterval = 3600 // 1 hour in seconds
    
    private init() {}
    
    func getSession() async throws -> CreateSessionResponse {
        // If we have a valid session that's not expired, return it
        if let session = currentSession, let lastTime = lastSessionTime,
           Date().timeIntervalSince(lastTime) < sessionExpiryTime {
            return session
        }
        
        // Otherwise create a new session
        let newSession = try await createSession()
        currentSession = newSession
        lastSessionTime = Date()
        return newSession
    }
    
    func clearSession() {
        currentSession = nil
        lastSessionTime = nil
    }
}
