import AppKit
import Observation
import SwiftUI
import WorkoutCore

/// Owns the workout list and persists it shortly after every change.
@MainActor @Observable
final class WorkoutStore {
    var workouts: [Workout] {
        didSet { scheduleSave() }
    }
    private(set) var saveError: String?

    @ObservationIgnored private let file: WorkoutFile
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(file: WorkoutFile = WorkoutFile(url: WorkoutFile.defaultURL)) {
        self.file = file
        self.workouts = file.load()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    @discardableResult
    func add() -> Workout.ID {
        let w = Workout(name: "New Workout", sets: [WorkoutSet.makeDefault()])
        workouts.append(w)
        return w.id
    }

    @discardableResult
    func duplicate(_ id: Workout.ID) -> Workout.ID? {
        guard let i = workouts.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = workouts[i]
        copy.id = UUID()
        copy.name += " copy"
        copy.sets = copy.sets.map { set in
            var s = set
            s.id = UUID()
            s.exercises = s.exercises.map { Exercise(name: $0.name) }
            return s
        }
        workouts.insert(copy, at: i + 1)
        return copy.id
    }

    func delete(_ id: Workout.ID) {
        workouts.removeAll { $0.id == id }
    }

    /// A binding that stays safe if the workout disappears: reads fall back to the last value, writes are dropped.
    func binding(for id: Workout.ID) -> Binding<Workout>? {
        guard let current = workouts.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in self?.workouts.first(where: { $0.id == id }) ?? current },
            set: { [weak self] new in self?.workouts.update(id: id) { $0 = new } }
        )
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try file.save(workouts)
            saveError = nil
        } catch {
            saveError = "Couldn't save workouts: \(error.localizedDescription)"
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
}
