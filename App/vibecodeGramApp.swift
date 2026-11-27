import SwiftUI

@main
struct vibecodeGramApp: App {
    @StateObject private var session = SessionStore()
    private let api = APIClient()

    var body: some Scene {
        WindowGroup {
            AppRootView(api: api)
                .environmentObject(session)
                .task {
                    await session.restore(using: api)
                }
        }
    }
}

@MainActor
private struct AppRootView: View {
    @EnvironmentObject private var session: SessionStore
    let api: APIClient

    var body: some View {
        Group {
            if session.isRestoring {
                ProgressView("Подключение к vibecodeGram…")
                    .tint(.primary)
            } else if let user = session.user {
                FeedView(api: api, session: session, user: user, onLogout: {
                    Task { await session.logout(using: api) }
                })
            } else if session.accessToken != nil {
                SessionRecoveryView(message: session.restorationError ?? "Не удалось проверить сессию.") {
                    Task { await session.retryRestore(using: api) }
                }
            } else {
                AuthView(api: api, session: session)
            }
        }
        .animation(.snappy(duration: 0.25), value: session.isRestoring)
        .preferredColorScheme(nil)
    }
}

private struct SessionRecoveryView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Повторить", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}
