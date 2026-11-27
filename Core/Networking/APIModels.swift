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
