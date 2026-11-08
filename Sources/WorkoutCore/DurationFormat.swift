import Foundation

public enum DurationFormat {
    /// "m:ss" for editor fields and totals.
    public static func format(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// Timer digits: whole seconds (rounded up) up to 60, "m:ss" above.
    public static func countdown(_ remaining: Double) -> String {
        let s = Int(max(remaining, 0).rounded(.up))
        return s <= 60 ? "\(s)" : format(s)
    }

    /// Accepts "45" or "1:30"; returns nil for anything else. Valid values are clamped to `Limits.seconds`.
    public static func parse(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        let numbers = parts.map { $0.allSatisfy(\.isASCII) && !$0.isEmpty ? Int($0) : nil }
        guard numbers.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        let n = numbers.map { $0! }
        let total: Int
        switch n.count {
        case 1: total = n[0]
        case 2 where n[1] < 60:
            // Cap minutes before multiplying so absurd input clamps instead of overflowing.
            total = min(n[0], Limits.seconds.upperBound) * 60 + n[1]
        default: return nil
        }
        return Limits.clamp(total, Limits.seconds)
    }
}
