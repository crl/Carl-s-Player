import SwiftUI

struct MediaItemCell: View {
    let item: MediaItem
    let thumbnailWidth: CGFloat
    let showsName: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
            if showsName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(item.duration.map(TimeFormatting.duration) ?? "--:--")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(ThumbnailLayout.cellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.28) : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(item.name)
    }

    private var thumbnail: some View {
        ThumbnailView(item: item, iconScale: thumbnailWidth)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if !showsName, let duration = item.duration {
                    Text(TimeFormatting.duration(duration))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(5)
                }
            }
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct ThumbnailView: View {
    let item: MediaItem
    var iconScale: CGFloat = 80
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: item.kind == .video ? "film" : "music.note")
                    .font(.system(size: max(14, iconScale * 0.18)))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: item.id) {
            image = await ThumbnailService.shared.image(for: item)
        }
    }
}
