import Foundation
import Combine

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var comments: [APIComment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore
    private let postID: Int64

    init(api: APIClient, session: SessionStore, postID: Int64) {
        self.api = api
        self.session = session
        self.postID = postID
    }

    func load() async {
        guard let token = session.accessToken, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await api.comments(postID: postID, token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(_ text: String) async -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = session.accessToken, !isSending,
              !body.isEmpty, body.utf8.count <= 2000 else { return false }
        isSending = true
        defer { isSending = false }
        do {
            try await api.addComment(postID: postID, body: body, token: token)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
