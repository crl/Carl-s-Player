import SwiftUI

struct ContentView: View {
    @State private var library = LibraryStore()
    @State private var playback = PlaybackController()
    @State private var isSidebarVisible = true
    @State private var sidebarWidth: CGFloat = ThumbnailLayout.idealSidebarWidth

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if isSidebarVisible {
                    SidebarView(
                        library: library,
                        columnWidth: sidebarWidth
                    )
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity)
                    SidebarResizeHandle(
                        width: $sidebarWidth,
                        range: ThumbnailLayout.sidebarWidthRange
                    )
                        .frame(width: 12)
                        .frame(maxHeight: .infinity)
                }
                PlayerDetailView(
                    library: library,
                    playback: playback,
                    showsWindowTitle: false
                )
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                if isSidebarVisible {
                    titleToolbarItem

                    ToolbarItem(placement: .navigation) {
                        Button {
                            isSidebarVisible = false
                        } label: {
                            Image(systemName: "sidebar.leading")
                        }
                        .help("隐藏边栏")
                    }
                } else {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            isSidebarVisible = true
                        } label: {
                            Image(systemName: "sidebar.leading")
                        }
                        .help("显示边栏")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        library.openFolder()
                    } label: {
                        Label("打开文件夹", systemImage: "folder.badge.plus")
                    }
                    .help("打开文件夹")
                    .keyboardShortcut("o", modifiers: .command)
                }
            }
        }
        .onChange(of: library.selectedID) { _, _ in
            if let item = library.selectedItem {
                playback.load(item)
            } else {
                playback.unload()
            }
        }
        .onChange(of: playback.finishToken) { _, _ in
            guard playback.finishToken > 0 else { return }
            library.handlePlaybackFinished(playback)
        }
        .preferredColorScheme(.dark)
    }

    @ToolbarContentBuilder
    private var titleToolbarItem: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                titleLabel
                    .frame(maxWidth: max(80, sidebarWidth - 118), alignment: .leading)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) {
                titleLabel
                    .frame(maxWidth: max(80, sidebarWidth - 118), alignment: .leading)
            }
        }
    }

    private var titleLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(toolbarTitle)
                .font(.headline)
                .lineLimit(1)
            if !toolbarSubtitle.isEmpty {
                Text(toolbarSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var toolbarTitle: String {
        library.selectedItem?.name ?? library.folderName ?? "Carl's Player"
    }

    private var toolbarSubtitle: String {
        guard library.selectedItem != nil else { return "" }
        return TimeFormatting.position(playback.currentTime, duration: playback.duration)
    }
}

#Preview {
    ContentView()
}
