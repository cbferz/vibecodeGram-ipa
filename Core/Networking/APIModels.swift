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

struct CreateVideoPostResponse: Decodable, Sendable {
    let id: Int64
    let authorId: Int64
    let body: String
    let tag: String
    let createdAt: String
    let likes: Int64
    let liked: Bool
    let saved: Bool
    let mediaType: String
    let mediaSize: Int64
    let videoUrl: String
    let contentKind: String
}

struct LikeResponse: Decodable, Sendable {
    let liked: Bool
    let likes: Int64
}

struct SavedResponse: Decodable, Sendable {
    let saved: Bool
}

struct APIStory: Decodable, Sendable, Identifiable, Equatable {
    let id: Int64
    let authorId: Int64
    let username: String
    let displayName: String
    let caption: String
    let mediaType: String
    let mediaSize: Int64
    let createdAt: String
    let expiresAt: String
    let viewed: Bool
    let mediaUrl: String
}

struct CreateStoryResponse: Decodable, Sendable {
    let id: Int64
    let authorId: Int64
    let caption: String
    let mediaType: String
    let mediaSize: Int64
    let createdAt: String
    let expiresAt: String
    let mediaUrl: String
}

struct StoryViewResponse: Decodable, Sendable {
    let viewed: Bool
}

struct StoryDeleteResponse: Decodable, Sendable {
    let deleted: Bool
}

struct APIProfile: Decodable, Sendable, Identifiable {
    let id: Int64
    let username: String
    let displayName: String
    let bio: String
    let avatarUrl: String
    let coverUrl: String
    let website: String
    let location: String
    let followers: Int64
    let following: Int64
    let posts: Int64
    let likes: Int64
    let followed: Bool
    let isMe: Bool
}

struct UpdateProfileRequest: Encodable, Sendable {
    let displayName: String
    let bio: String
    let avatarUrl: String
    let coverUrl: String
    let website: String
    let location: String
}

struct UpdateProfileResponse: Decodable, Sendable {
    let updated: Bool
}

struct APIPerson: Decodable, Sendable, Identifiable {
    let id: Int64
    let username: String
    let displayName: String
}

struct FollowResponse: Decodable, Sendable {
    let following: Bool
}

struct APIComment: Decodable, Sendable, Identifiable {
    let id: Int64
    let authorId: Int64
    let username: String
    let displayName: String
    let body: String
    let createdAt: String
}

struct CreateCommentResponse: Decodable, Sendable {
    let created: Bool
}

struct APINotification: Decodable, Sendable, Identifiable {
    let id: Int64
    let actorId: Int64
    let username: String
    let displayName: String
    let kind: String
    let read: Bool
    let createdAt: String
    let postId: Int64?
    let storyId: Int64?
}

struct MarkNotificationsReadResponse: Decodable, Sendable {
    let read: Bool
}

struct CreateCommentRequest: Encodable, Sendable {
    let body: String
}

struct APIConversation: Decodable, Sendable, Identifiable {
    let id: Int64
    let kind: String
    let title: String
    let createdAt: String
    let lastMessage: String
    let lastMessageAt: String?
}

struct APIMessage: Decodable, Sendable, Identifiable {
    let id: Int64
    let senderId: Int64
    let username: String
    let body: String
    let createdAt: String
}

struct CreateConversationRequest: Encodable, Sendable {
    let kind: String
    let title: String
    let memberIds: [Int64]
}

struct CreateConversationResponse: Decodable, Sendable {
    let id: Int64
    let kind: String
    let title: String
}

struct SendMessageRequest: Encodable, Sendable {
    let body: String
}

struct SendMessageResponse: Decodable, Sendable {
    let id: Int64
    let conversationId: Int64
    let senderId: Int64
    let body: String
    let createdAt: String
}

struct APISession: Decodable, Sendable, Identifiable {
    let id: String
    let createdAt: String
    let lastSeenAt: String
    let expiresAt: String
    let current: Bool
}

struct SessionListResponse: Decodable, Sendable {
    let sessions: [APISession]
}

struct RevokeSessionResponse: Decodable, Sendable {
    let revoked: Bool
}

struct APIBlockedUser: Decodable, Sendable, Identifiable {
    let id: Int64
    let username: String
    let displayName: String
    let blockedAt: String
}

struct BlockUserResponse: Decodable, Sendable {
    let blocked: Bool
}

struct APIReport: Decodable, Sendable, Identifiable {
    let id: Int64
    let postId: Int64
    let reason: String
    let details: String
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct CreateReportRequest: Encodable, Sendable {
    let reason: String
    let details: String
}

struct CreateReportResponse: Decodable, Sendable {
    let reported: Bool
    let reportId: Int64
}

struct APIBadge: Decodable, Sendable, Identifiable {
    let code: String
    let title: String
    let description: String
    let color: String
    let icon: String
    let grantedAt: String?

    var id: String { code }
}

struct BadgeListResponse: Decodable, Sendable {
    let badges: [APIBadge]
}

struct AIModel: Decodable, Sendable, Identifiable {
    let id: String
    var name: String { id }
}

struct AIModelsResponse: Decodable, Sendable {
    let data: [AIModel]
    let configuredModels: [String]
    let provider: String
}

struct AIMessage: Encodable, Sendable, Identifiable {
    let id: UUID
    let role: String
    let content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}

struct AIChatRequest: Encodable, Sendable {
    let messages: [AIMessage]
    let model: String
    let temperature: Double
    let maxTokens: Int
}

struct AIChatResponse: Decodable, Sendable {
    let reply: String
    let model: String
    let provider: String
}

struct AIToolRequest: Encodable, Sendable {
    let text: String
    let context: String
    let targetLanguage: String
}

struct HidePostResponse: Decodable, Sendable {
    let hidden: Bool
}

struct DeviceAccount: Decodable, Sendable, Identifiable {
    let id: Int64
    let username: String
    let displayName: String
    let addedAt: String
    let isPremium: Bool
}

struct DeviceAccountsResponse: Decodable, Sendable {
    let accounts: [DeviceAccount]
    let limit: Int
}

struct DeviceAccountActionResponse: Decodable, Sendable {
    let added: Bool?
    let removed: Bool?
    let limit: Int?
}
