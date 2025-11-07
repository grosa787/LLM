import Foundation

@MainActor
final class AppStateBinder {
    static let shared = AppStateBinder()

    var settingsStore: SettingsStore = SettingsStore(previewMode: true)

    private init() {}
}
