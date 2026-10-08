import Foundation

extension Error {
    /// APIエラーをユーザー向けのメッセージに変換する
    var userFacingMessage: String {
        if (self as? HTTPError)?.statusCode == 429 {
            return "アクセスが集中しています。しばらくしてから再度お試しください。"
        }
        return localizedDescription
    }
}
