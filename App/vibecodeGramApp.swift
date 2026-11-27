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
            } else if session.accessToken != nil, let user = session.user {
                AuthenticatedRootView(user: user, onLogout: {
                    Task { await session.logout(using: api) }
                })
            } else {
                AuthView(api: api)
            }
        }
        .animation(.snappy(duration: 0.25), value: session.isRestoring)
        .preferredColorScheme(nil)
    }
}

private struct AuthenticatedRootView: View {
    let user: APIUser
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 58, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                Text(user.displayName.isEmpty ? user.username : user.displayName)
                    .font(.title2.weight(.semibold))
                Text("@\(user.username)")
                    .foregroundStyle(.secondary)
                Text("Авторизация подтверждена сервером")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Выйти из аккаунта", role: .destructive, action: onLogout)
                    .buttonStyle(.bordered)
                    .padding(.top, 12)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle("vibecodeGram")
        }
    }
}
