import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var llamaManager: LLMManager

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatView()
                .tabItem {
                    Label("Чат", systemImage: "message")
                }
                .tag(AppState.Tab.chat)

            SpecialChatView()
                .tabItem {
                    Label("Спец. Чат", systemImage: "square.grid.2x2")
                }
                .tag(AppState.Tab.specialChat)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(AppState.Tab.settings)
        }
        .sheet(isPresented: $appState.showChatModeSelection) {
            ChatModeSelectionView()
        }
        .overlay(alignment: .bottom) {
            if llamaManager.isGenerating {
                ProgressView("Модель генерирует ответ...")
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
            }
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(AppState())
            .environmentObject(LLMManager())
            .environmentObject(SettingsStore())
            .environmentObject(ModelDownloadManager())
    }
}
