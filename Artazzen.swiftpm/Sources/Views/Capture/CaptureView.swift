import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(AppSession.self) private var session
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isProcessing = false
    @State private var generatedArtwork: Artwork?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isProcessing {
                        ProgressView("Uploading to Artazzen...")
                            .font(.azBody)
                    } else if let artwork = generatedArtwork {
                        MetadataEditor(artwork: artwork)
                    } else if let error = session.lastError {
                        Text(error)
                            .font(.azBody)
                            .foregroundStyle(.red)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Capture Artwork", systemImage: "camera.viewfinder")
                    } description: {
                        Text("Take a photo or choose from your library to add artwork.")
                    }
                }
            }
            .padding()
            .navigationTitle("Capture")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose", systemImage: "photo.on.rectangle")
                    }
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else {
                        return
                    }
                    imageData = data
                    isProcessing = true
                    let filename = "capture-\(Int(Date().timeIntervalSince1970)).jpg"
                    await session.upload(imageData: data, filename: filename)
                    generatedArtwork =
                        session.pending.first(where: { $0.filename == filename })
                        ?? Artwork(filename: filename, title: filename, status: .pending)
                    isProcessing = false
                }
            }
        }
    }
}
