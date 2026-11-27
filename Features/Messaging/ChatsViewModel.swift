import Foundation
import Combine

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var conversations: [APIConversation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore

    init(api: APIClient, session: SessionStore) {
        self.api = api
        self.session = session
    }

    func load() async {
        guard let token = session.accessToken, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await api.conversations(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createDirect(with person: APIPerson) async -> APIConversation? {
        guard let token = session.accessToken else { return nil }
        do {
            let created = try await api.createConversation(
                kind: "direct",
                title: "",
                memberIDs: [person.id],
                token: token
            )
            await load()
            return conversations.first(where: { $0.id == created.id })
                ?? APIConversation(
                    id: created.id,
                    kind: created.kind,
                    title: person.displayName.isEmpty ? person.username : person.displayName,
                    createdAt: "",
                    lastMessage: "",
                    lastMessageAt: nil
                )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class ChatMessagesViewModel: ObservableObject {
    @Published private(set) var messages: [APIMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let api: APIClient
    private let session: SessionStore
    private let conversationID: Int64

    init(api: APIClient, session: SessionStore, conversationID: Int64) {
        self.api = api
        self.session = session
        self.conversationID = conversationID
    }

    func load() async {
        guard let token = session.accessToken, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.messages(conversationID: conversationID, limit: 100, token: token)
            messages = result.sorted { $0.id < $1.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(_ text: String) async -> Bool {
        guard let token = session.accessToken, !isSending else { return false }
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await api.sendMessage(conversationID: conversationID, body: text, token: token)
            let username = session.user?.username ?? ""
            messages.append(
                APIMessage(
                    id: sent.id,
                    senderId: sent.senderId,
                    username: username,
                    body: sent.body,
                    createdAt: sent.createdAt
                )
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
