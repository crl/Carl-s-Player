import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackController

    var body: some View {
        HStack(spacing: 14) {
            Button {
                playback.togglePlay()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!playback.hasItem)
            .keyboardShortcut(.space, modifiers: [])
            .help(playback.isPlaying ? "暂停" : "播放")

            Button {
                library.playbackMode.cycle()
            } label: {
                PlaybackModeIcon(mode: library.playbackMode)
                    .foregroundStyle(modeTint)
            }
            .buttonStyle(.plain)
            .help(library.playbackMode.help)
            .accessibilityLabel(library.playbackMode.help)

            progressSlider

            Text(TimeFormatting.position(playback.currentTime, duration: playback.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 92, alignment: .trailing)

            volumeControl
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var modeTint: Color {
        switch library.playbackMode {
        case .sequential:
            return .secondary
        case .loopAll, .loopOne:
            return .accentColor
        }
    }

    private var progressSlider: some View {
        Slider(
            value: $playback.currentTime,
            in: 0...max(playback.duration, 0.01)
        ) { editing in
            playback.isSeeking = editing
            if !editing {
                playback.seek(to: playback.currentTime)
            }
        }
        .disabled(!playback.hasItem || playback.duration <= 0)
        .controlSize(.small)
    }

    private var volumeControl: some View {
        HStack(spacing: 6) {
            Image(systemName: volumeSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Slider(value: volumeBinding, in: 0...1)
                .frame(width: 84)
                .controlSize(.small)
        }
        .help("音量")
    }

    private var volumeBinding: Binding<Float> {
        Binding(
            get: { playback.volume },
            set: { playback.volume = $0 }
        )
    }

    private var volumeSymbol: String {
        if playback.volume <= 0.001 {
            return "speaker.slash.fill"
        }
        if playback.volume < 0.4 {
            return "speaker.wave.1.fill"
        }
        if playback.volume < 0.75 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }
}
