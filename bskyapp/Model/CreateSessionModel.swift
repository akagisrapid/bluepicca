import Foundation

struct CreateSessionRequest: Codable {
    let identifier: String
    let password: String
}

struct CreateSessionResponse: Codable{
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
    let email: String?
    let emailConfirmed : Bool?
}

