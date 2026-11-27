import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var sessions: [APISession] = []
    @Published private(set) var blockedUsers: [APIBlockedUser] = []
    @Published private(set) var reports: [APIReport] = []
    @Published private(set) var badges: [APIBadge] = []
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

        do { sessions = try await api.sessions(token: token) }
        catch { errorMessage = error.localizedDescription }

        do { blockedUsers = try await api.blockedUsers(token: token) }
        catch { errorMessage = error.localizedDescription }

        do { reports = try await api.myReports(token: token) }
        catch { errorMessage = error.localizedDescription }

        do { badges = try await api.badges(token: token) }
        catch { errorMessage = error.localizedDescription }
    }

    func revoke(_ item: APISession) async {
        guard let token = session.accessToken else { return }
        do {
            let revoked = try await api.revokeSession(id: item.id, token: token)
            if revoked {
                sessions.removeAll { $0.id == item.id }
                if item.current {
                    session.clear()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblock(_ person: APIBlockedUser) async {
        guard let token = session.accessToken else { return }
        do {
            _ = try await api.blockUser(userID: person.id, block: false, token: token)
            blockedUsers.removeAll { $0.id == person.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
