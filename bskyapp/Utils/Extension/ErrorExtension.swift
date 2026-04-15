import Foundation
import Alamofire

extension Error {
    /// APIエラーをユーザー向けのメッセージに変換する
    var userFacingMessage: String {
        if let afError = self as? AFError,
           let statusCode = afError.responseCode,
           statusCode == 429 {
            return "アクセスが集中しています。しばらくしてから再度お試しください。"
        }
        return localizedDescription
    }
}
