import SwiftUI

@MainActor
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SearchViewModel
    @State private var query = ""
    @State private var selectedPerson: APIPerson?
    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
        _model = StateObject(wrappedValue: SearchViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            List {
                if model.isSearching {
                    ProgressView("Поиск…")
                        .frame(maxWidth: .infinity)
                }

                if !model.people.isEmpty {
                    Section("Пользователи") {
                        ForEach(model.people) { person in
                            Button {
                                selectedPerson = person
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.displayName.isEmpty ? person.username : person.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("@\(person.username)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if !model.posts.isEmpty {
                    Section("Публикации") {
                        ForEach(model.posts) { post in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("@\(post.username)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(post.body)
                                    .font(.subheadline)
                                HStack {
                                    Label(post.likes.formatted(), systemImage: "heart")
                                    if post.contentKind == "reel" {
                                        Label("vibee", systemImage: "play.rectangle")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !model.isSearching && model.people.isEmpty && model.posts.isEmpty {
                    ContentUnavailableView(
                        query.count >= 2 ? "Ничего не найдено" : "Поиск",
                        systemImage: "magnifyingglass",
                        description: Text(query.count >= 2 ? "Попробуйте изменить запрос." : "Введите минимум два символа и нажмите «Найти».")
                    )
                }
            }
            .searchable(text: $query, prompt: "Пользователи и публикации")
            .onSubmit(of: .search) {
                Task { await model.search(query) }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Найти") {
                        Task { await model.search(query) }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || model.isSearching)
                }
            }
            .sheet(item: $selectedPerson) { person in
                ProfileView(api: api, session: session, userID: person.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Поиск", isPresented: Binding(
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
