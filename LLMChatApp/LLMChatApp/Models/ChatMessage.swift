import Foundation

struct ChatMessage: Identifiable, Hashable {
    enum Role {
        case user
        case assistant
        case system

        var displayName: String {
            switch self {
            case .user: return "Вы"
            case .assistant: return "LLM"
            case .system: return "Система"
            }
        }

        var bubbleAlignment: HorizontalAlignment {
            switch self {
            case .user: return .trailing
            default: return .leading
            }
        }
    }

    let id: UUID
    let role: Role
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
