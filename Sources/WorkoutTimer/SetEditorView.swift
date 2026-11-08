import SwiftUI
import WorkoutCore

/// Editor for one set. All rows are addressed by id, never by array index, so deleting or
/// moving a row while another row's field is focused can't index out of range.
struct SetEditorView: View {
    @Binding var set: WorkoutSet
    let number: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canDelete: Bool
    let onMove: (Int) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                header
                timing
                Divider()
                ForEach(Array(set.exercises.enumerated()), id: \.element.id) { offset, exercise in
                    exerciseRow(exercise.id, position: offset)
                }
                Button {
                    set.exercises.append(Exercise(name: ""))
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(6)
        }
    }

    private var header: some View {
        HStack {
            Text("Set \(number)").font(.headline)
            TextField("Set name", text: $set.name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            Spacer()
            Button { onMove(-1) } label: { Image(systemName: "arrow.up") }
                .disabled(!canMoveUp).help("Move set up")
            Button { onMove(1) } label: { Image(systemName: "arrow.down") }
                .disabled(!canMoveDown).help("Move set down")
            Button(action: onDuplicate) { Image(systemName: "plus.square.on.square") }
                .help("Duplicate set")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .disabled(!canDelete).help("Delete set")
        }
        .buttonStyle(.borderless)
    }

    private var timing: some View {
        HStack(spacing: 20) {
            DurationField(title: "Work", seconds: $set.workSeconds)
            DurationField(title: "Rest", seconds: $set.restSeconds)
            HStack(spacing: 4) {
                Text("Repeat").foregroundStyle(.secondary)
                Text("×\(set.repeats)").monospacedDigit().frame(minWidth: 30, alignment: .trailing)
                Stepper("Repeat", value: $set.repeats, in: Limits.repeats).labelsHidden()
            }
        }
    }

    private func exerciseRow(_ id: Exercise.ID, position: Int) -> some View {
        HStack {
            Text("Round \(position + 1)")
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            TextField("Exercise \(position + 1)", text: nameBinding(id))
                .textFieldStyle(.roundedBorder)
            Button { moveExercise(id, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(position == 0)
            Button { moveExercise(id, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(position == set.exercises.count - 1)
            Button(role: .destructive) {
                set.exercises.removeAll { $0.id == id }
            } label: { Image(systemName: "minus.circle") }
                .disabled(set.exercises.count <= 1)
                .help("Remove exercise")
        }
        .buttonStyle(.borderless)
    }

    private func nameBinding(_ id: Exercise.ID) -> Binding<String> {
        Binding(
            get: { set.exercises.first { $0.id == id }?.name ?? "" },
            set: { new in set.exercises.update(id: id) { $0.name = new } }
        )
    }

    private func moveExercise(_ id: Exercise.ID, by delta: Int) {
        guard let i = set.exercises.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard set.exercises.indices.contains(j) else { return }
        set.exercises.swapAt(i, j)
    }
}
