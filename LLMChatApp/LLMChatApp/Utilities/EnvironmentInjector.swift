import Foundation

/// Provides access to shared services for SwiftUI previews where EnvironmentObjects are unavailable.
final class EnvironmentInjector {
    static let shared = EnvironmentInjector()

    private(set) var llamaManager: LLMManager
    private(set) var settingsStore: SettingsStore
    private(set) var downloadManager: ModelDownloadManager

    private init() {
        let settingsStore = SettingsStore(previewMode: true)
        let downloadManager = ModelDownloadManager(previewMode: true)
        let llamaManager = LLMManager(previewMode: true)

        self.settingsStore = settingsStore
        self.downloadManager = downloadManager
        self.llamaManager = llamaManager
    }

    func configure(llamaManager: LLMManager, settingsStore: SettingsStore, downloadManager: ModelDownloadManager) {
        self.llamaManager = llamaManager
        self.settingsStore = settingsStore
        self.downloadManager = downloadManager
    }
}
