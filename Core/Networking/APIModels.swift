import Foundation

struct APIUser: Codable, Sendable, Equatable {
    let id: Int64
    let username: String
    let displayName: String
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: APIUser
}

struct APIErrorResponse: Decodable, Sendable {
    let error: String
}

struct AuthRequest: Encodable, Sendable {
    let username: String
    let password: String
    let displayName: String?
}

struct APIPost: Decodable, Sendable, Identifiable, Equatable {
    let id: Int64
    let authorId: Int64
    let username: String
    let displayName: String
    let body: String
    let tag: String
    let createdAt: String
    let likes: Int64
    let liked: Bool
    let saved: Bool
    let videoUrl: String?
    let mediaType: String?
    let mediaSize: Int64?
    let contentKind: String?
}

struct CreatePostRequest: Encodable, Sendable {
    let body: String
    let tag: String
}

struct CreatePostResponse: Decodable, Sendable {
    let id: Int64
    let authorId: Int64
    let body: String
    let tag: String
    let createdAt: String
    let likes: Int64
    let liked: Bool
    let saved: Bool
}

struct LikeResponse: Decodable, Sendable {
    let liked: Bool
    let likes: Int64
}

struct SavedResponse: Decodable, Sendable {
    let saved: Bool
}
