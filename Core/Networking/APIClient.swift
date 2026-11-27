import Foundation

struct APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared
    ) {
        let configured = baseURL
            ?? (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
                .flatMap(URL.init(string:))
            ?? URL(string: "https://api.vibecodegram.tendercheck.pro")!
        self.baseURL = configured
        self.session = session
    }

    func authenticate(
        username: String,
        password: String,
        displayName: String?,
        registering: Bool
    ) async throws -> AuthResponse {
        let path = registering ? "/v1/auth/register" : "/v1/auth/login"
        let payload = AuthRequest(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            displayName: registering ? displayName?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
        return try await send(path: path, method: "POST", body: payload)
    }

    func currentUser(token: String) async throws -> APIUser {
        try await send(path: "/v1/me", method: "GET", token: token)
    }

    func logout(token: String) async throws {
        let _: LogoutResponse = try await send(
            path: "/v1/auth/logout",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
    }

    func posts(sort: String, token: String) async throws -> [APIPost] {
        let allowedSorts = ["latest", "popular", "saved", "hidden", "videos"]
        guard allowedSorts.contains(sort) else {
            throw APIError.httpStatus(400, "Unsupported feed sort.")
        }
        return try await send(path: "/v1/posts?sort=\(sort)", method: "GET", token: token)
    }

    func toggleLike(postID: Int64, token: String) async throws -> LikeResponse {
        try await send(
            path: "/v1/posts/\(postID)/like",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
    }

    func setSaved(postID: Int64, saved: Bool, token: String) async throws {
        let path = "/v1/posts/\(postID)/save"
        if saved {
            let _: SavedResponse = try await send(
                path: path,
                method: "PUT",
                body: EmptyRequest(),
                token: token
            )
        } else {
            let _: SavedResponse = try await send(
                path: path,
                method: "DELETE",
                token: token
            )
        }
    }

    func createTextPost(body: String, tag: String, token: String) async throws {
        let payload = CreatePostRequest(body: body, tag: tag)
        let _: CreatePostResponse = try await send(
            path: "/v1/posts",
            method: "POST",
            body: payload,
            token: token
        )
    }

    func reels(offset: Int, limit: Int = 20, token: String) async throws -> [APIPost] {
        let safeOffset = max(0, offset)
        let safeLimit = min(max(1, limit), 30)
        return try await send(
            path: "/v1/reels?limit=\(safeLimit)&offset=\(safeOffset)",
            method: "GET",
            token: token
        )
    }

    func createVideoContent(
        media: Data,
        bodyText: String,
        tag: String,
        asReel: Bool,
        token: String
    ) async throws {
        guard media.count >= 12, media.count <= 50 * 1024 * 1024 else {
            throw APIError.httpStatus(413, "MP4 video must be between 12 bytes and 50 MiB.")
        }
        guard media.subdata(in: 4..<8) == Data("ftyp".utf8) else {
            throw APIError.httpStatus(415, "Only MP4 video files are supported.")
        }

        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = trimmedTag.hasPrefix("#") ? String(trimmedTag.dropFirst()) : trimmedTag
        guard cleanBody.utf8.count <= 5000, cleanTag.utf8.count <= 32 else {
            throw APIError.httpStatus(400, "Video description or tag is too long.")
        }

        let boundary = "vibecodegram-\(UUID().uuidString)"
        var body = Data()
        appendMultipartField("body", value: cleanBody, boundary: boundary, to: &body)
        appendMultipartField("tag", value: cleanTag, boundary: boundary, to: &body)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"upload.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(media)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let endpoint = asReel ? "/v1/reels/video" : "/v1/posts/video"
        let url = baseURL.appending(path: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpStatus(http.statusCode, payload?.error ?? "")
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let _: CreateVideoPostResponse = try decoder.decode(CreateVideoPostResponse.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func profile(userID: Int64, token: String) async throws -> APIProfile {
        try await send(path: "/v1/users/\(userID)", method: "GET", token: token)
    }

    func userPosts(userID: Int64, kind: String, token: String) async throws -> [APIPost] {
        guard ["posts", "videos", "vibees"].contains(kind) else {
            throw APIError.httpStatus(400, "Unsupported profile media kind.")
        }
        return try await send(
            path: "/v1/users/\(userID)/posts?kind=\(kind)",
            method: "GET",
            token: token
        )
    }

    func updateProfile(
        displayName: String,
        bio: String,
        avatarUrl: String,
        coverUrl: String,
        website: String,
        location: String,
        token: String
    ) async throws {
        let payload = UpdateProfileRequest(
            displayName: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
            website: website,
            location: location
        )
        let _: UpdateProfileResponse = try await send(
            path: "/v1/me/profile",
            method: "PUT",
            body: payload,
            token: token
        )
    }

    func followUser(userID: Int64, follow: Bool, token: String) async throws {
        let method = follow ? "POST" : "DELETE"
        if follow {
            let _: FollowResponse = try await send(
                path: "/v1/users/\(userID)/follow",
                method: method,
                body: EmptyRequest(),
                token: token
            )
        } else {
            let _: FollowResponse = try await send(
                path: "/v1/users/\(userID)/follow",
                method: method,
                token: token
            )
        }
    }

    func followers(userID: Int64, following: Bool, token: String) async throws -> [APIPerson] {
        let suffix = following ? "following" : "followers"
        return try await send(
            path: "/v1/users/\(userID)/\(suffix)",
            method: "GET",
            token: token
        )
    }

    func comments(postID: Int64, token: String) async throws -> [APIComment] {
        try await send(path: "/v1/posts/\(postID)/comments", method: "GET", token: token)
    }

    func addComment(postID: Int64, body: String, token: String) async throws {
        let payload = CreateCommentRequest(body: body)
        let _: CreateCommentResponse = try await send(
            path: "/v1/posts/\(postID)/comments",
            method: "POST",
            body: payload,
            token: token
        )
    }

    func sessions(token: String) async throws -> [APISession] {
        let response: SessionListResponse = try await send(path: "/v1/sessions", method: "GET", token: token)
        return response.sessions
    }

    func revokeSession(id: String, token: String) async throws -> Bool {
        let response: RevokeSessionResponse = try await send(
            path: "/v1/sessions/\(id)",
            method: "DELETE",
            token: token
        )
        return response.revoked
    }

    func blockedUsers(token: String) async throws -> [APIBlockedUser] {
        try await send(path: "/v1/me/blocked", method: "GET", token: token)
    }

    func blockUser(userID: Int64, block: Bool, token: String) async throws -> Bool {
        let path = "/v1/users/\(userID)/block"
        let response: BlockUserResponse
        if block {
            response = try await send(path: path, method: "POST", body: EmptyRequest(), token: token)
        } else {
            response = try await send(path: path, method: "DELETE", token: token)
        }
        return response.blocked
    }

    func reportPost(postID: Int64, reason: String, details: String, token: String) async throws {
        let payload = CreateReportRequest(reason: reason, details: details)
        let _: CreateReportResponse = try await send(
            path: "/v1/posts/\(postID)/report",
            method: "POST",
            body: payload,
            token: token
        )
    }

    func myReports(limit: Int = 50, token: String) async throws -> [APIReport] {
        try await send(path: "/v1/me/reports?limit=\(min(max(limit, 1), 100))", method: "GET", token: token)
    }

    func badges(token: String) async throws -> [APIBadge] {
        let response: BadgeListResponse = try await send(path: "/v1/me/badges", method: "GET", token: token)
        return response.badges
    }

    func conversations(token: String) async throws -> [APIConversation] {
        try await send(path: "/v1/conversations", method: "GET", token: token)
    }

    func createConversation(kind: String, title: String, memberIDs: [Int64], token: String) async throws -> CreateConversationResponse {
        let payload = CreateConversationRequest(kind: kind, title: title, memberIds: memberIDs)
        return try await send(
            path: "/v1/conversations",
            method: "POST",
            body: payload,
            token: token
        )
    }

    func messages(conversationID: Int64, limit: Int = 50, before: Int64? = nil, token: String) async throws -> [APIMessage] {
        var components = URLComponents()
        components.path = "/v1/conversations/\(conversationID)/messages"
        var items = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 100)))]
        if let before {
            items.append(URLQueryItem(name: "before", value: String(before)))
        }
        components.queryItems = items
        guard let path = components.string else { throw APIError.invalidBaseURL }
        return try await send(path: path, method: "GET", token: token)
    }

    func sendMessage(conversationID: Int64, body: String, token: String) async throws -> SendMessageResponse {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty, cleanBody.utf8.count <= 10_000 else {
            throw APIError.httpStatus(400, "Message must contain 1–10000 bytes.")
        }
        return try await send(
            path: "/v1/conversations/\(conversationID)/messages",
            method: "POST",
            body: SendMessageRequest(body: cleanBody),
            token: token
        )
    }

    func searchUsers(query: String, token: String) async throws -> [APIPerson] {
        var components = URLComponents()
        components.path = "/v1/users/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let path = components.string else { throw APIError.invalidBaseURL }
        return try await send(path: path, method: "GET", token: token)
    }

    func searchPosts(query: String, token: String) async throws -> [APIPost] {
        var components = URLComponents()
        components.path = "/v1/posts/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let path = components.string else { throw APIError.invalidBaseURL }
        return try await send(path: path, method: "GET", token: token)
    }

    func notifications(token: String) async throws -> [APINotification] {
        try await send(path: "/v1/notifications", method: "GET", token: token)
    }

    func markNotificationsRead(token: String) async throws {
        let _: MarkNotificationsReadResponse = try await send(
            path: "/v1/notifications/read",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
    }

    func stories(token: String) async throws -> [APIStory] {
        try await send(path: "/v1/stories", method: "GET", token: token)
    }

    func markStoryViewed(storyID: Int64, token: String) async throws {
        let _: StoryViewResponse = try await send(
            path: "/v1/stories/\(storyID)/view",
            method: "POST",
            body: EmptyRequest(),
            token: token
        )
    }

    func deleteStory(storyID: Int64, token: String) async throws {
        let _: StoryDeleteResponse = try await send(
            path: "/v1/stories/\(storyID)",
            method: "DELETE",
            token: token
        )
    }

    func createStory(
        media: Data,
        mimeType: String,
        caption: String,
        durationHours: Int,
        token: String
    ) async throws {
        guard [5, 12, 24, 48].contains(durationHours) else {
            throw APIError.httpStatus(400, "Unsupported story expiration.")
        }
        guard caption.utf8.count <= 500 else {
            throw APIError.httpStatus(400, "Story caption must be at most 500 bytes.")
        }
        guard media.count > 0, media.count <= 15 * 1024 * 1024 else {
            throw APIError.httpStatus(413, "Story media must be between 1 byte and 15 MiB.")
        }
        guard ["image/jpeg", "image/png", "image/webp", "video/mp4"].contains(mimeType) else {
            throw APIError.httpStatus(415, "Unsupported story media type.")
        }

        let boundary = "vibecodegram-\(UUID().uuidString)"
        var body = Data()
        appendMultipartField("caption", value: caption, boundary: boundary, to: &body)
        appendMultipartField("duration_hours", value: String(durationHours), boundary: boundary, to: &body)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"story-media\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(media)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURL.appending(path: "/v1/stories")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpStatus(http.statusCode, payload?.error ?? "")
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let _: CreateStoryResponse = try decoder.decode(CreateStoryResponse.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func mediaURL(for path: String) -> URL? {
        URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    func downloadMedia(path: String, token: String) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpStatus(http.statusCode, payload?.error ?? "")
        }
        return data
    }

    private func appendMultipartField(
        _ name: String,
        value: String,
        boundary: String,
        to data: inout Data
    ) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append(value.data(using: .utf8)!)
        data.append("\r\n".data(using: .utf8)!)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil
    ) async throws -> Response {
        try await send(path: path, method: method, body: Optional<EmptyRequest>.none, token: token)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        token: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpStatus(http.statusCode, payload?.error ?? "")
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

private struct EmptyRequest: Encodable, Sendable {}
private struct LogoutResponse: Decodable, Sendable {
    let loggedOut: Bool
}
