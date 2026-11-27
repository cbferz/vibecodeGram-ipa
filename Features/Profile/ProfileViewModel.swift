import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: APIProfile?
    @Published private(set) var posts: [APIPost] = []
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isLoadingPosts = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore
    private let userID: Int64

    init(api: APIClient, session: SessionStore, userID: Int64) {
        self.api = api
        self.session = session
        self.userID = userID
    }

    func load() async {
        guard let token = session.accessToken, !isLoadingProfile else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            profile = try await api.profile(userID: userID, token: token)
            errorMessage = nil
            await loadPosts(kind: "posts")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPosts(kind: String) async {
        guard let token = session.accessToken, !isLoadingPosts else { return }
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            posts = try await api.userPosts(userID: userID, kind: kind, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile(_ input: UpdateProfileRequest) async -> Bool {
        guard let token = session.accessToken, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await api.updateProfile(
                displayName: input.displayName,
                bio: input.bio,
                avatarUrl: input.avatarUrl,
                coverUrl: input.coverUrl,
                website: input.website,
                location: input.location,
                token: token
            )
            profile = try await api.profile(userID: userID, token: token)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
