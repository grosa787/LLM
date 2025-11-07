import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var downloadManager: ModelDownloadManager
    @EnvironmentObject private var llamaManager: LLMManager
    @EnvironmentObject private var appState: AppState

    @State private var modelURLString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Параметры генерации") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature: \(settingsStore.temperature, specifier: "%.2f")")
                            Spacer()
                        }
                        Slider(value: $settingsStore.temperature, in: 0...2, step: 0.05)
                    }

                    Stepper(value: $settingsStore.maxTokens, in: 64...4096, step: 64) {
                        Text("Max tokens: \(settingsStore.maxTokens)")
                    }
                }

                Section("Загрузка модели") {
                    TextField("URL модели (.gguf)", text: $modelURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if downloadManager.isDownloading {
                        VStack(alignment: .leading) {
                            ProgressView(value: downloadManager.downloadProgress)
                            Text("Прогресс: \(Int(downloadManager.downloadProgress * 100))%")
                                .font(.caption)
                        }
                    }

                    HStack {
                        Button("Скачать модель") {
                            downloadManager.downloadModel(from: modelURLString)
                        }
                        .disabled(modelURLString.isEmpty || downloadManager.isDownloading)

                        if downloadManager.isDownloading {
                            Button("Отменить") {
                                downloadManager.cancelDownload()
                            }
                            .foregroundColor(.red)
                        }
                    }

                    if let error = downloadManager.lastError {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section("Доступные модели") {
                    if downloadManager.availableModels.isEmpty {
                        Text("Пока нет загруженных моделей")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(downloadManager.availableModels) { model in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                        .font(.headline)
                                    Text(model.fileURL.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Запустить модель") {
                                    Task {
                                        let success = await llamaManager.loadModel(from: model.fileURL, settingsStore: settingsStore)
                                        if success {
                                            appState.presentChatModeSelection()
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if case let .failed(message) = llamaManager.activeLLMState {
                    Section("Состояние модели") {
                        Text("Ошибка: \(message)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Настройки")
            .onAppear {
                downloadManager.refreshDownloadedModels()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsStore(previewMode: true))
            .environmentObject(ModelDownloadManager(previewMode: true))
            .environmentObject(LLMManager(previewMode: true))
            .environmentObject(AppState())
    }
}
