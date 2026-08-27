import SwiftUI

struct PlayerDetailView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackController

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PlayerPaneView(player: playback.player)
                    .background(.black)

                if let item = library.selectedItem, item.kind == .audio {
                    AudioStageView(item: item)
                }

                if library.selectedItem == nil {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackControlsView(library: library, playback: playback)
        }
        .background(Color.black)
        .navigationTitle(library.selectedItem?.name ?? "mPlayer")
        .navigationSubtitle(subtitle)
    }

    private var subtitle: String {
        guard library.selectedItem != nil else { return "" }
        return TimeFormatting.position(playback.currentTime, duration: playback.duration)
    }

    @ViewBuilder
    private var emptyState: some View {
        if library.folderURL == nil {
            ContentUnavailableView(
                "打开文件夹开始播放",
                systemImage: "play.rectangle.on.rectangle",
                description: Text("从左侧打开一个本地文件夹，然后选择文件")
            )
        } else if library.items.isEmpty {
            ContentUnavailableView(
                "没有可播放的文件",
                systemImage: "film.stack",
                description: Text("换一个包含 mp4、mov、mp3 等格式的文件夹")
            )
        } else {
            ContentUnavailableView(
                "选择一个文件",
                systemImage: "play.circle",
                description: Text("点击左侧列表中的文件即可播放")
            )
        }
    }
}

private struct AudioStageView: View {
    let item: MediaItem
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: 240, height: 240)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 24, y: 8)

            Text(item.name)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .task(id: item.id) {
            image = await ThumbnailService.shared.image(for: item)
        }
    }
}
