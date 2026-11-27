import Foundation
import Combine

@MainActor
final class AIToolsViewModel: ObservableObject {
    @Published private(set) var models: [AIModel] = []
    @Published var selectedModel = ""
    @Published private(set) var messages: [AIMessage] = []
    @Published private(set) var isLoadingModels = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func load() async {
        guard let token = session.accessToken, !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            models = try await api.aiModels(token: token)
            if !models.contains(where: { $0.id == selectedModel }) {
                selectedModel = models.first?.id ?? ""
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSending else { return }
        guard let token = session.accessToken else {
            errorMessage = "Сессия завершена."
            return
        }
        guard !selectedModel.isEmpty else {
            errorMessage = "Список моделей ИИ недоступен."
            return
        }

        isSending = true
        defer { isSending = false }
        let userMessage = AIMessage(role: "user", content: clean)
        messages.append(userMessage)
        let outbound = Array(messages.suffix(24))

        do {
            let response = try await api.aiChat(messages: outbound, model: selectedModel, token: token)
            messages.append(AIMessage(role: "assistant", content: response.reply))
            if messages.count > 24 {
                messages = Array(messages.suffix(24))
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runTool(
        tool: String,
        text: String,
        context: String,
        targetLanguage: String
    ) async -> String? {
        guard let token = session.accessToken else {
            errorMessage = "Сессия завершена."
            return nil
        }
        do {
            let response = try await api.aiTool(
                tool: tool,
                text: text,
                context: context,
                targetLanguage: targetLanguage,
                token: token
            )
            errorMessage = nil
            return response.reply
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
