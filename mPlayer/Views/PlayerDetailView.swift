import SwiftUI

struct PlayerDetailView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackController
    var showsWindowTitle: Bool = true
    @State private var statusVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var peekItem: MediaItem?
    @State private var peekDelta = 0
    @State private var isSwitching = false
    @State private var pageHeight: CGFloat = 600
    @State private var playerReadyForDisplay = false

    var body: some View {
        let pending = library.pendingTransition
        return VStack(spacing: 0) {
            playerStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            PlaybackControlsView(library: library, playback: playback)
        }
        .background(Color.black)
        .navigationTitle(showsWindowTitle ? (library.selectedItem?.name ?? "Carl's Player") : "")
        .navigationSubtitle(showsWindowTitle ? subtitle : "")
        .onChange(of: pending) { _, newPending in
            guard let newPending else { return }
            Task { await finishTransition(newPending) }
        }
        .onChange(of: playback.playToggleToken) { _, token in
            guard token > 0, library.selectedItem != nil, abs(dragOffset) < 8 else { return }
            Task { await flashStatus() }
        }
        .onChange(of: library.selectedID) { _, _ in
            statusVisible = false
            prefetchAdjacentFirstFrames()
        }
    }

    private var playerStage: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack {
                if library.selectedItem == nil {
                    Color.black
                    emptyState
                } else {
                    Color.black

                    livePage
                        .frame(width: geo.size.width, height: height)
                        .offset(y: dragOffset)

                    if let peekItem {
                        PeekPageView(item: peekItem)
                            .id(peekItem.id)
                            .frame(width: geo.size.width, height: height)
                            .offset(y: dragOffset + CGFloat(peekDelta) * height)
                            .allowsHitTesting(false)
                    }

                    PlayerInteractionCatcher(
                        pageHeight: height,
                        onPan: { translationY, ended, isClick in
                            handlePan(translationY: translationY, ended: ended, isClick: isClick, height: height)
                        }
                    )

                    if statusVisible, abs(dragOffset) < 8, peekItem == nil {
                        CenterPlaybackStatus(isPlaying: playback.isPlaying)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
            .onAppear { pageHeight = height }
            .onChange(of: height) { _, newHeight in
                pageHeight = newHeight
            }
        }
    }

    @ViewBuilder
    private var livePage: some View {
        if let item = library.selectedItem {
            ZStack {
                BlurredPreviewBackground(item: item)
                PlayerPaneView(player: playback.player) { ready in
                    playerReadyForDisplay = ready
                }
                    .opacity(item.kind == .audio ? 0 : 1)
                if item.kind == .audio {
                    AudioStageView(item: item)
                }
            }
        }
    }

    private func handlePan(translationY: CGFloat, ended: Bool, isClick: Bool, height: CGFloat) {
        guard !isSwitching, library.pendingTransition == nil, library.selectedItem != nil else { return }
        if isClick {
            playback.togglePlay()
            resetDrag(animated: false)
            return
        }
        applyInteractiveOffset(translationY)
        if ended {
            settle(height: height)
        }
    }

    /// Douyin: offset > 0 slides down to previous; offset < 0 slides up to next.
    private func applyInteractiveOffset(_ y: CGFloat) {
        let delta = y < 0 ? 1 : (y > 0 ? -1 : 0)
        guard delta != 0 else {
            dragOffset = 0
            peekItem = nil
            peekDelta = 0
            return
        }
        if let adjacent = library.item(offset: delta, wrapping: library.wrapsAdjacently),
           adjacent.id != library.selectedID {
            peekItem = adjacent
            peekDelta = delta
            dragOffset = y
        } else {
            peekItem = nil
            peekDelta = 0
            dragOffset = y * 0.28
        }
    }

    private func settle(height: CGFloat) {
        let threshold = max(height * 0.2, 72)
        let shouldSwitch = abs(dragOffset) >= threshold && peekItem != nil
        if shouldSwitch, let peekItem {
            library.requestSelect(peekItem)
            return
        }
        withAnimation(.spring(duration: 0.28, bounce: 0.1)) {
            dragOffset = 0
        }
        peekItem = nil
        peekDelta = 0
    }

    @MainActor
    private func finishTransition(_ pending: LibraryStore.MediaTransition) async {
        guard !isSwitching else { return }
        isSwitching = true
        guard let item = library.items.first(where: { $0.id == pending.itemID }) else {
            isSwitching = false
            library.pendingTransition = nil
            resetDrag(animated: false)
            return
        }

        let target = CGFloat(-pending.delta) * max(pageHeight, 1)
        let alreadyFollowing = peekItem?.id == item.id && abs(dragOffset) > 8

        if !alreadyFollowing {
            var prepare = Transaction()
            prepare.disablesAnimations = true
            withTransaction(prepare) {
                peekItem = item
                peekDelta = pending.delta
                dragOffset = 0
            }
            try? await Task.sleep(for: .milliseconds(16))
        } else {
            peekItem = item
            peekDelta = pending.delta
        }

        withAnimation(.easeInOut(duration: 0.38)) {
            dragOffset = target
        }
        try? await Task.sleep(for: .milliseconds(380))

        var rest = Transaction()
        rest.disablesAnimations = true
        withTransaction(rest) {
            peekItem = item
            peekDelta = 0
            dragOffset = 0
            playerReadyForDisplay = false
            playback.pauseNextLoadAtStart()
            library.commitPendingTransition()
        }

        await waitForPlaybackDisplay(item)
        try? await Task.sleep(for: .milliseconds(16))

        var reveal = Transaction()
        reveal.disablesAnimations = true
        withTransaction(reveal) {
            if peekItem?.id == item.id {
                peekItem = nil
                peekDelta = 0
            }
            isSwitching = false
        }
        playback.startPlaying()
    }

    private func prefetchAdjacentFirstFrames() {
        let next = library.item(offset: 1, wrapping: library.wrapsAdjacently)
        let previous = library.item(offset: -1, wrapping: library.wrapsAdjacently)
        Task {
            if let next {
                _ = await ThumbnailService.shared.firstFrame(for: next)
            }
            if let previous {
                _ = await ThumbnailService.shared.firstFrame(for: previous)
            }
        }
    }

    @MainActor
    private func waitForPlaybackDisplay(_ item: MediaItem) async {
        let deadline = Date().addingTimeInterval(1.2)
        var itemReadyAt: Date?
        while Date() < deadline {
            let itemReady = playback.player.currentItem?.status == .readyToPlay
            if playback.isCurrentItem(item), itemReady {
                if item.kind == .audio || playerReadyForDisplay {
                    return
                }
                if itemReadyAt == nil {
                    itemReadyAt = Date()
                }
                if let itemReadyAt, Date().timeIntervalSince(itemReadyAt) >= 0.08 {
                    return
                }
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func resetDrag(animated: Bool) {
        if animated {
            withAnimation(.spring(duration: 0.28, bounce: 0.1)) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
        peekItem = nil
        peekDelta = 0
    }

    @MainActor
    private func flashStatus() async {
        withAnimation(.easeOut(duration: 0.18)) {
            statusVisible = true
        }
        guard playback.isPlaying else { return }
        try? await Task.sleep(for: .milliseconds(800))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            statusVisible = false
        }
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

private struct PeekPageView: View {
    let item: MediaItem
    @State private var image: NSImage?

    init(item: MediaItem) {
        self.item = item
        _image = State(
            initialValue: ThumbnailService.shared.cachedFirstFrame(for: item)
                ?? ThumbnailService.shared.cachedImage(for: item)
        )
    }

    var body: some View {
        ZStack {
            BlurredPreviewBackground(item: item)
            if item.kind == .audio {
                AudioStageView(item: item)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: item.id) {
            if let frame = await ThumbnailService.shared.firstFrame(for: item) {
                image = frame
            } else {
                image = await ThumbnailService.shared.image(for: item)
            }
        }
    }
}

private struct BlurredPreviewBackground: View {
    let item: MediaItem
    @State private var image: NSImage?

    init(item: MediaItem) {
        self.item = item
        _image = State(initialValue: ThumbnailService.shared.cachedImage(for: item))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
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
