import SwiftUI

struct TaskElementEditor: View {
    @Binding var element: TaskElement
    var onRemove: () -> Void

    @State private var options: [String] = [""]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(element.type.rawValue)
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            switch element.type {
            case .options:
                optionsEditor
            default:
                TextField("Введите текст", text: $element.text, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { syncOptionsIfNeeded() }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: element.type) { _ in syncOptionsIfNeeded() }
        .onChange(of: element.text) { _ in syncOptionsIfNeeded() }
        .onAppear { syncOptionsIfNeeded() }
    }

    private var optionsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                HStack {
                    TextField("Вариант ответа", text: Binding(
                        get: { index < options.count ? options[index] : "" },
                        set: { newValue in
                            if index < options.count {
                                options[index] = newValue
                            }
                            persistOptions()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button {
                        removeOption(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button {
                addOption()
            } label: {
                Label("Добавить вариант", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
        .onAppear { syncOptionsIfNeeded() }
    }

    private func syncOptionsIfNeeded() {
        let existing = element.text.split(separator: "\n").map(String.init)
        if existing.isEmpty {
            options = [""]
        } else {
            options = existing
        }
    }

    private func persistOptions() {
        element.text = options.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private func addOption() {
        options.append("")
        persistOptions()
    }

    private func removeOption(at index: Int) {
        guard options.indices.contains(index) else { return }
        options.remove(at: index)
        if options.isEmpty { options = [""] }
        persistOptions()
    }
}

struct TaskElementEditor_Previews: PreviewProvider {
    @State static var element = TaskElement(type: .question, text: "Сколько будет 2+2?")

    static var previews: some View {
        Form {
            TaskElementEditor(element: $element, onRemove: {})
        }
    }
}
