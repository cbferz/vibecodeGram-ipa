import SwiftUI
import AVKit
import UniformTypeIdentifiers

@MainActor
struct VibeesView: View {
    @StateObject private var model: VibeesViewModel
    @State private var showingComposer = false
    private let api: APIClient
    private let token: String

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.token = session.accessToken ?? ""
        _model = StateObject(wrappedValue: VibeesViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    if model.isLoading && model.reels.isEmpty {
                        ProgressView("Загружаем vibees…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if model.reels.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("vibees пока нет")
                                .font(.headline)
                            Text("Короткие видео публикуются отдельно от видео в обычных постах.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Создать vibee") { showingComposer = true }
                                .buttonStyle(.borderedProminent)
                            Button("Обновить") { Task { await model.loadInitial() } }
                                .buttonStyle(.bordered)
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(model.reels.indices, id: \.self) { index in
                                    let post = model.reels[index]
                                    VibeeCard(
                                        api: api,
                                        token: token,
                                        post: post,
                                        height: geometry.size.height,
                                        onLike: { Task { await model.toggleLike(post) } },
                                        onSave: { Task { await model.toggleSaved(post) } }
                                    )
                                    .onAppear {
                                        if index >= model.reels.count - 4 {
                                            Task { await model.loadMore() }
                                        }
                                    }
                                }
                                if model.isLoadingMore {
                                    ProgressView().tint(.white).padding()
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollIndicators(.hidden)
                        .background(.black)
                    }
                }
            }
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("vibees")
                        .font(.title2.weight(.bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingComposer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Создать vibee")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingComposer) {
                VibeeComposerSheet { media, bodyText, tag in
                    let success = await model.publish(media: media, bodyText: bodyText, tag: tag)
                    if success { showingComposer = false }
                    return success
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("vibees", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task { await model.loadInitial() }
        }
    }
}

@MainActor
private struct VibeeCard: View {
    let api: APIClient
    let token: String
    let post: APIPost
    let height: CGFloat
    let onLike: () -> Void
    let onSave: () -> Void
    @State private var player: AVPlayer?
    @State private var isMuted = false

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.72)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    }
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(post.username)")
                            .font(.headline.weight(.bold))
                        if !post.body.isEmpty {
                            Text(post.body)
                                .font(.subheadline)
                                .lineLimit(4)
                        }
                        if !post.tag.isEmpty {
                            Text("#\(post.tag)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    VStack(spacing: 22) {
                        Button(action: onLike) {
                            VStack(spacing: 4) {
                                Image(systemName: post.liked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundStyle(post.liked ? .red : .white)
                                Text(post.likes.formatted()).font(.caption2)
                            }
                        }
                        .accessibilityLabel(post.liked ? "Убрать лайк" : "Нравится")

                        Button(action: onSave) {
                            Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(post.saved ? "Убрать из сохранённого" : "Сохранить")

                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(isMuted ? "Включить звук" : "Выключить звук")
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .frame(height: height)
        .task { await preparePlayer() }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private func preparePlayer() async {
        guard player == nil,
              let path = post.videoUrl,
              let url = api.mediaURL(for: path),
              !token.isEmpty else { return }
        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(token)"]]
        )
        let next = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        next.isMuted = isMuted
        next.actionAtItemEnd = .none
        player = next
        next.play()
    }
}

@MainActor
private struct VibeeComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingImporter = false
    @State private var videoData: Data?
    @State private var bodyText = ""
    @State private var tagText = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?
    let onPublish: (Data, String, String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Видео") {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Выбрать MP4", systemImage: "video.badge.plus")
                    }
                    if let videoData {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(videoData.count), countStyle: .file), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    Text("Максимальный размер — 50 МиБ. Поддерживается MP4.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("Описание") {
                    TextField("Текст vibee", text: $bodyText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Хэштег", text: $tagText)
                        .textInputAutocapitalization(.never)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Новое vibee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        guard let videoData else { return }
                        Task {
                            isPublishing = true
                            let tag = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let success = await onPublish(videoData, bodyText, tag)
                            isPublishing = false
                            if success { dismiss() }
                            else { errorMessage = "Не удалось опубликовать vibee. Проверьте MP4 и размер файла." }
                        }
                    }
                    .disabled(isPublishing || videoData == nil || bodyText.utf8.count > 5000 || tagText.utf8.count > 33)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                loadVideo(result)
            }
            .overlay {
                if isPublishing {
                    ProgressView("Загрузка видео…")
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
                    guard data.count <= 50 * 1024 * 1024 else {
                        errorMessage = "Видео превышает лимит 50 МиБ."
                        return
                    }
                    guard data.count >= 12, data.subdata(in: 4..<8) == Data("ftyp".utf8) else {
                        errorMessage = "Файл не является корректным MP4."
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
}
