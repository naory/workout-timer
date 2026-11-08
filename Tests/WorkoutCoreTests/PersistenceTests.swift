import Foundation
import Testing
@testable import WorkoutCore

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("wt-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Suite struct PersistenceTests {
    @Test func missingFileGivesSample() {
        let f = WorkoutFile(url: tempDir().appendingPathComponent("sub/workouts.json"))
        let loaded = f.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].name == Workout.sample.name)
    }

    @Test func roundTrip() throws {
        let url = tempDir().appendingPathComponent("nested/workouts.json")
        let f = WorkoutFile(url: url)
        let ws = [Workout.sample, Workout(name: "Two", sets: [.makeDefault()])]
        try f.save(ws)
        #expect(f.load() == ws)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("\"version\" : 1"))
    }

    @Test func corruptFileIsBackedUp() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("workouts.json")
        try "{nope".write(to: url, atomically: true, encoding: .utf8)
        let loaded = WorkoutFile(url: url).load()
        #expect(loaded.map(\.name) == [Workout.sample.name])
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("workouts.corrupt-") && $0.hasSuffix(".json") }
        #expect(backups.count == 1)
        let backup = try String(contentsOf: dir.appendingPathComponent(backups[0]), encoding: .utf8)
        #expect(backup == "{nope")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func loadNormalizes() throws {
        let url = tempDir().appendingPathComponent("workouts.json")
        var w = Workout.sample
        w.sets[0].workSeconds = 0
        try WorkoutFile(url: url).save([w])
        #expect(WorkoutFile(url: url).load()[0].sets[0].workSeconds == 1)
    }

    @Test func emptyListRespected() throws {
        let url = tempDir().appendingPathComponent("workouts.json")
        try WorkoutFile(url: url).save([])
        #expect(WorkoutFile(url: url).load() == [])
    }

    @Test func unreadableFileIsMovedAsideNotOverwritten() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("workouts.json")
        try WorkoutFile(url: url).save([Workout(name: "Mine", sets: [.makeDefault()])])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        let f = WorkoutFile(url: url)
        #expect(f.load().map(\.name) == [Workout.sample.name])
        try f.save([Workout.sample])
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("workouts.corrupt-") }
        #expect(backups.count == 1)
    }

    @Test func defaultURLLocation() {
        #expect(WorkoutFile.defaultURL.path.hasSuffix("Application Support/WorkoutTimer/workouts.json"))
    }
}
