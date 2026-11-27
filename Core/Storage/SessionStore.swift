import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var user: APIUser?
    @Published private(set) var isRestoring = true
    @Published private(set) var restorationError: String?

    private let keychain = KeychainStore()

    func establish(token: String, user: APIUser) throws {
        guard keychain.saveToken(token) else {
            throw SessionError.keychainWriteFailed
        }
        accessToken = token
        self.user = user
        restorationError = nil
        isRestoring = false
    }

    func restore(using api: APIClient) async {
        guard isRestoring else { return }
        guard let token = keychain.readToken() else {
            isRestoring = false
            return
        }

        accessToken = token
        do {
            user = try await api.currentUser(token: token)
            restorationError = nil
        } catch let error as APIError where error.isUnauthorized {
            clear()
        } catch {
            restorationError = "Не удалось проверить сессию. Проверьте подключение и повторите запуск."
        }
        isRestoring = false
    }

    func retryRestore(using api: APIClient) async {
        isRestoring = true
        restorationError = nil
        await restore(using: api)
    }

    func logout(using api: APIClient) async {
        if let token = accessToken {
            do {
                try await api.logout(token: token)
            } catch {
                // Local logout must still complete if the network is unavailable.
            }
        }
        clear()
    }

    func clear() {
        keychain.deleteToken()
        accessToken = nil
        user = nil
        restorationError = nil
        isRestoring = false
    }
}

enum SessionError: Error {
    case keychainWriteFailed
}
