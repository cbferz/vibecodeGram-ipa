import SwiftUI

@MainActor
struct AIToolsView: View {
    @StateObject private var model: AIToolsViewModel
    @State private var draft = ""
    @State private var selectedTool: String?
    @FocusState private var isFocused: Bool

    init(api: APIClient, session: SessionStore) {
        _model = StateObject(wrappedValue: AIToolsViewModel(api: api, session: session))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !model.models.isEmpty {
                    HStack {
                        Text("Модель")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Модель", selection: $model.selectedModel) {
                            ForEach(model.models) { item in
                                Text(item.name).tag(item.id)
                            }
                        }
                        .labelsHidden()
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }

                if model.messages.isEmpty {
                    ContentUnavailableView(
                        "ИИ-помощник",
                        systemImage: "sparkles",
                        description: Text("Задайте вопрос или выберите один из инструментов.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(model.messages) { message in
                                    HStack {
                                        if message.role == "user" { Spacer(minLength: 44) }
                                        Text(message.content)
                                            .font(.body)
                                            .padding(13)
                                            .background(
                                                message.role == "user" ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground),
                                                in: RoundedRectangle(cornerRadius: 16)
                                            )
                                        if message.role == "assistant" { Spacer(minLength: 44) }
                                    }
                                    .id(message.id)
                                }
                            }
                            .padding(14)
                        }
                        .onChange(of: model.messages.count) { _, _ in
                            if let last = model.messages.last {
                                withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }

                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Сообщение ИИ…", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                    Button {
                        let text = draft
                        draft = ""
                        isFocused = false
                        Task { await model.send(text) }
                    } label: {
                        if model.isSending { ProgressView() }
                        else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)) }
                    }
                    .disabled(model.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Отправить запрос")
                }
                .padding(12)
            }
            .navigationTitle("ИИ-инструменты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Перевод") { selectedTool = "translate" }
                        Button("Суммаризация") { selectedTool = "summarize" }
                        Button("Переписать") { selectedTool = "rewrite" }
                        Button("Грамматика") { selectedTool = "grammar" }
                        Button("Пост для соцсети") { selectedTool = "post" }
                        Button("Варианты ответа") { selectedTool = "smart_reply" }
                        Button("Поиск по контексту") { selectedTool = "context_search" }
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .accessibilityLabel("Выбрать ИИ-инструмент")
                }
            }
            .task { await model.load() }
            .overlay {
                if model.isLoadingModels && model.models.isEmpty {
                    ProgressView("Загружаем модели…")
                }
            }
            .sheet(item: Binding(
                get: { selectedTool.map(AIToolSelection.init) },
                set: { selectedTool = $0?.tool }
            )) { selection in
                AIToolSheet(tool: selection.tool) { text, context, language in
                    await model.runTool(
                        tool: selection.tool,
                        text: text,
                        context: context,
                        targetLanguage: language
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("ИИ-инструменты", isPresented: Binding(
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

private struct AIToolSelection: Identifiable {
    let tool: String
    var id: String { tool }
}

@MainActor
private struct AIToolSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tool: String
    let onRun: (String, String, String) async -> String?
    @State private var input = ""
    @State private var context = ""
    @State private var targetLanguage = "Русский"
    @State private var result: String?
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if tool == "translate" {
                    Section("Язык перевода") {
                        TextField("Например, English", text: $targetLanguage)
                    }
                }
                Section("Текст") {
                    TextEditor(text: $input)
                        .frame(minHeight: 120)
                }
                if tool == "context_search" || tool == "smart_reply" {
                    Section("Контекст (необязательно)") {
                        TextEditor(text: $context)
                            .frame(minHeight: 90)
                    }
                }
                if let result {
                    Section("Результат") {
                        Text(result)
                            .textSelection(.enabled)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Запустить") {
                        Task {
                            isRunning = true
                            result = await onRun(input, context, targetLanguage)
                            isRunning = false
                            if result == nil { errorMessage = "Инструмент не выполнил запрос." }
                        }
                    }
                    .disabled(isRunning || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || input.utf8.count > 16000 || context.utf8.count > 12000)
                }
            }
            .overlay {
                if isRunning {
                    ProgressView("Обработка…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var title: String {
        switch tool {
        case "translate": return "Перевод"
        case "summarize": return "Суммаризация"
        case "rewrite": return "Переписать текст"
        case "grammar": return "Грамматика"
        case "post": return "Пост для соцсети"
        case "smart_reply": return "Варианты ответа"
        default: return "Поиск по контексту"
        }
    }
}
