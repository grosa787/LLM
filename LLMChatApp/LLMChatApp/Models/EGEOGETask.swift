import Foundation

struct EGEOGETask: Identifiable, Hashable {
    let id = UUID()
    var condition: String = ""
    var question: String = ""
    var options: [String] = []
    var correctAnswer: String? = nil
    var additionalNotes: String = ""

    var isEmpty: Bool {
        condition.isEmpty && question.isEmpty && options.allSatisfy { $0.isEmpty } && (correctAnswer?.isEmpty ?? true)
    }
}

struct TaskElement: Identifiable, Hashable {
    enum ElementType: String, CaseIterable, Identifiable {
        case condition = "Условие"
        case question = "Вопрос"
        case options = "Варианты ответов"
        case correctAnswer = "Правильный ответ"
        case notes = "Подсказка"

        var id: String { rawValue }
    }

    let id = UUID()
    var type: ElementType
    var text: String

    init(type: ElementType, text: String = "") {
        self.type = type
        self.text = text
    }
}
