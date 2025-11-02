import Foundation
import Combine

@MainActor
final class SpecialChatViewModel: ObservableObject {
    @Published var elements: [TaskElement] = [TaskElement(type: .condition)]
    @Published var generatedPrompt: String = ""
    @Published var response: String = ""
    @Published var parsedSolution: String = ""
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?

    private var llamaManager: LLMManager

    init(llamaManager: LLMManager) {
        self.llamaManager = llamaManager
    }

    func update(llamaManager: LLMManager) {
        self.llamaManager = llamaManager
    }

    func addElement(of type: TaskElement.ElementType) {
        elements.append(TaskElement(type: type))
    }

    func removeElement(_ element: TaskElement) {
        elements.removeAll { $0.id == element.id }
    }

    func generatePrompt() {
        let promptBuilder = PromptBuilder(elements: elements)
        generatedPrompt = promptBuilder.buildPrompt()
    }

    func sendToModel() async {
        guard !generatedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Сформируйте запрос перед отправкой."
            return
        }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let rawResponse = try await llamaManager.generateResponse(for: generatedPrompt)
            response = rawResponse
            parsedSolution = parseSolution(from: rawResponse)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseSolution(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let answerLine = trimmed.components(separatedBy: "\n").first(where: { $0.lowercased().contains("ответ") }) {
            return answerLine
        }

        if trimmed.contains("=") {
            return "Решение привело к равенству: \(trimmed)"
        }

        return "Пояснение: \(trimmed)"
    }
}

struct PromptBuilder {
    var elements: [TaskElement]

    func buildPrompt() -> String {
        var parts: [String] = ["Реши задачу формата ЕГЭ/ОГЭ по математике. Предоставь подробное объяснение шага за шагом."]

        for element in elements {
            guard !element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            switch element.type {
            case .condition:
                parts.append("Условие задачи: \(element.text)")
            case .question:
                parts.append("Вопрос: \(element.text)")
            case .options:
                parts.append("Варианты ответов: \(element.text)")
            case .correctAnswer:
                parts.append("Правильный ответ: \(element.text)")
            case .notes:
                parts.append("Дополнительные указания: \(element.text)")
            }
        }

        parts.append("Верни структурированный ответ с объяснением, итоговым ответом и проверкой.")
        return parts.joined(separator: "\n")
    }
}
