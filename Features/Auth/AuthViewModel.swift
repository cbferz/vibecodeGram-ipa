import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var isRegistering = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func toggleMode() {
        isRegistering.toggle()
        errorMessage = nil
    }

    func submit() async {
        guard !isSubmitting else { return }
        errorMessage = nil

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (3...32).contains(cleanUsername.utf8.count),
              cleanUsername.allSatisfy({ $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }) else {
            errorMessage = "Логин: от 3 до 32 символов, только a–z, 0–9 и _."
            return
        }

        guard (10...72).contains(password.utf8.count) else {
            errorMessage = "Пароль должен содержать от 10 до 72 байт."
            return
        }

        if isRegistering && displayName.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count > 64 {
            errorMessage = "Имя профиля не должно превышать 64 байта."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await api.authenticate(
                username: cleanUsername,
                password: password,
                displayName: displayName,
                registering: isRegistering
            )
            try session.establish(token: result.token, user: result.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
