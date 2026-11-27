import SwiftUI
import AVKit
import UniformTypeIdentifiers

@MainActor
struct FeedView: View {
    private let api: APIClient
    private let session: SessionStore
    @StateObject private var model: FeedViewModel
    @State private var showingComposer = false
    @State private var showingNotifications = false
    @State private var showingSearch = false
    @State private var selectedCommentPost: APIPost?
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
                                api: api,
                                token: session.accessToken ?? "",
                                post: post,
                                onLike: { Task { await model.toggleLike(for: post) } },
                                onComments: { selectedCommentPost = post },
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
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Поиск")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNotifications = true
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Уведомления")
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
                CreatePostSheet(
                    onPublish: { body, tag in
                        let success = await model.publish(body: body, tag: tag)
                        if success { showingComposer = false }
                        return success
                    },
                    onPublishVideo: { media, body, tag in
                        let success = await model.publishVideo(media: media, body: body, tag: tag)
                        if success { showingComposer = false }
                        return success
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedCommentPost) { post in
                CommentsSheet(api: api, session: session, postID: post.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet(api: api, session: session)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSearch) {
                SearchSheet(api: api, session: session)
                    .presentationDetents([.large])
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
    let api: APIClient
    let token: String
    let post: APIPost
    let onLike: () -> Void
    let onComments: () -> Void
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

                if let mediaType = post.mediaType, mediaType == "video/mp4",
                   let videoPath = post.videoUrl, !videoPath.isEmpty {
                    AuthenticatedVideoPreview(api: api, token: token, path: videoPath)
                    Label(
                        "Видео · \(ByteCountFormatter.string(fromByteCount: post.mediaSize ?? 0, countStyle: .file))",
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

                    Button(action: onComments) {
                        Image(systemName: "bubble.right")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Комментарии")

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
    @State private var videoData: Data?
    @State private var showingVideoImporter = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    let onPublish: (String, String) async -> Bool
    let onPublishVideo: (Data, String, String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Медиа (необязательно)") {
                    Button {
                        showingVideoImporter = true
                    } label: {
                        Label("Выбрать MP4-видео", systemImage: "video")
                    }
                    if let videoData {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(videoData.count), countStyle: .file), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                }
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
            .fileImporter(
                isPresented: $showingVideoImporter,
                allowedContentTypes: [.mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                loadVideo(result)
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
                            let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let success: Bool
                            if let videoData {
                                success = await onPublishVideo(videoData, cleanBody, normalizedTag)
                            } else {
                                success = await onPublish(cleanBody, normalizedTag)
                            }
                            if !success {
                                errorMessage = "Публикацию не удалось отправить. Проверьте текст и подключение."
                            }
                            isSubmitting = false
                        }
                    }
                    .disabled(
                        isSubmitting
                        || (videoData == nil && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        || bodyText.utf8.count > 5000
                        || normalizedTag.utf8.count > 32
                        || (videoData != nil && (videoData?.count ?? 0) > 50 * 1024 * 1024)
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

    private func loadVideo(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            Task {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer {
                            if hasAccess { url.stopAccessingSecurityScopedResource() }
                        }
                        return try Data(contentsOf: url, options: .mappedIfSafe)
                    }.value
                    guard data.count >= 12, data.count <= 50 * 1024 * 1024,
                          data.subdata(in: 4..<8) == Data("ftyp".utf8) else {
                        errorMessage = "Выберите корректный MP4-файл размером до 50 МиБ."
                        return
                    }
                    videoData = data
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedTag: String {
        tagText.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
    }
}


@MainActor
private struct AuthenticatedVideoPreview: View {
    let api: APIClient
    let token: String
    let path: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ZStack {
                    Color.black.opacity(0.9)
                    ProgressView().tint(.white)
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task { await prepare() }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private func prepare() async {
        guard player == nil, !token.isEmpty, let url = api.mediaURL(for: path) else { return }
        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(token)"]]
        )
        let next = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        player = next
    }
}
