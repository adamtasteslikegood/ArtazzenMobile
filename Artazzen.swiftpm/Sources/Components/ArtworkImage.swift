import ArtazzenCore
import SwiftUI

/// The parent supplies a stable frame; loading never changes the card's geometry.
struct ArtworkImage: View {
    let artwork: Artwork
    var contentMode: ContentMode = .fit
    var maxPixelSize = 1200
    var compact = false

    @State private var image: CGImage?
    @State private var failure: String?
    @State private var retry = 0

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.06))
            .overlay {
                GeometryReader { geometry in
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let failure {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                            if !compact {
                                Text(failure).font(.caption)
                                Text("Touch and hold to retry").font(.caption2)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        ProgressView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(artwork.title.isEmpty ? artwork.filename : artwork.title)
            .accessibilityValue(failure ?? (image == nil ? "Loading image" : "Artwork image"))
            .accessibilityAction(named: "Retry image") { retry += 1 }
            .contextMenu { Button("Retry Image", systemImage: "arrow.clockwise") { retry += 1 } }
            .task(id: LoadID(url: artwork.imageURL, pixels: maxPixelSize, retry: retry)) {
                image = nil
                failure = nil
                guard let url = artwork.imageURL else {
                    failure = "Image address unavailable"
                    return
                }
                do {
                    let loaded = try await ArtworkImageLoader.shared.load(
                        url: url, maxPixelSize: maxPixelSize, reload: retry > 0)
                    try Task.checkCancellation()
                    image = loaded
                } catch {
                    guard !Task.isCancelled else { return }
                    // Network messages contain no server credentials or response bodies.
                    failure = error.localizedDescription
                }
            }
    }

    private struct LoadID: Hashable {
        let url: URL?
        let pixels: Int
        let retry: Int
    }
}
