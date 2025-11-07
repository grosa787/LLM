import Foundation
import Combine

@MainActor
final class ModelDownloadManager: ObservableObject {
    struct DownloadedModel: Identifiable, Hashable {
        let id = UUID()
        let fileURL: URL

        var displayName: String {
            fileURL.deletingPathExtension().lastPathComponent
        }
    }

    enum DownloadError: Error, LocalizedError {
        case invalidURL
        case downloadFailed
        case fileMoveFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Некорректный URL."
            case .downloadFailed:
                return "Не удалось скачать модель."
            case .fileMoveFailed:
                return "Не удалось сохранить файл модели."
            }
        }
    }

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var availableModels: [DownloadedModel] = []
    @Published var lastError: DownloadError?

    private var downloadTask: URLSessionDownloadTask?
    private var progressCancellable: AnyCancellable?
    private let fileManager = FileManager.default
    private let isPreview: Bool

    init(previewMode: Bool = false) {
        self.isPreview = previewMode
        refreshDownloadedModels()
    }

    func refreshDownloadedModels() {
        guard let modelsDirectory = try? modelsDirectoryURL() else { return }
        let urls = (try? fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)) ?? []
        availableModels = urls.map { DownloadedModel(fileURL: $0) }.sorted { $0.displayName < $1.displayName }
    }

    func downloadModel(from urlString: String) {
        guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            lastError = .invalidURL
            return
        }

        if !url.lastPathComponent.lowercased().hasSuffix(".gguf") {
            lastError = .invalidURL
            return
        }

        guard !isPreview else {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PreviewModel.gguf")
            try? "demo".data(using: .utf8)?.write(to: tempURL)
            availableModels.append(DownloadedModel(fileURL: tempURL))
            return
        }

        isDownloading = true
        downloadProgress = 0
        lastError = nil

        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)

        downloadTask = session.downloadTask(with: request) { [weak self] tempURL, _, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isDownloading = false
                self.progressCancellable?.cancel()

                if let error = error {
                    print("Download failed: \(error)")
                    self.lastError = .downloadFailed
                    return
                }

                guard let tempURL = tempURL else {
                    self.lastError = .downloadFailed
                    return
                }

                do {
                    let destinationURL = try self.persistedURL(for: url)
                    try? self.fileManager.removeItem(at: destinationURL)
                    try self.fileManager.moveItem(at: tempURL, to: destinationURL)
                    self.refreshDownloadedModels()
                } catch {
                    self.lastError = .fileMoveFailed
                }
            }
        }

        if let progress = downloadTask?.progress {
            progressCancellable = progress.publisher(for: \Progress.fractionCompleted)
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.downloadProgress = value
                }
        }

        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressCancellable?.cancel()
        progressCancellable = nil
        isDownloading = false
    }

    private func modelsDirectoryURL() throws -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let modelsURL = documentsURL.appendingPathComponent("Models", isDirectory: true)
        if !fileManager.fileExists(atPath: modelsURL.path) {
            try fileManager.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        }
        return modelsURL
    }

    private func persistedURL(for sourceURL: URL) throws -> URL {
        let fileName = sourceURL.lastPathComponent
        return try modelsDirectoryURL().appendingPathComponent(fileName, isDirectory: false)
    }
}
