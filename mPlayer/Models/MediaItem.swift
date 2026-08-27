import Foundation

struct MediaItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case video
        case audio
    }

    let id: URL
    let url: URL
    let name: String
    let kind: Kind
    var duration: TimeInterval?

    init(url: URL, kind: Kind, duration: TimeInterval? = nil) {
        let standardized = url.standardizedFileURL
        self.id = standardized
        self.url = standardized
        self.name = url.deletingPathExtension().lastPathComponent
        self.kind = kind
        self.duration = duration
    }
}
