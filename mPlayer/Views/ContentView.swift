import SwiftUI

struct ContentView: View {
    @State private var library = LibraryStore()
    @State private var playback = PlaybackController()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(library: library)
                .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 560)
        } detail: {
            PlayerDetailView(library: library, playback: playback)
        }
        .toolbar {
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
}

#Preview {
    ContentView()
}
