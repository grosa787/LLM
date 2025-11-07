import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published var error: ChatError?

    private var llamaManager: LLMManager

    enum ChatError: Identifiable, Error {
        case emptyInput
        case generationFailed(String)

        var id: String {
            switch self {
            case .emptyInput: return "emptyInput"
            case .generationFailed: return "generationFailed"
            }
        }

        var message: String {
            switch self {
            case .emptyInput:
                return "Введите сообщение перед отправкой."
            case .generationFailed(let reason):
                return "Ошибка генерации ответа: \(reason)"
            }
        }
    }

    init(llamaManager: LLMManager) {
        self.llamaManager = llamaManager
    }

    func update(llamaManager: LLMManager) {
        self.llamaManager = llamaManager
    }

    func send() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = .emptyInput
            return
        }

        let userMessage = ChatMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        draftText = ""

        do {
            let response = try await llamaManager.generateResponse(for: trimmed)
            let assistantMessage = ChatMessage(role: .assistant, text: response)
            messages.append(assistantMessage)
        } catch {
            self.error = .generationFailed(error.localizedDescription)
        }
    }

    func clearConversation() {
        messages.removeAll()
    }
}
