import Foundation
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [APINotification] = []
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
            notifications = try await api.notifications(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        guard let token = session.accessToken else { return }
        do {
            try await api.markNotificationsRead(token: token)
            notifications = notifications.map { item in
                APINotification(
                    id: item.id,
                    actorId: item.actorId,
                    username: item.username,
                    displayName: item.displayName,
                    kind: item.kind,
                    read: true,
                    createdAt: item.createdAt,
                    postId: item.postId,
                    storyId: item.storyId
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
