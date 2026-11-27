import SwiftUI

@MainActor
struct FeedView: View {
    private let api: APIClient
    private let session: SessionStore
    @StateObject private var model: FeedViewModel
    @State private var showingComposer = false
    let user: APIUser
    let onLogout: () -> Void

    init(api: APIClient, session: SessionStore, user: APIUser, onLogout: @escaping () -> Void) {
        self.api = api
        self.session = session
        self.user = user
        self.onLogout = onLogout
        _model = StateObject(wrappedValue: FeedViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    StoriesStripView(api: api, session: session, currentUserID: user.id)
                        .padding(.horizontal, 2)
                    if model.isLoading && model.posts.isEmpty {
                        ProgressView("Загружаем ленту…")
                            .padding(.top, 48)
                    } else if model.posts.isEmpty {
                        GlassSurface {
                            ContentUnavailableView(
                                "Пока нет публикаций",
                                systemImage: "rectangle.stack",
                                description: Text("Новые публикации появятся здесь.")
                            )
                        }
                        .padding(.top, 28)
                    } else {
                        ForEach(model.posts) { post in
                            FeedPostCard(
                                post: post,
                                onLike: { Task { await model.toggleLike(for: post) } },
                                onSave: { Task { await model.toggleSaved(for: post) } }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable { await model.load() }
            .navigationTitle("vibecodeGram")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("@\(user.username)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: onLogout) {
                            Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Аккаунт")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Создать публикацию")
                }
            }
            .sheet(isPresented: $showingComposer) {
                CreatePostSheet { body, tag in
                    let success = await model.publish(body: body, tag: tag)
                    if success { showingComposer = false }
                    return success
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Не удалось выполнить действие", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task { await model.load() }
        }
    }
}

private struct FeedPostCard: View {
    let post: APIPost
    let onLike: () -> Void
    let onSave: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.displayName.isEmpty ? post.username : post.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("@\(post.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(post.createdAt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !post.body.isEmpty {
                    Text(post.body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if !post.tag.isEmpty {
                    Text("#\(post.tag)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }

                if let mediaType = post.mediaType, !mediaType.isEmpty {
                    Label(
                        "Видеопубликация · \(ByteCountFormatter.string(fromByteCount: post.mediaSize ?? 0, countStyle: .file))",
                        systemImage: "play.rectangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 22) {
                    Button(action: onLike) {
                        Label(post.likes.formatted(), systemImage: post.liked ? "heart.fill" : "heart")
                            .foregroundStyle(post.liked ? .red : .primary)
                    }
                    .accessibilityLabel(post.liked ? "Убрать отметку нравится" : "Нравится")

                    Button(action: onSave) {
                        Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(post.saved ? "Убрать из сохранённого" : "Сохранить")

                    Spacer()
                    if post.contentKind == "reel" {
                        Label("vibee", systemImage: "play.square.stack")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
            }
        }
    }
}

private struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var tagText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    let onPublish: (String, String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Текст публикации") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 130)
                        .accessibilityLabel("Текст публикации")
                    Text("\(bodyText.utf8.count) / 5000 байт")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("Хэштег") {
                    TextField("Например, жизнь", text: $tagText)
                        .textInputAutocapitalization(.never)
                    Text("\(normalizedTag.utf8.count) / 32 байта")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Новая публикация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        Task {
                            isSubmitting = true
                            let success = await onPublish(
                                bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                                normalizedTag
                            )
                            if !success {
                                errorMessage = "Публикацию не удалось отправить. Проверьте текст и подключение."
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(
                        isSubmitting
                        || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || bodyText.utf8.count > 5000
                        || normalizedTag.utf8.count > 32
                    )
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var normalizedTag: String {
        tagText.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
    }
}
