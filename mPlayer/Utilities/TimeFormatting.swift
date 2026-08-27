import Foundation

enum TimeFormatting {
    static func duration(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "--:--" }
        let total = Int(time.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func position(_ current: TimeInterval, duration: TimeInterval) -> String {
        "\(Self.duration(current)) / \(Self.duration(duration))"
    }
}
