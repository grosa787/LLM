import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var llamaManager: LLMManager
    @StateObject private var viewModel = ChatViewModel(llamaManager: EnvironmentInjector.shared.llamaManager)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                messageBubble(for: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .onChange(of: viewModel.messages) { _, newMessages in
                        if let last = newMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    TextField("Введите сообщение", text: $viewModel.draftText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...6)

                    Button {
                        Task { await viewModel.send() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .padding(12)
                            .background(Color.accentColor, in: Circle())
                            .foregroundColor(.white)
                    }
                    .disabled(llamaManager.isGenerating)
                    .accessibilityIdentifier("sendButton")
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Чат")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Очистить", role: .destructive) {
                        viewModel.clearConversation()
                    }
                }
            }
            .alert(item: $viewModel.error) { error in
                Alert(title: Text("Ошибка"), message: Text(error.message), dismissButton: .default(Text("Ок")))
            }
        }
        .onAppear {
            viewModel.update(llamaManager: llamaManager)
        }
        .onChange(of: llamaManager.activeLLMState) { _, newValue in
            if case .idle = newValue {
                viewModel.clearConversation()
            }
        }
    }

    @ViewBuilder
    private func messageBubble(for message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.text)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .padding(12)
                .background(message.role == .user ? Color.accentColor.opacity(0.2) : Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(LLMManager(previewMode: true))
    }
}
