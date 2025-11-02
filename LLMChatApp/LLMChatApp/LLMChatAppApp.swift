import SwiftUI

@main
struct LLMChatAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var llamaManager = LLMManager()
    @StateObject private var downloadManager = ModelDownloadManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .environmentObject(llamaManager)
                .environmentObject(downloadManager)
                .task {
                    AppStateBinder.shared.settingsStore = settingsStore
                    EnvironmentInjector.shared.configure(llamaManager: llamaManager, settingsStore: settingsStore, downloadManager: downloadManager)
                    await llamaManager.restorePersistedState(settingsStore: settingsStore)
                }
        }
    }
}
