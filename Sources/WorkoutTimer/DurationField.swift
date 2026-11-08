import SwiftUI
import WorkoutCore

/// Edits a duration in seconds. Accepts "45" or "1:30"; invalid text reverts, values are clamped.
struct DurationField: View {
    let title: String
    @Binding var seconds: Int

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            TextField(title, text: $text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
            Stepper(title, value: clampedSeconds, in: Limits.seconds, step: 5)
                .labelsHidden()
        }
        .onAppear { text = DurationFormat.format(seconds) }
        .onChange(of: seconds) { _, new in text = DurationFormat.format(new) }
    }

    private var clampedSeconds: Binding<Int> {
        Binding(get: { seconds }, set: { seconds = Limits.clamp($0, Limits.seconds) })
    }

    private func commit() {
        if let value = DurationFormat.parse(text) {
            seconds = value
        }
        text = DurationFormat.format(seconds)
    }
}
