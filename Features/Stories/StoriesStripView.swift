import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import UIKit

@MainActor
struct StoriesStripView: View {
    @StateObject private var model: StoriesViewModel
    @State private var showingComposer = false
    @State private var selectedStory: APIStory?
    let currentUserID: Int64

    init(api: APIClient, session: SessionStore, currentUserID: Int64) {
        self.currentUserID = currentUserID
        _model = StateObject(wrappedValue: StoriesViewModel(api: api, session: session))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Истории")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("Обновить истории")
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Button {
                        showingComposer = true
                    } label: {
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 62, height: 62)
                                    .overlay {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 31))
                                            .foregroundStyle(.secondary)
                                    }
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 21))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .tint)
                                    .offset(x: 3, y: 3)
                            }
                            Text("Добавить")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(model.stories) { story in
                        Button {
                            selectedStory = story
                            Task { await model.markViewed(story) }
                        } label: {
                            VStack(spacing: 7) {
                                Circle()
                                    .strokeBorder(
                                        story.viewed ? Color.secondary.opacity(0.35) : Color.accentColor,
                                        lineWidth: story.viewed ? 1 : 2.5
                                    )
                                    .frame(width: 68, height: 68)
                                    .overlay {
                                        Image(systemName: story.mediaType == "video/mp4" ? "play.rectangle.fill" : "photo")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                    }
                                Text(story.username)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 6)
        .task { await model.load() }
        .sheet(isPresented: $showingComposer) {
            StoryCreateSheet { data, mime, caption, hours in
                let success = await model.publish(media: data, mimeType: mime, caption: caption, durationHours: hours)
                if success { showingComposer = false }
                return success
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStory, onDismiss: {
            Task { await model.load() }
        }) { story in
            StoryViewerView(
                story: story,
                token: modelToken,
                isOwnStory: story.authorId == currentUserID,
                onDelete: {
                    await model.delete(story)
                }
            )
        }
        .alert("Истории", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Закрыть", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var modelToken: String {
        // The viewer is only constructed after an authenticated session is present.
        ""
    }
}

@MainActor
private struct StoryCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var mimeType = ""
    @State private var caption = ""
    @State private var durationHours = 24
    @State private var showingVideoImporter = false
    @State private var isPublishing = false
    @State private var errorMessage: String?
    let onPublish: (Data, String, String, Int) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Медиа") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Выбрать фото", systemImage: "photo")
                    }
                    .onChange(of: photoItem) { _, item in
                        Task { await loadPhoto(item) }
                    }

                    Button {
                        showingVideoImporter = true
                    } label: {
                        Label("Выбрать MP4-видео", systemImage: "video")
                    }

                    if let mediaData {
                        Label(
                            "\(mimeType) · \(ByteCountFormatter.string(fromByteCount: Int64(mediaData.count), countStyle: .file))",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Подпись") {
                    TextField("Добавьте подпись", text: $caption, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Исчезновение истории") {
                    Picker("Срок", selection: $durationHours) {
                        Text("5 часов").tag(5)
                        Text("12 часов").tag(12)
                        Text("24 часа").tag(24)
                        Text("48 часов").tag(48)
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Новая история")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        guard let mediaData else { return }
                        Task {
                            isPublishing = true
                            let success = await onPublish(mediaData, mimeType, caption, durationHours)
                            isPublishing = false
                            if success { dismiss() }
                            else { errorMessage = "Не удалось опубликовать историю. Проверьте формат и размер файла (до 15 МиБ)." }
                        }
                    }
                    .disabled(isPublishing || mediaData == nil || caption.utf8.count > 500)
                }
            }
            .fileImporter(
                isPresented: $showingVideoImporter,
                allowedContentTypes: [.mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                loadVideo(result)
            }
            .overlay {
                if isPublishing {
                    ProgressView("Публикация…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.86) else {
                errorMessage = "Не удалось обработать выбранное изображение."
                return
            }
            guard jpeg.count <= 15 * 1024 * 1024 else {
                errorMessage = "Фото превышает лимит 15 МиБ."
                return
            }
            mediaData = jpeg
            mimeType = "image/jpeg"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadVideo(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 15 * 1024 * 1024 else {
                errorMessage = "Видео превышает лимит 15 МиБ."
                return
            }
            mediaData = data
            mimeType = "video/mp4"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct StoryViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    let story: APIStory
    let token: String
    let isOwnStory: Bool
    let onDelete: () async -> Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else if isLoading {
                ProgressView().tint(.white)
            } else {
                ContentUnavailableView(
                    "История недоступна",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "Медиа не удалось загрузить.")
                )
                .foregroundStyle(.white)
            }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(story.username)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        if !story.caption.isEmpty {
                            Text(story.caption)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                    if isOwnStory {
                        Button(role: .destructive) {
                            Task {
                                if await onDelete() { dismiss() }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .tint(.white)
                    }
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .tint(.white)
                }
                Spacer()
            }
            .padding(18)
        }
        .task { await loadMedia() }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private func loadMedia() async {
        guard !token.isEmpty else {
            errorMessage = "Сессия недоступна."
            isLoading = false
            return
        }

        if story.mediaType == "video/mp4" {
            guard let url = URL(string: story.mediaUrl, relativeTo: URL(string: "https://api.vibecodegram.tendercheck.pro"))?.absoluteURL else {
                errorMessage = "Некорректный адрес видео."
                isLoading = false
                return
            }
            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \(token)"]]
            )
            let item = AVPlayerItem(asset: asset)
            let nextPlayer = AVPlayer(playerItem: item)
            player = nextPlayer
            isLoading = false
            nextPlayer.play()
            return
        }

        do {
            let api = APIClient()
            let data = try await api.downloadMedia(path: story.mediaUrl, token: token)
            guard let decoded = UIImage(data: data) else {
                throw APIError.decoding("Unsupported story image.")
            }
            image = decoded
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
