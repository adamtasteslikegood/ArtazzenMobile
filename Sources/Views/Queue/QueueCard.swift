import ArtazzenCore
import SwiftUI

@MainActor
struct QueueCard: View {
    let artwork: Artwork

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(
                artwork: artwork, contentMode: .fill, maxPixelSize: 192, compact: true
            )
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.displayTitle)
                    .font(.azBody)
                    .lineLimit(1)
                Text(artwork.filename)
                    .font(.azMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                StatusBadge(status: artwork.status)
            }
        }
        .padding(.vertical, 4)
    }
}
