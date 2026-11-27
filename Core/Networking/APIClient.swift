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
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

private struct EmptyRequest: Encodable, Sendable {}
private struct LogoutResponse: Decodable, Sendable {
    let loggedOut: Bool
}
