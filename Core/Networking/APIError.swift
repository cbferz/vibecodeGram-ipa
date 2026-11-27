import Foundation

enum APIError: Error, LocalizedError, Sendable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(String)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Некорректный адрес сервера."
        case .invalidResponse:
            return "Сервер вернул некорректный ответ."
        case let .httpStatus(code, message):
            return message.isEmpty ? "Ошибка сервера (HTTP \(code))." : message
        case let .decoding(message):
            return "Не удалось обработать ответ сервера: \(message)"
        case .missingToken:
            return "Сессия не найдена. Войдите в аккаунт."
        }
    }

    var isUnauthorized: Bool {
        if case let .httpStatus(code, _) = self {
            return code == 401
        }
        return false
    }
}
