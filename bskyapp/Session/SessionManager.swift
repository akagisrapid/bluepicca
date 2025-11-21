import Foundation

// Global SessionManager class that can be accessed from anywhere in the app
class SessionManager {
    static let shared = SessionManager()
    
    private var currentSession: CreateSessionResponse?
    private var lastSessionTime: Date?
    private let sessionExpiryTime: TimeInterval = 12 * 60 * 60 * 1000 // 12 hours in milliseconds
    
    private let userDefaults = UserDefaults.standard
    private let identifierKey = "bsky_identifier"
    private let appPasswordKey = "bsky_app_password"
    private let lastSessionTimeKey = "bsky_last_session_time"
    
    private init() {
        // Load last session time from UserDefaults if available
        if let lastTime = userDefaults.object(forKey: lastSessionTimeKey) as? Date {
            lastSessionTime = lastTime
        }
    }
    
    var currentUser: CreateSessionResponse? {
        return currentSession
    }
    
    func getSession() async throws -> CreateSessionResponse {
        // If we have a valid session that's not expired, return it
        if let session = currentSession, let lastTime = lastSessionTime,
           Date().timeIntervalSince(lastTime) < sessionExpiryTime {
            return session
        }
        
        // Check if we have saved credentials
        if let identifier = getSavedIdentifier(), let password = getSavedAppPassword() {
            // Create a new session with saved credentials
            let newSession = try await createSession(identifier: identifier, password: password)
            
            // Update session properties on the main thread
            await MainActor.run {
                currentSession = newSession
                lastSessionTime = Date()
                userDefaults.set(lastSessionTime, forKey: lastSessionTimeKey)
            }
            
            return newSession
        } else {
            // No saved credentials, throw an error
            throw SessionError.noSavedCredentials
        }
    }
    
    func createSessionWithCredentials(identifier: String, password: String) async throws -> CreateSessionResponse {
        // Create a new session with provided credentials
        let newSession = try await createSession(identifier: identifier, password: password)
        
        // Save credentials
        saveCredentials(identifier: identifier, password: password)
        
        // Update session properties on the main thread
        await MainActor.run {
            currentSession = newSession
            lastSessionTime = Date()
            userDefaults.set(lastSessionTime, forKey: lastSessionTimeKey)
        }
        
        return newSession
    }
    
    func clearSession() {
        // Ensure we're on the main thread when updating properties
        DispatchQueue.main.async {
            self.currentSession = nil
            self.lastSessionTime = nil
            self.userDefaults.removeObject(forKey: self.lastSessionTimeKey)
        }
    }
    
    func logout() {
        clearSession()
        clearSavedCredentials()
    }
    
    func isLoggedIn() -> Bool {
        if currentSession != nil && lastSessionTime != nil &&
           Date().timeIntervalSince(lastSessionTime!) < sessionExpiryTime {
            return true
        }
        
        // If we have saved credentials, we can try to create a new session
        if getSavedIdentifier() != nil && getSavedAppPassword() != nil {
            // We have saved credentials, but we need to check if the last session time is valid
            if let lastTime = lastSessionTime,
               Date().timeIntervalSince(lastTime) < sessionExpiryTime {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func saveCredentials(identifier: String, password: String) {
        userDefaults.set(identifier, forKey: identifierKey)
        userDefaults.set(password, forKey: appPasswordKey)
    }
    
    private func getSavedIdentifier() -> String? {
        return userDefaults.string(forKey: identifierKey)
    }
    
    private func getSavedAppPassword() -> String? {
        return userDefaults.string(forKey: appPasswordKey)
    }
    
    private func clearSavedCredentials() {
        userDefaults.removeObject(forKey: identifierKey)
        userDefaults.removeObject(forKey: appPasswordKey)
    }
}

// Error types for SessionManager
enum SessionError: Error {
    case noSavedCredentials
    case invalidCredentials
    case networkError
    case unknown
}
