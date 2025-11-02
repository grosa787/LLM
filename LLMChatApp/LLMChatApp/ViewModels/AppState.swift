import SwiftUI

final class AppState: ObservableObject {
    enum Tab: Hashable {
        case chat
        case specialChat
        case settings
    }

    enum ChatMode {
        case standard
        case special
    }

    @Published var selectedTab: Tab = .chat
    @Published var showChatModeSelection: Bool = false
    @Published var activeChatMode: ChatMode? = .standard

    func presentChatModeSelection() {
        showChatModeSelection = true
    }

    func select(chatMode: ChatMode) {
        activeChatMode = chatMode
        switch chatMode {
        case .standard:
            selectedTab = .chat
        case .special:
            selectedTab = .specialChat
        }
        showChatModeSelection = false
    }
}
