import SwiftUI

struct PlaybackModeIcon: View {
    let mode: PlaybackMode

    var body: some View {
        Image(systemName: mode.systemImage)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .frame(width: 28, height: 24)
            .accessibilityHidden(true)
    }
}
