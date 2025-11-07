import Foundation

extension OpaquePointer: @unchecked Sendable {}

final class LlamaBridge: LlamaBridgeProtocol {
    private let queue = DispatchQueue(label: "com.llmchatapp.llamabridge", qos: .userInitiated)
    private var context: OpaquePointer?

    func loadModel(at url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    self.unloadModelIfNeededLocked()
                    guard let handle = llama_create_context(url.path) else {
                        throw LLMError.loadFailed("Не удалось создать контекст llama.cpp")
                    }
                    self.context = handle
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func generateResponse(prompt: String, settings: GenerationSettings) async throws -> String {
        guard let context else { throw LLMError.modelNotReady }
        let contextHandle = context

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let response = try llama_generate(contextHandle, prompt, settings.temperature, Int32(settings.maxTokens))
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancelGeneration() {
        llama_cancel()
    }

    private func unloadModelIfNeededLocked() {
        if let context {
            llama_destroy_context(context)
            self.context = nil
        }
    }

    deinit {
        queue.sync {
            unloadModelIfNeededLocked()
        }
    }
}

extension LlamaBridge: @unchecked Sendable {}

// MARK: - Bridged C API

private func llama_create_context(_ modelPath: String) -> OpaquePointer? {
    guard let pointer = modelPath.cString(using: .utf8) else { return nil }
    return pointer.withUnsafeBufferPointer { buffer -> OpaquePointer? in
        guard let baseAddress = buffer.baseAddress else { return nil }
        guard let contextRef = llama_create_context_from_model_path(baseAddress) else { return nil }
        return OpaquePointer(contextRef)
    }
}

private func llama_generate(_ context: OpaquePointer, _ prompt: String, _ temperature: Double, _ maxTokens: Int32) throws -> String {
    guard let promptPtr = prompt.cString(using: .utf8) else {
        throw LLMError.loadFailed("Некорректный промпт")
    }

    return promptPtr.withUnsafeBufferPointer { buffer -> String in
        guard let baseAddress = buffer.baseAddress else { return "" }
        let responsePtr = llama_generate_response(UnsafeMutableRawPointer(context), baseAddress, temperature, Int(maxTokens))
        guard let responsePtr else { return "" }
        return String(cString: responsePtr)
    }
}

private func llama_destroy_context(_ context: OpaquePointer) {
    llama_free_context(UnsafeMutableRawPointer(context))
}
