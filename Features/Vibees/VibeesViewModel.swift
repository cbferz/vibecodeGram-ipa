import Foundation
import Combine

@MainActor
final class VibeesViewModel: ObservableObject {
    @Published private(set) var reels: [APIPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isPublishing = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func loadInitial() async {
        guard let token = session.accessToken, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            reels = try await api.reels(offset: 0, limit: 20, token: token)
                .filter { $0.contentKind == "reel" && !($0.videoUrl ?? "").isEmpty }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard let token = session.accessToken,
              !isLoadingMore,
              !isLoading,
              !reels.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await api.reels(offset: reels.count, limit: 20, token: token)
            let newItems = next.filter { item in
                item.contentKind == "reel"
                    && !(item.videoUrl ?? "").isEmpty
                    && !reels.contains(where: { $0.id == item.id })
            }
            reels.append(contentsOf: newItems)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ post: APIPost) async {
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

    func toggleSaved(_ post: APIPost) async {
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

    func publish(media: Data, bodyText: String, tag: String) async -> Bool {
        guard let token = session.accessToken, !isPublishing else { return false }
        isPublishing = true
        defer { isPublishing = false }
        do {
            try await api.createVideoContent(
                media: media,
                bodyText: bodyText,
                tag: tag,
                asReel: true,
                token: token
            )
            reels = []
            await loadInitial()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func update(postID: Int64, transform: (APIPost) -> APIPost) {
        guard let index = reels.firstIndex(where: { $0.id == postID }) else { return }
        reels[index] = transform(reels[index])
    }
}
