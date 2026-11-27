import SwiftUI

@MainActor
struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: NotificationsViewModel

    init(api: APIClient, session: SessionStore) {
        _model = StateObject(wrappedValue: NotificationsViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            List(model.notifications) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon(for: item.kind))
                        .font(.title3)
                        .foregroundStyle(item.read ? .secondary : .tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(description(for: item))
                            .font(.subheadline.weight(item.read ? .regular : .semibold))
                        Text(item.createdAt)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if !item.read {
                        Circle()
                            .fill(.tint)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(item.read ? Color.clear : Color.accentColor.opacity(0.06))
            }
            .overlay {
                if model.isLoading && model.notifications.isEmpty {
                    ProgressView()
                } else if model.notifications.isEmpty {
                    ContentUnavailableView(
                        "Уведомлений пока нет",
                        systemImage: "bell",
                        description: Text("Здесь появятся новости о действиях других пользователей.")
                    )
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Прочитано") {
                        Task { await model.markAllRead() }
                    }
                    .disabled(!model.notifications.contains(where: { !$0.read }))
                }
            }
            .refreshable { await model.load() }
            .task {
                await model.load()
                await model.markAllRead()
            }
            .alert("Уведомления", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "follow": return "person.badge.plus"
        case "like": return "heart.fill"
        case "comment": return "bubble.left.fill"
        case "message": return "message.fill"
        default: return "bell.fill"
        }
    }

    private func description(for item: APINotification) -> String {
        let actor = item.displayName.isEmpty ? "@\(item.username)" : item.displayName
        switch item.kind {
        case "follow": return "\(actor) подписался на вас"
        case "like": return "\(actor) оценил вашу публикацию"
        case "comment": return "\(actor) прокомментировал вашу публикацию"
        case "message": return "Новое сообщение от \(actor)"
        default: return "Новое действие от \(actor)"
        }
    }
}
