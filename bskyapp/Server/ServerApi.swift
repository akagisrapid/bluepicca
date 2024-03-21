import Foundation

class PostItem{
    var text: String = ""
    var postDate: Date = Date()
    func configure(text: String, postDate: Date){
        self.text = text
        self.postDate = postDate
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
