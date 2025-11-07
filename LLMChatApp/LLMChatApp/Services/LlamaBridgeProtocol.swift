import Foundation

protocol LlamaBridgeProtocol {
    func loadModel(at url: URL) async throws
    func generateResponse(prompt: String, settings: GenerationSettings) async throws -> String
    func cancelGeneration()
}

final class PreviewLlamaBridge: LlamaBridgeProtocol {
    func loadModel(at url: URL) async throws {}

    func generateResponse(prompt: String, settings: GenerationSettings) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        return "Пример ответа на запрос: \(prompt)"
    }

    func cancelGeneration() {}
}
