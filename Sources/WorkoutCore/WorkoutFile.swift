import Foundation

/// Reads and writes the user's workouts as JSON. Never throws on load and never destroys
/// an unreadable file: it is renamed aside so the user's data can be recovered.
public struct WorkoutFile: Sendable {
    private struct Envelope: Codable {
        var version: Int
        var workouts: [Workout]
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WorkoutTimer/workouts.json")
    }

    public func load() -> [Workout] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [Workout.sample] }
        guard let data = try? Data(contentsOf: url) else {
            // Exists but unreadable: move it aside so a later save can't overwrite it.
            backUpUnreadableFile()
            return [Workout.sample]
        }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).workouts.map { $0.normalized() }
        } catch {
            backUpUnreadableFile()
            return [Workout.sample]
        }
    }

    public func save(_ workouts: [Workout]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: 1, workouts: workouts))
        try data.write(to: url, options: .atomic)
    }

    private func backUpUnreadableFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        var backup = url.deletingLastPathComponent().appendingPathComponent("workouts.corrupt-\(stamp).json")
        var n = 1
        while FileManager.default.fileExists(atPath: backup.path) {
            backup = url.deletingLastPathComponent().appendingPathComponent("workouts.corrupt-\(stamp)-\(n).json")
            n += 1
        }
        try? FileManager.default.moveItem(at: url, to: backup)
    }
}
