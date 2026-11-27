import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published private(set) var people: [APIPerson] = []
    @Published private(set) var posts: [APIPost] = []
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func search(_ rawQuery: String) async {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, let token = session.accessToken, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            async let foundPeople = api.searchUsers(query: query, token: token)
            async let foundPosts = api.searchPosts(query: query, token: token)
            let (peopleResult, postsResult) = try await (foundPeople, foundPosts)
            people = peopleResult
            posts = postsResult
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
