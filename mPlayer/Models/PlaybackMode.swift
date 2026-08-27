import Foundation

enum PlaybackMode: String, CaseIterable, Identifiable {
    case sequential
    case loopAll
    case loopOne

    var id: String { rawValue }

    mutating func cycle() {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        self = all[(index + 1) % all.count]
    }

    var systemImage: String {
        switch self {
        case .sequential:
            return "play.square.stack"
        case .loopAll:
            return "repeat"
        case .loopOne:
            return "repeat.1"
        }
    }

    var help: String {
        switch self {
        case .sequential:
            return "连接播放：播完自动下一首，到列表末尾停止"
        case .loopAll:
            return "循环：列表循环播放"
        case .loopOne:
            return "单个循环：重复播放当前文件"
        }
    }
}
