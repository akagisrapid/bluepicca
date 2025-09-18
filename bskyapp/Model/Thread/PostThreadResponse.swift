//
//  PostThreadResponse.swift
//  bskyapp
//
//  Created by shuya on 2025/09/17.
//

import Foundation

struct PostThreadResponse: Codable {
    let thread: ThreadViewPost
}

struct ThreadViewPost: Codable, Identifiable {
    let id = UUID()
    let type: String?
    let post: Post
    let parent: Box<ThreadViewPost>?
    let replies: [ThreadViewPost]?
    
    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case post, parent, replies
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        post = try container.decode(Post.self, forKey: .post)
        
        if let parentData = try container.decodeIfPresent(ThreadViewPost.self, forKey: .parent) {
            parent = Box(parentData)
        } else {
            parent = nil
        }
        
        replies = try container.decodeIfPresent([ThreadViewPost].self, forKey: .replies)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(post, forKey: .post)
        try container.encodeIfPresent(parent?.value, forKey: .parent)
        try container.encodeIfPresent(replies, forKey: .replies)
    }
}

// 間接参照のためのBox型
class Box<T>: Codable where T: Codable {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
