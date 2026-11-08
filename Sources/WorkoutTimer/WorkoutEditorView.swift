import SwiftUI
import WorkoutCore

struct WorkoutEditorView: View {
    @Binding var workout: Workout
    let onStart: (Workout) -> Void

    @State private var setPendingDelete: WorkoutSet.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    TextField("Workout name", text: $workout.name)
                        .textFieldStyle(.plain)
                        .font(.largeTitle.bold())
                    Spacer()
                    Text("Total \(DurationFormat.format(Timeline.build(workout).totalDuration))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(workout.sets.enumerated()), id: \.element.id) { offset, set in
                    SetEditorView(
                        set: setBinding(set.id, fallback: set),
                        number: offset + 1,
                        canMoveUp: offset > 0,
                        canMoveDown: offset < workout.sets.count - 1,
                        canDelete: workout.sets.count > 1,
                        onMove: { moveSet(set.id, by: $0) },
                        onDuplicate: { duplicateSet(set.id) },
                        onDelete: { setPendingDelete = set.id }
                    )
                }

                Button(action: addSet) {
                    Label("Add set", systemImage: "plus.rectangle.on.rectangle")
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onStart(workout.normalized())
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .help("Start workout (⌘↩)")
            }
        }
        .confirmationDialog(
            "Delete this set?",
            isPresented: Binding(get: { setPendingDelete != nil }, set: { if !$0 { setPendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = setPendingDelete, workout.sets.count > 1 {
                    workout.sets.removeAll { $0.id == id }
                }
                setPendingDelete = nil
            }
        }
    }

    private func setBinding(_ id: WorkoutSet.ID, fallback: WorkoutSet) -> Binding<WorkoutSet> {
        Binding(
            get: { workout.sets.first { $0.id == id } ?? fallback },
            set: { new in workout.sets.update(id: id) { $0 = new } }
        )
    }

    private func addSet() {
        let last = workout.sets.last
        workout.sets.append(WorkoutSet.makeDefault(
            name: "Set \(workout.sets.count + 1)",
            workSeconds: last?.workSeconds ?? 30,
            restSeconds: last?.restSeconds ?? 30))
    }

    private func duplicateSet(_ id: WorkoutSet.ID) {
        guard let i = workout.sets.firstIndex(where: { $0.id == id }) else { return }
        var copy = workout.sets[i]
        copy.id = UUID()
        copy.exercises = copy.exercises.map { Exercise(name: $0.name) }
        workout.sets.insert(copy, at: i + 1)
    }

    private func moveSet(_ id: WorkoutSet.ID, by delta: Int) {
        guard let i = workout.sets.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard workout.sets.indices.contains(j) else { return }
        workout.sets.swapAt(i, j)
    }
}
