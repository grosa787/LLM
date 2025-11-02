import SwiftUI

struct SpecialChatView: View {
    @EnvironmentObject private var llamaManager: LLMManager
    @StateObject private var viewModel = SpecialChatViewModel(llamaManager: EnvironmentInjector.shared.llamaManager)

    var body: some View {
        NavigationStack {
            Form {
                Section("Конструктор задачи") {
                    ForEach(viewModel.elements) { element in
                        TaskElementEditor(element: binding(for: element)) {
                            viewModel.removeElement(element)
                        }
                    }

                    Menu("Добавить элемент") {
                        ForEach(TaskElement.ElementType.allCases) { elementType in
                            Button(elementType.rawValue) {
                                viewModel.addElement(of: elementType)
                            }
                        }
                    }
                }

                Section("Запрос для модели") {
                    TextEditor(text: $viewModel.generatedPrompt)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        .accessibilityIdentifier("promptEditor")

                    HStack {
                        Button("Сгенерировать запрос") {
                            viewModel.generatePrompt()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Отправить в модель") {
                            Task { await viewModel.sendToModel() }
                        }
                        .disabled(llamaManager.isGenerating || viewModel.generatedPrompt.isEmpty)
                    }
                }

                if !viewModel.response.isEmpty {
                    Section("Ответ модели") {
                        Text(viewModel.response)
                            .font(.callout)
                    }
                }

                if !viewModel.parsedSolution.isEmpty {
                    Section("Объяснение") {
                        Text(viewModel.parsedSolution)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Спец. чат")
            .alert(isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Alert(title: Text("Ошибка"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("Понятно")))
            }
            .overlay {
                if viewModel.isGenerating {
                    ProgressView("Модель готовит решение...")
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            viewModel.update(llamaManager: llamaManager)
        }
        .onChange(of: llamaManager.activeLLMState) { _, newValue in
            if case .idle = newValue {
                viewModel.elements = [TaskElement(type: .condition)]
                viewModel.generatedPrompt = ""
                viewModel.response = ""
                viewModel.parsedSolution = ""
            }
        }
    }

    private func binding(for element: TaskElement) -> Binding<TaskElement> {
        guard let index = viewModel.elements.firstIndex(where: { $0.id == element.id }) else {
            fatalError("Element not found")
        }
        return $viewModel.elements[index]
    }
}

struct SpecialChatView_Previews: PreviewProvider {
    static var previews: some View {
        SpecialChatView()
            .environmentObject(LLMManager(previewMode: true))
    }
}
