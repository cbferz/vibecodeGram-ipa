import SwiftUI

@MainActor
struct DeviceAccountsView: View {
    let api: APIClient
    let session: SessionStore
    @State private var accounts: [DeviceAccount] = []
    @State private var limit = 3
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var selectedAccount: DeviceAccount?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await addCurrentAccount() }
                } label: {
                    HStack {
                        Label("Добавить текущий аккаунт", systemImage: "plus.circle")
                        Spacer()
                        if isAdding { ProgressView() }
                    }
                }
                .disabled(isAdding || accounts.contains(where: { $0.id == session.user?.id }))
                Text("На этом устройстве: \(accounts.count) из \(limit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Сохранённые аккаунты") {
                ForEach(accounts) { account in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.displayName.isEmpty ? account.username : account.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("@\(account.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if account.id == session.user?.id {
                                Text("ТЕКУЩИЙ")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        HStack {
                            if account.id != session.user?.id {
                                Button("Переключить") {
                                    selectedAccount = account
                                }
                                .buttonStyle(.bordered)
                            }
                            Spacer()
                            Button("Удалить", role: .destructive) {
                                Task { await remove(account) }
                            }
                            .font(.caption.weight(.medium))
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            } else if accounts.isEmpty {
                ContentUnavailableView(
                    "Нет сохранённых аккаунтов",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Добавьте текущий аккаунт, чтобы он появился в списке этого устройства.")
                )
            }
        }
        .navigationTitle("Аккаунты устройства")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selectedAccount) { account in
            DeviceAccountSwitchSheet(account: account) { password in
                do {
                    let result = try await api.authenticate(
                        username: account.username,
                        password: password,
                        displayName: nil,
                        registering: false
                    )
                    try session.establish(token: result.token, user: result.user)
                    return true
                } catch {
                    errorMessage = error.localizedDescription
                    return false
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Аккаунты устройства", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Закрыть", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        guard let token = session.accessToken else {
            errorMessage = "Сессия завершена."
            isLoading = false
            return
        }
        do {
            let result = try await api.deviceAccounts(deviceID: DeviceIdentity.current, token: token)
            accounts = result.accounts
            limit = result.limit
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addCurrentAccount() async {
        guard let token = session.accessToken else { return }
        isAdding = true
        defer { isAdding = false }
        do {
            let result = try await api.addDeviceAccount(deviceID: DeviceIdentity.current, token: token)
            if let newLimit = result.limit { limit = newLimit }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ account: DeviceAccount) async {
        guard let token = session.accessToken else { return }
        do {
            _ = try await api.removeDeviceAccount(
                accountID: account.id,
                deviceID: DeviceIdentity.current,
                token: token
            )
            accounts.removeAll { $0.id == account.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct DeviceAccountSwitchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let account: DeviceAccount
    let onSwitch: (String) async -> Bool
    @State private var password = ""
    @State private var isSwitching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Переключение аккаунта") {
                    Text(account.displayName.isEmpty ? account.username : account.displayName)
                    Text("@\(account.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Пароль аккаунта", text: $password)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Войти в аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Войти") {
                        Task {
                            isSwitching = true
                            let success = await onSwitch(password)
                            isSwitching = false
                            if success { dismiss() }
                            else { errorMessage = "Не удалось выполнить вход. Проверьте пароль и подключение." }
                        }
                    }
                    .disabled(isSwitching || password.isEmpty)
                }
            }
            .overlay {
                if isSwitching {
                    ProgressView("Вход…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
