import Foundation
import Combine

@MainActor
final class StoriesViewModel: ObservableObject {
    @Published private(set) var stories: [APIStory] = []
    @Published private(set) var isLoading = false
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
            stories = try await api.stories(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markViewed(_ story: APIStory) async {
        guard let token = session.accessToken, !story.viewed else { return }
        do {
            try await api.markStoryViewed(storyID: story.id, token: token)
            if let index = stories.firstIndex(where: { $0.id == story.id }) {
                let old = stories[index]
                stories[index] = APIStory(
                    id: old.id,
                    authorId: old.authorId,
                    username: old.username,
                    displayName: old.displayName,
                    caption: old.caption,
                    mediaType: old.mediaType,
                    mediaSize: old.mediaSize,
                    createdAt: old.createdAt,
                    expiresAt: old.expiresAt,
                    viewed: true,
                    mediaUrl: old.mediaUrl
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ story: APIStory) async -> Bool {
        guard let token = session.accessToken else { return false }
        do {
            try await api.deleteStory(storyID: story.id, token: token)
            stories.removeAll { $0.id == story.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func publish(media: Data, mimeType: String, caption: String, durationHours: Int) async -> Bool {
        guard let token = session.accessToken else { return false }
        do {
            try await api.createStory(
                media: media,
                mimeType: mimeType,
                caption: caption,
                durationHours: durationHours,
                token: token
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
