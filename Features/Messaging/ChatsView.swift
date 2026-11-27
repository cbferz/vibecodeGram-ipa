import SwiftUI

@MainActor
struct ChatsView: View {
    @StateObject private var model: ChatsViewModel
    @State private var showingNewChat = false
    @State private var selectedConversation: APIConversation?
    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
        _model = StateObject(wrappedValue: ChatsViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            List(model.conversations) { conversation in
                Button {
                    selectedConversation = conversation
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: conversation.kind == "group" ? "person.3.fill" : "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title.isEmpty ? "Диалог" : conversation.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(conversation.lastMessage.isEmpty ? "Нет сообщений" : conversation.lastMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if model.isLoading && model.conversations.isEmpty {
                    ProgressView()
                } else if model.conversations.isEmpty {
                    ContentUnavailableView(
                        "Нет переписок",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Начните новый диалог.")
                    )
                }
            }
            .navigationTitle("Сообщения")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Новое сообщение")
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .sheet(isPresented: $showingNewChat) {
                NewConversationSheet(api: api, session: session) { person in
                    if let conversation = await model.createDirect(with: person) {
                        selectedConversation = conversation
                        showingNewChat = false
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedConversation) { conversation in
                ConversationView(
                    api: api,
                    session: session,
                    conversation: conversation
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("Сообщения", isPresented: Binding(
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
private struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let api: APIClient
    let session: SessionStore
    let onSelect: (APIPerson) async -> Void
    @State private var query = ""
    @State private var people: [APIPerson] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(people) { person in
                Button {
                    Task { await onSelect(person) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.displayName.isEmpty ? person.username : person.displayName)
                            .foregroundStyle(.primary)
                        Text("@\(person.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if isSearching {
                    ProgressView()
                } else if people.isEmpty {
                    ContentUnavailableView(
                        "Найдите пользователя",
                        systemImage: "person.crop.magnifyingglass",
                        description: Text("Введите минимум два символа.")
                    )
                }
            }
            .searchable(text: $query, prompt: "Имя пользователя")
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle("Новый диалог")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Найти") { Task { await search() } }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || isSearching)
                }
            }
            .alert("Поиск", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func search() async {
        guard let token = session.accessToken else { return }
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            people = try await api.searchUsers(query: value, token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct ConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChatMessagesViewModel
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    private let conversation: APIConversation
    private let currentUserID: Int64

    init(api: APIClient, session: SessionStore, conversation: APIConversation) {
        self.conversation = conversation
        self.currentUserID = session.user?.id ?? 0
        _model = StateObject(wrappedValue: ChatMessagesViewModel(api: api, session: session, conversationID: conversation.id))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.messages) { message in
                                HStack {
                                    if message.senderId == currentUserID { Spacer(minLength: 50) }
                                    VStack(alignment: .leading, spacing: 4) {
                                        if message.senderId != currentUserID {
                                            Text("@\(message.username)")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(message.body)
                                            .font(.body)
                                            .textSelection(.enabled)
                                    }
                                    .padding(12)
                                    .background(
                                        message.senderId == currentUserID ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    if message.senderId != currentUserID { Spacer(minLength: 50) }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(14)
                    }
                    .refreshable { await model.load() }
                    .onChange(of: model.messages.count) { _, _ in
                        if let last = model.messages.last {
                            withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Сообщение…", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                    Button {
                        Task {
                            let sent = await model.send(draft)
                            if sent {
                                draft = ""
                                isFocused = false
                            }
                        }
                    } label: {
                        if model.isSending { ProgressView() }
                        else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)) }
                    }
                    .disabled(model.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.utf8.count > 10_000)
                    .accessibilityLabel("Отправить сообщение")
                }
                .padding(12)
            }
            .navigationTitle(conversation.title.isEmpty ? "Диалог" : conversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .task { await model.load() }
            .alert("Сообщения", isPresented: Binding(
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
