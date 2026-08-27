import SwiftUI

struct SidebarView: View {
    @Bindable var library: LibraryStore

    private let gridPadding: CGFloat = 10
    private let cellPadding: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if library.folderURL == nil {
                    ContentUnavailableView(
                        "未打开文件夹",
                        systemImage: "folder",
                        description: Text("点击工具栏中的「打开文件夹」以浏览媒体文件")
                    )
                } else if library.items.isEmpty {
                    ContentUnavailableView(
                        "没有可播放的文件",
                        systemImage: "film.stack",
                        description: Text("该文件夹中没有支持的视频或音频")
                    )
                } else {
                    mediaGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !library.items.isEmpty {
                thumbnailSizeSlider
            }
        }
        .navigationTitle(library.folderName ?? "资料库")
    }

    private var mediaGrid: some View {
        GeometryReader { geo in
            let available = max(80, geo.size.width - gridPadding * 2)
            let thumbWidth = min(library.thumbnailSize, max(64, available - cellPadding * 2))
            let columnMin = min(thumbWidth + cellPadding * 2, available)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: columnMin), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(library.items) { item in
                        Button {
                            library.selectedID = item.id
                        } label: {
                            MediaItemCell(
                                item: item,
                                thumbnailWidth: thumbWidth,
                                showsName: library.showsThumbnailNames,
                                isSelected: library.selectedID == item.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(gridPadding)
            }
        }
    }

    private var thumbnailSizeSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: $library.thumbnailSize,
                in: LibraryStore.thumbnailSizeRange
            )
            .controlSize(.small)
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .help("预览图大小")
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
