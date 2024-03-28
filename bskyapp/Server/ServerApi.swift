import Foundation

struct Record: Codable{
    let text: String
    let createdAt: String
    let type: String
    init(text: String, createdAt: String, type: String){
        self.text = text
        self.createdAt = createdAt
        self.type =  type
    }
}

enum SystemError: Error{
    case failure(String)
}

enum HttpMethodType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

