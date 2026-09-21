import SwiftUI

struct PlayerDetailView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackController
    var showsWindowTitle: Bool = true
    @State private var statusVisible = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let item = library.selectedItem {
                    BlurredPreviewBackground(item: item)
                } else {
                    Color.black
                }

                PlayerPaneView(player: playback.player)
                    .opacity(library.selectedItem?.kind == .audio ? 0 : 1)

                if let item = library.selectedItem, item.kind == .audio {
                    AudioStageView(item: item)
                }

                if library.selectedItem == nil {
                    emptyState
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playback.togglePlay()
                        }
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }

                    if statusVisible {
                        CenterPlaybackStatus(isPlaying: playback.isPlaying)
                            .transition(.scale(scale: 0.84).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: playback.playToggleToken) {
                guard playback.playToggleToken > 0, library.selectedItem != nil else { return }
                withAnimation(.spring(duration: 0.22, bounce: 0.18)) {
                    statusVisible = true
                }
                guard playback.isPlaying else { return }
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    statusVisible = false
                }
            }
            .onChange(of: library.selectedID) { _, _ in
                statusVisible = false
            }

            PlaybackControlsView(library: library, playback: playback)
        }
        .background(Color.black)
        .navigationTitle(showsWindowTitle ? (library.selectedItem?.name ?? "Carl's Player") : "")
        .navigationSubtitle(showsWindowTitle ? subtitle : "")
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

private struct BlurredPreviewBackground: View {
    let item: MediaItem
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.2)
                        .blur(radius: 56)
                        .saturation(1.28)
                        .brightness(-0.04)
                }
                Color.black.opacity(0.26)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: item.id) {
            image = await ThumbnailService.shared.image(for: item)
        }
    }
}

private struct CenterPlaybackStatus: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.white)
            .offset(x: isPlaying ? 0 : 3)
            .frame(width: 84, height: 84)
            .background {
                Circle()
                    .fill(.black.opacity(0.46))
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .accessibilityHidden(true)
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
