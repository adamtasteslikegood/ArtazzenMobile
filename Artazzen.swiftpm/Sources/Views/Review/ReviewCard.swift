import ArtazzenCore
import SwiftUI

@MainActor
struct ReviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let artwork: Artwork

    var body: some View {
        VStack(spacing: 0) {
            ArtworkImage(artwork: artwork)
                .aspectRatio(4 / 5, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                Text(artwork.title)
                    .font(.azDisplay)
                    .lineLimit(2)

                if !artwork.caption.isEmpty {
                    Text(artwork.caption)
                        .font(.azBody)
                        .foregroundStyle(.secondary)
                }

                if !artwork.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(artwork.tags.prefix(5), id: \.self) { tag in
                                TagPill(text: tag)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colorScheme == .dark ? Color.azCarbon : Color.azParchment)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8, x: 0, y: 4)

    }
}
