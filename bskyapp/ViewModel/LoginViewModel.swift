import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var password: String = ""
    @Published var isLoggingIn: Bool = false
    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if user is already logged in
        isLoggedIn = SessionManager.shared.isLoggedIn()
    }
    
    func login() async {
        if identifier.isEmpty || password.isEmpty {
            await setErrorMessage("ユーザー名とアプリパスワードを入力してください")
            return
        }
        
        await setIsLoggingIn(true)
        await setErrorMessage("")
        
        do {
            _ = try await SessionManager.shared.createSessionWithCredentials(
                identifier: identifier,
                password: password
            )
            
            await setIsLoggingIn(false)
            await setIsLoggedIn(true)
        } catch SessionError.invalidCredentials {
            await setErrorMessage("ユーザー名またはアプリパスワードが正しくありません")
            await setIsLoggingIn(false)
        } catch SessionError.networkError {
            await setErrorMessage("ネットワークエラーが発生しました。インターネット接続を確認してください")
            await setIsLoggingIn(false)
        } catch {
            await setErrorMessage("エラーが発生しました: \(error.localizedDescription)")
            await setIsLoggingIn(false)
        }
    }
    
    func logout() {
        SessionManager.shared.logout()
        isLoggedIn = false
    }
    
    // Helper methods to update published properties on the main thread
    @MainActor
    private func setIsLoggingIn(_ value: Bool) {
        isLoggingIn = value
    }
    
    @MainActor
    private func setErrorMessage(_ message: String) {
        errorMessage = message
    }
    
    @MainActor
    private func setIsLoggedIn(_ value: Bool) {
        isLoggedIn = value
    }
}
