import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var posts: [APIPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPublishing = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func load() async {
        guard let token = session.accessToken, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            posts = try await api.posts(sort: "latest", token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(for post: APIPost) async {
        guard let token = session.accessToken else { return }
        do {
            let result = try await api.toggleLike(postID: post.id, token: token)
            update(postID: post.id) { current in
                APIPost(
                    id: current.id,
                    authorId: current.authorId,
                    username: current.username,
                    displayName: current.displayName,
                    body: current.body,
                    tag: current.tag,
                    createdAt: current.createdAt,
                    likes: result.likes,
                    liked: result.liked,
                    saved: current.saved,
                    videoUrl: current.videoUrl,
                    mediaType: current.mediaType,
                    mediaSize: current.mediaSize,
                    contentKind: current.contentKind
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSaved(for post: APIPost) async {
        guard let token = session.accessToken else { return }
        do {
            let saved = !post.saved
            try await api.setSaved(postID: post.id, saved: saved, token: token)
            update(postID: post.id) { current in
                APIPost(
                    id: current.id,
                    authorId: current.authorId,
                    username: current.username,
                    displayName: current.displayName,
                    body: current.body,
                    tag: current.tag,
                    createdAt: current.createdAt,
                    likes: current.likes,
                    liked: current.liked,
                    saved: saved,
                    videoUrl: current.videoUrl,
                    mediaType: current.mediaType,
                    mediaSize: current.mediaSize,
                    contentKind: current.contentKind
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func publish(body: String, tag: String) async -> Bool {
        guard let token = session.accessToken else {
            errorMessage = "Сессия завершена. Войдите снова."
            return false
        }
        guard !isPublishing else { return false }

        isPublishing = true
        defer { isPublishing = false }

        do {
            try await api.createTextPost(body: body, tag: tag, token: token)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func update(postID: Int64, transform: (APIPost) -> APIPost) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index] = transform(posts[index])
    }
}
