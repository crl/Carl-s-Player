import SwiftUI

struct ContentView: View {
    @State private var library = LibraryStore()
    @State private var playback = PlaybackController()
    @State private var isSidebarVisible = true
    @State private var sidebarWidth: CGFloat = ThumbnailLayout.idealSidebarWidth
    @State private var contentWidth: CGFloat = 1100

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
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentWidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(ContentWidthKey.self) { contentWidth = $0 }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    sidebarToggleButton
                }

                titleToolbarItem

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        library.openFolder()
                    } label: {
                        Label("打开文件夹", systemImage: "folder.badge.plus")
                            .labelStyle(.iconOnly)
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

    private var sidebarToggleButton: some View {
        Button {
            isSidebarVisible.toggle()
        } label: {
            Image(systemName: "sidebar.leading")
        }
        .help(isSidebarVisible ? "隐藏边栏" : "显示边栏")
    }

    @ToolbarContentBuilder
    private var titleToolbarItem: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .principal) {
                titleLabel
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) {
                titleLabel
            }
        }
    }

    private var titleLabel: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: max(0, titleCenterOffset * 2))
            Text(toolbarTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: titleMaxWidth)
                .help(toolbarTitle)
        }
    }

    /// `.principal` is window-centered; shift by half the sidebar so the title
    /// sits on the playback pane's horizontal center.
    private var titleCenterOffset: CGFloat {
        isSidebarVisible ? leadingColumnWidth / 2 : 0
    }

    private var leadingColumnWidth: CGFloat {
        sidebarWidth + 12
    }

    private var titleMaxWidth: CGFloat {
        let playerWidth = max(380, contentWidth - (isSidebarVisible ? leadingColumnWidth : 0))
        return min(360, max(80, playerWidth - 120))
    }

    private var toolbarTitle: String {
        library.selectedItem?.name ?? library.folderName ?? "Carl's Player"
    }
}

private struct ContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 1100
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ContentView()
}
