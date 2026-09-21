import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var library: LibraryStore
    @Bindable var playback: PlaybackController
    @State private var isRateMenuPresented = false

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

            rateButton

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

    private var rateButton: some View {
        Button {
            isRateMenuPresented.toggle()
        } label: {
            Text(isDefaultRate ? "倍速" : Self.rateLabel(playback.playbackRate))
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(isDefaultRate ? .secondary : Color.accentColor)
                .frame(minWidth: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("播放速度")
        .popover(isPresented: $isRateMenuPresented, arrowEdge: .bottom) {
            rateMenu
        }
    }

    private var rateMenu: some View {
        VStack(spacing: 2) {
            ForEach(Self.ratePresets, id: \.self) { rate in
                let selected = abs(playback.playbackRate - rate) < 0.001
                Button {
                    playback.playbackRate = rate
                    isRateMenuPresented = false
                } label: {
                    Text(Self.rateLabel(rate))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? Color.white.opacity(0.14) : .clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(width: 84)
    }

    private var isDefaultRate: Bool {
        abs(playback.playbackRate - 1) < 0.001
    }

    private static let ratePresets: [Float] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3]

    private static func rateLabel(_ rate: Float) -> String {
        switch rate {
        case 0.25: return "0.25x"
        case 0.5: return "0.5x"
        case 0.75: return "0.75x"
        case 1: return "1.0x"
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        case 1.75: return "1.75x"
        case 2: return "2.0x"
        case 3: return "3.0x"
        default: return String(format: "%gx", rate)
        }
    }

    private var volumeControl: some View {
        HStack(spacing: 6) {
            Button {
                playback.toggleMute()
            } label: {
                Image(systemName: volumeSymbol)
                    .foregroundStyle(playback.isMuted || playback.volume <= 0.001 ? .secondary : .primary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(playback.isMuted ? "取消静音" : "静音")
            .accessibilityLabel(playback.isMuted ? "取消静音" : "静音")

            Slider(value: volumeBinding, in: 0...1)
                .frame(width: 84)
                .controlSize(.small)
                .help("音量")
        }
    }

    private var volumeBinding: Binding<Float> {
        Binding(
            get: { playback.volume },
            set: { playback.volume = $0 }
        )
    }

    private var volumeSymbol: String {
        if playback.isMuted || playback.volume <= 0.001 {
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
