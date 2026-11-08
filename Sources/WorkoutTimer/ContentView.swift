import SwiftUI
import WorkoutCore

struct ContentView: View {
    @Bindable var store: WorkoutStore
    let onStart: (Workout) -> Void

    @State private var selection: Workout.ID?
    @State private var pendingDelete: Workout.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.workouts) { workout in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name.isEmpty ? "Untitled" : workout.name)
                        Text(DurationFormat.format(Timeline.build(workout).totalDuration))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .tag(workout.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .toolbar {
                ToolbarItemGroup {
                    Button { selection = store.add() } label: { Label("New", systemImage: "plus") }
                        .help("New workout")
                    Button {
                        if let id = selection { selection = store.duplicate(id) }
                    } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        .disabled(selection == nil)
                        .help("Duplicate workout")
                    Button { pendingDelete = selection } label: { Label("Delete", systemImage: "trash") }
                        .disabled(selection == nil)
                        .help("Delete workout")
                }
            }
        } detail: {
            if let id = selection, let binding = store.binding(for: id) {
                WorkoutEditorView(workout: binding, onStart: onStart)
                    .id(id)
            } else {
                ContentUnavailableView("No workout selected", systemImage: "figure.run",
                                       description: Text("Pick a workout or create a new one."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = store.saveError {
                Text(error)
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.2))
            }
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDelete {
                    if selection == id { selection = nil }
                    store.delete(id)
                }
                pendingDelete = nil
            }
        }
        .onAppear {
            if selection == nil { selection = store.workouts.first?.id }
        }
    }
}
