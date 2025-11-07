import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    @Published var temperature: Double {
        didSet { persist() }
    }
    @Published var maxTokens: Int {
        didSet { persist() }
    }
    @Published var selectedModelPath: URL? {
        didSet { persist() }
    }

    private let temperatureKey = "llm.temperature"
    private let maxTokensKey = "llm.maxTokens"
    private let modelPathKey = "llm.modelPath"
    private let defaults: UserDefaults
    private let isPreview: Bool

    init(defaults: UserDefaults = .standard, previewMode: Bool = false) {
        self.defaults = defaults
        self.isPreview = previewMode
        let storedTemperature = defaults.object(forKey: temperatureKey) as? Double ?? 0.7
        let storedMaxTokens = defaults.object(forKey: maxTokensKey) as? Int ?? 512
        let storedModelPath = defaults.url(forKey: modelPathKey)

        temperature = storedTemperature
        maxTokens = storedMaxTokens
        selectedModelPath = storedModelPath
    }

    private func persist() {
        guard !isPreview else { return }
        defaults.set(temperature, forKey: temperatureKey)
        defaults.set(maxTokens, forKey: maxTokensKey)
        if let selectedModelPath {
            defaults.set(selectedModelPath, forKey: modelPathKey)
        } else {
            defaults.removeObject(forKey: modelPathKey)
        }
    }
}
