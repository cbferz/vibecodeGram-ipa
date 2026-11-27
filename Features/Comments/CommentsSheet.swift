import SwiftUI

@MainActor
struct CommentsSheet: View {
    @StateObject private var model: CommentsViewModel
    @State private var message = ""
    @FocusState private var isFocused: Bool

    init(api: APIClient, session: SessionStore, postID: Int64) {
        _model = StateObject(wrappedValue: CommentsViewModel(api: api, session: session, postID: postID))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.isLoading && model.comments.isEmpty {
                            ProgressView().padding(.top, 30)
                        } else if model.comments.isEmpty {
                            ContentUnavailableView(
                                "Комментариев пока нет",
                                systemImage: "text.bubble",
                                description: Text("Будьте первым, кто оставит комментарий.")
                            )
                            .padding(.top, 24)
                        } else {
                            ForEach(model.comments) { comment in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(comment.displayName.isEmpty ? comment.username : comment.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        Text("@\(comment.username)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(comment.body)
                                        .font(.body)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(16)
                }

                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Написать комментарий…", text: $message, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                    Button {
                        Task {
                            let sent = await model.send(message)
                            if sent {
                                message = ""
                                isFocused = false
                            }
                        }
                    } label: {
                        if model.isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                        }
                    }
                    .disabled(model.isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.utf8.count > 2000)
                    .accessibilityLabel("Отправить комментарий")
                }
                .padding(12)
            }
            .navigationTitle("Комментарии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { isFocused = false }
                }
            }
            .task { await model.load() }
            .alert("Комментарии", isPresented: Binding(
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
