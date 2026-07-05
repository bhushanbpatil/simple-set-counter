//
//  DebouncedSearchField.swift
//  Simple Set Counter
//

import SwiftUI

struct DebouncedSearchField: View {
    let prompt: String
    @Binding var text: String
    @Binding var debouncedText: String

    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        TextField(prompt, text: $text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: text) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { return }
                    debouncedText = newValue
                }
            }
            .onAppear {
                debouncedText = text
            }
    }
}
