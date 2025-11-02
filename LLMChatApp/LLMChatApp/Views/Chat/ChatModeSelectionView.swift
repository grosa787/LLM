import SwiftUI

struct ChatModeSelectionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Button {
                    appState.select(chatMode: .standard)
                } label: {
                    Label("Обычный чат", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)
                }

                Button {
                    appState.select(chatMode: .special)
                } label: {
                    Label("Спец. чат", systemImage: "square.grid.2x2")
                        .font(.headline)
                }
            }
            .navigationTitle("Выбор режима")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        appState.showChatModeSelection = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ChatModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChatModeSelectionView()
            .environmentObject(AppState())
    }
}
