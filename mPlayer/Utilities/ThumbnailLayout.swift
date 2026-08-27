import CoreGraphics

enum ThumbnailLayout {
    static let minThumbnail: CGFloat = 80
    static let cellPadding: CGFloat = 4
    static let gridPadding: CGFloat = 10
    static let spacing: CGFloat = 8
    static let minColumns = 2
    static let hideNameSize: CGFloat = 136
    static let maxSidebarWidth: CGFloat = 640

    static var minCell: CGFloat { minThumbnail + cellPadding * 2 }

    static var minSidebarWidth: CGFloat {
        gridPadding * 2
            + CGFloat(minColumns) * minCell
            + CGFloat(minColumns - 1) * spacing
    }

    static var idealSidebarWidth: CGFloat {
        gridPadding * 2 + 3 * minCell + 2 * spacing
    }

    static var sidebarWidthRange: ClosedRange<CGFloat> {
        minSidebarWidth...maxSidebarWidth
    }

    static func metrics(columnWidth: CGFloat, sizeT: CGFloat) -> (thumbWidth: CGFloat, columns: Int) {
        let available = max(minCell, columnWidth - gridPadding * 2)
        let t = min(max(sizeT, 0), 1)
        let maxColumns = max(
            1,
            Int(floor((available + spacing) / (minCell + spacing)))
        )
        let columns = max(1, Int(round(CGFloat(maxColumns) - t * CGFloat(maxColumns - 1))))
        let cellOuter = (available - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let thumbWidth = max(minThumbnail, cellOuter - cellPadding * 2)
        return (thumbWidth, columns)
    }
}
