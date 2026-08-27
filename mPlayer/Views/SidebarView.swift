import SwiftUI

struct SidebarView: View {
    @Bindable var library: LibraryStore
    var columnWidth: CGFloat

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
    }

    private var mediaGrid: some View {
        let metrics = ThumbnailLayout.metrics(
            columnWidth: columnWidth,
            sizeT: library.thumbnailSizeT
        )
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: ThumbnailLayout.spacing),
            count: metrics.columns
        )

        return ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: ThumbnailLayout.spacing) {
                ForEach(library.items) { item in
                    Button {
                        library.selectedID = item.id
                    } label: {
                        MediaItemCell(
                            item: item,
                            thumbnailWidth: metrics.thumbWidth,
                            showsName: metrics.thumbWidth < ThumbnailLayout.hideNameSize,
                            isSelected: library.selectedID == item.id
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
            }
            .padding(ThumbnailLayout.gridPadding)
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
