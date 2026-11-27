import SwiftUI

@MainActor
struct ProfileView: View {
    @StateObject private var model: ProfileViewModel
    @State private var selectedKind = "posts"
    @State private var showingEditor = false
    @State private var selectedPeople: PeopleListKind?
    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore, userID: Int64) {
        self.api = api
        self.session = session
        _model = StateObject(wrappedValue: ProfileViewModel(api: api, session: session, userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = model.profile {
                    VStack(spacing: 14) {
                        profileHeader(profile)
                        Picker("Публикации", selection: $selectedKind) {
                            Text("Посты").tag("posts")
                            Text("Видео").tag("videos")
                            Text("vibees").tag("vibees")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedKind) { _, kind in
                            Task { await model.loadPosts(kind: kind) }
                        }

                        if model.isLoadingPosts && model.posts.isEmpty {
                            ProgressView("Загружаем публикации…")
                                .padding(.top, 30)
                        } else if model.posts.isEmpty {
                            ContentUnavailableView(
                                "Пока пусто",
                                systemImage: "square.grid.2x2",
                                description: Text("В этой вкладке ещё нет публикаций.")
                            )
                            .padding(.top, 22)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(model.posts) { post in
                                    GlassSurface(cornerRadius: 20) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(post.body)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            if !post.tag.isEmpty {
                                                Text("#\(post.tag)")
                                                    .foregroundStyle(.tint)
                                                    .font(.caption)
                                            }
                                            HStack {
                                                Label(post.likes.formatted(), systemImage: "heart")
                                                Spacer()
                                                if post.contentKind == "reel" {
                                                    Label("vibee", systemImage: "play.rectangle")
                                                } else if let mediaType = post.mediaType, !mediaType.isEmpty {
                                                    Label("Видео", systemImage: "video")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                } else if model.isLoadingProfile {
                    ProgressView("Загружаем профиль…")
                        .padding(.top, 60)
                } else {
                    ContentUnavailableView(
                        "Профиль недоступен",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(model.errorMessage ?? "Не удалось загрузить профиль.")
                    )
                    .padding(.top, 50)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Профиль")
            .toolbar {
                if model.profile?.isMe == true {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Редактировать профиль")
                    }
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .sheet(isPresented: $showingEditor) {
                if let profile = model.profile {
                    ProfileEditSheet(profile: profile) { input in
                        let saved = await model.saveProfile(input)
                        if saved { showingEditor = false }
                        return saved
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $selectedPeople) { kind in
                PeopleListSheet(api: api, session: session, userID: model.profile?.id ?? 0, kind: kind)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Профиль", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("Закрыть", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func profileHeader(_ profile: APIProfile) -> some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                if let url = URL(string: profile.coverUrl), !profile.coverUrl.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(height: 116)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.55), Color(uiColor: .secondarySystemBackground)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 116)
                }

                avatarView(profile.avatarUrl)
                    .padding(.leading, 18)
                    .offset(y: 34)
            }
            .padding(.bottom, 30)

            VStack(alignment: .leading, spacing: 7) {
                Text(profile.displayName.isEmpty ? profile.username : profile.displayName)
                    .font(.title2.weight(.bold))
                Text("@\(profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !profile.location.isEmpty {
                    Label(profile.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let url = URL(string: profile.website), !profile.website.isEmpty {
                    Link(profile.website, destination: url)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)

            HStack(spacing: 0) {
                ProfileStat(value: profile.posts, label: "Публикации")
                Spacer(minLength: 6)
                Button {
                    selectedPeople = .followers
                } label: {
                    ProfileStat(value: profile.followers, label: "Подписчики")
                }
                .buttonStyle(.plain)
                Spacer(minLength: 6)
                Button {
                    selectedPeople = .following
                } label: {
                    ProfileStat(value: profile.following, label: "Подписки")
                }
                .buttonStyle(.plain)
                Spacer(minLength: 6)
                ProfileStat(value: profile.likes, label: "Лайки")
            }
            .padding(.horizontal, 18)

            if !profile.isMe {
                Button {
                    Task { await model.toggleFollow() }
                } label: {
                    Text(profile.followed ? "Отписаться" : "Подписаться")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func avatarView(_ urlString: String) -> some View {
        if let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 76, height: 76)
            .clipShape(Circle())
            .overlay(Circle().stroke(.background, lineWidth: 4))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .symbolRenderingMode(.hierarchical)
                .frame(width: 76, height: 76)
                .background(.background, in: Circle())
                .overlay(Circle().stroke(.background, lineWidth: 4))
        }
    }
}

private struct ProfileStat: View {
    let value: Int64
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value.formatted())
                .font(.headline.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 54)
    }
}

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var bio: String
    @State private var avatarUrl: String
    @State private var coverUrl: String
    @State private var website: String
    @State private var location: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSave: (UpdateProfileRequest) async -> Bool

    init(profile: APIProfile, onSave: @escaping (UpdateProfileRequest) async -> Bool) {
        _displayName = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio)
        _avatarUrl = State(initialValue: profile.avatarUrl)
        _coverUrl = State(initialValue: profile.coverUrl)
        _website = State(initialValue: profile.website)
        _location = State(initialValue: profile.location)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Имя", text: $displayName)
                    TextField("О себе", text: $bio, axis: .vertical)
                        .lineLimit(2...5)
                    Text("\(bio.utf8.count) / 160 байт")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("Изображения по URL") {
                    TextField("URL аватара", text: $avatarUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("URL обложки", text: $coverUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                Section("Дополнительно") {
                    TextField("Сайт", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Город", text: $location)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            isSaving = true
                            let input = UpdateProfileRequest(
                                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                                avatarUrl: avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                                coverUrl: coverUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                                website: website.trimmingCharacters(in: .whitespacesAndNewlines),
                                location: location.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            let saved = await onSave(input)
                            isSaving = false
                            if saved { dismiss() }
                            else { errorMessage = "Не удалось сохранить профиль. Проверьте ограничения полей и подключение." }
                        }
                    }
                    .disabled(
                        isSaving
                        || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || displayName.utf8.count > 64
                        || bio.utf8.count > 160
                        || avatarUrl.utf8.count > 2048
                        || coverUrl.utf8.count > 2048
                        || website.utf8.count > 255
                        || location.utf8.count > 100
                    )
                }
            }
            .overlay {
                if isSaving {
                    ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}

private enum PeopleListKind: String, Identifiable, Equatable {
    case followers
    case following

    var id: String { rawValue }
    var title: String { self == .followers ? "Подписчики" : "Подписки" }
}

@MainActor
private struct PeopleListSheet: View {
    let api: APIClient
    let session: SessionStore
    let userID: Int64
    let kind: PeopleListKind
    @State private var people: [APIPerson] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(people) { person in
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.displayName.isEmpty ? person.username : person.displayName)
                        .font(.subheadline.weight(.medium))
                    Text("@\(person.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView("Ошибка загрузки", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if people.isEmpty {
                    ContentUnavailableView("Список пуст", systemImage: "person.2")
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
        }
    }

    private func load() async {
        guard let token = session.accessToken else {
            errorMessage = "Сессия завершена."
            isLoading = false
            return
        }
        do {
            people = try await api.followers(userID: userID, following: kind == .following, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
