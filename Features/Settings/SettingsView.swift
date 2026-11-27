import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SettingsViewModel
    @AppStorage("vibecodeGram.appearance") private var appearance = "system"

    init(api: APIClient, session: SessionStore) {
        _model = StateObject(wrappedValue: SettingsViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Аккаунт и безопасность") {
                    NavigationLink {
                        SessionsSettingsView(model: model)
                    } label: {
                        Label("Активные сессии", systemImage: "iphone.and.arrow.forward")
                    }
                    NavigationLink {
                        BlockedUsersSettingsView(model: model)
                    } label: {
                        Label("Заблокированные", systemImage: "hand.raised")
                    }
                    NavigationLink {
                        ReportsSettingsView(model: model)
                    } label: {
                        Label("Мои жалобы", systemImage: "flag")
                    }
                }

                Section("Профиль и достижения") {
                    NavigationLink {
                        BadgesSettingsView(model: model)
                    } label: {
                        Label("Значки и бейджи", systemImage: "rosette")
                    }
                }

                Section("Внешний вид") {
                    Picker("Тема", selection: $appearance) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                if model.isLoading {
                    ProgressView("Загружаем настройки…")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .task { await model.load() }
            .alert("Настройки", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

@MainActor
private struct SessionsSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        List(model.sessions) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.current ? "Текущая сессия" : "Сессия")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if item.current {
                        Text("ЭТО УСТРОЙСТВО")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                    }
                }
                Text("Создана: \(item.createdAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Последняя активность: \(item.lastSeenAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Истекает: \(item.expiresAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(item.current ? "Выйти" : "Завершить сессию", role: .destructive) {
                    Task { await model.revoke(item) }
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.vertical, 6)
        }
        .overlay {
            if model.sessions.isEmpty {
                ContentUnavailableView("Нет активных сессий", systemImage: "iphone")
            }
        }
        .navigationTitle("Сессии")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct BlockedUsersSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        List(model.blockedUsers) { person in
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.displayName.isEmpty ? person.username : person.displayName)
                    Text("@\(person.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Разблокировать") {
                    Task { await model.unblock(person) }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .overlay {
            if model.blockedUsers.isEmpty {
                ContentUnavailableView("Список пуст", systemImage: "hand.raised")
            }
        }
        .navigationTitle("Заблокированные")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct ReportsSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        List(model.reports) { report in
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Публикация #\(report.postId)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(report.status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text("Причина: \(report.reason)")
                    .font(.caption)
                if !report.details.isEmpty {
                    Text(report.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(report.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 5)
        }
        .overlay {
            if model.reports.isEmpty {
                ContentUnavailableView("Жалоб пока нет", systemImage: "flag")
            }
        }
        .navigationTitle("Мои жалобы")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct BadgesSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        List(model.badges) { badge in
            HStack(spacing: 12) {
                Text(badge.icon.isEmpty ? "✦" : badge.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: badge.color))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(badge.title)
                        .font(.subheadline.weight(.semibold))
                    Text(badge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
        }
        .overlay {
            if model.badges.isEmpty {
                ContentUnavailableView("Бейджей пока нет", systemImage: "rosette")
            }
        }
        .navigationTitle("Бейджи")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        let red = Double((number >> 16) & 0xFF) / 255
        let green = Double((number >> 8) & 0xFF) / 255
        let blue = Double(number & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
