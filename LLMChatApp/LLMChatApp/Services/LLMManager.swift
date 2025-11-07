import Foundation
import Combine

@MainActor
final class LLMManager: ObservableObject {
    enum LLMState: Equatable {
        case idle
        case loadingModel(String)
        case ready(model: URL)
        case failed(String)
    }

    @Published private(set) var activeLLMState: LLMState = .idle
    @Published private(set) var isGenerating: Bool = false

    private var inferenceTask: Task<Void, Never>?
    private let bridge: LlamaBridgeProtocol
    private let isPreview: Bool

    init(previewMode: Bool = false) {
        self.isPreview = previewMode
        if previewMode {
            self.bridge = PreviewLlamaBridge()
        } else {
            self.bridge = LlamaBridge()
        }
    }

    func restorePersistedState(settingsStore: SettingsStore) async {
        guard let modelURL = settingsStore.selectedModelPath else { return }
        _ = await loadModel(from: modelURL, settingsStore: settingsStore)
    }

    @discardableResult
    func loadModel(from url: URL, settingsStore: SettingsStore) async -> Bool {
        activeLLMState = .loadingModel(url.lastPathComponent)
        do {
            try await bridge.loadModel(at: url)
            settingsStore.selectedModelPath = url
            activeLLMState = .ready(model: url)
            return true
        } catch {
            activeLLMState = .failed(error.localizedDescription)
            return false
        }
    }

    func generateResponse(for prompt: String) async throws -> String {
        guard case .ready = activeLLMState else {
            throw LLMError.modelNotReady
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let settings = GenerationSettings(temperature: AppStateBinder.shared.settingsStore.temperature, maxTokens: AppStateBinder.shared.settingsStore.maxTokens)
            let response = try await bridge.generateResponse(prompt: prompt, settings: settings)
            return response
        } catch {
            activeLLMState = .failed(error.localizedDescription)
            throw error
        }
    }

    func stopGeneration() {
        inferenceTask?.cancel()
        bridge.cancelGeneration()
        isGenerating = false
    }
}

enum LLMError: LocalizedError {
    case modelNotReady
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "Модель не загружена"
        case .loadFailed(let reason):
            return reason
        }
    }
}

struct GenerationSettings {
    let temperature: Double
    let maxTokens: Int
}
