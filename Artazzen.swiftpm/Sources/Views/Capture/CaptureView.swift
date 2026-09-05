import ArtazzenCore
import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct CaptureView: View {
    @Environment(AppSession.self) private var session
    @State private var selectedItem: PhotosPickerItem?
    @State private var photo: PreparedPhoto?
    @State private var preview: UIImage?
    @State private var filename = ""
    @State private var selectionID = UUID()
    @State private var isProcessing = false
    @State private var needsMetadata = false
    @State private var error: String?
    @State private var generatedArtwork: Artwork?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let preview {
                    Image(uiImage: preview)
                        .resizable().scaledToFit().frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if let artwork = generatedArtwork {
                        MetadataEditor(artwork: artwork).id(artwork.filename)
                    } else {
                        if let error { Text(error).foregroundStyle(.red) }
                        if isProcessing {
                            ProgressView("Preparing or uploading artwork...")
                        } else {
                            Button(
                                needsMetadata
                                    ? "Retry Metadata Load"
                                    : (error == nil ? "Upload" : "Retry Upload")
                            ) {
                                upload()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!session.hasCredentials || photo == nil)
                            if !session.hasCredentials {
                                Text("Connect in Settings before uploading.")
                            }
                        }
                    }
                } else if isProcessing {
                    ProgressView("Preparing photo...")
                } else {
                    ContentUnavailableView(
                        "Choose Artwork", systemImage: "photo",
                        description: Text(error ?? "Choose a photo, then tap Upload.")
                    )
                }
            }
            .padding()
            .navigationTitle("Capture")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isProcessing)
                }
            }
            .onChange(of: selectedItem) { _, item in prepare(item) }
        }
    }

    private func prepare(_ item: PhotosPickerItem?) {
        let selection = UUID()
        let generation = session.connectionID
        selectionID = selection
        generatedArtwork = nil
        photo = nil
        preview = nil
        error = nil
        needsMetadata = false
        isProcessing = true
        Task {
            defer { if selectionID == selection { isProcessing = false } }
            do {
                guard let data = try await item?.loadTransferable(type: Data.self) else {
                    throw PreparedPhoto.PreparationError.unreadable
                }
                let prepared = try await Task.detached { try PreparedPhoto(data: data) }.value
                guard generation == session.connectionID, selectionID == selection else { return }
                photo = prepared
                preview = UIImage(data: prepared.thumbnail)
                filename = "capture-\(UUID().uuidString).\(prepared.fileExtension)"
            } catch {
                guard generation == session.connectionID, selectionID == selection else { return }
                self.error = error.localizedDescription
            }
        }
    }

    private func upload() {
        guard let photo, !isProcessing else { return }
        let generation = session.connectionID
        let selection = selectionID
        isProcessing = true
        error = nil
        Task {
            defer { if selectionID == selection { isProcessing = false } }
            do {
                let artwork: Artwork
                if needsMetadata {
                    artwork = try await session.uploadedArtwork(filename: filename)
                } else {
                    artwork = try await session.upload(
                        imageData: photo.data, filename: filename, contentType: photo.contentType
                    )
                }
                guard generation == session.connectionID, selectionID == selection else { return }
                generatedArtwork = artwork
            } catch {
                guard generation == session.connectionID, selectionID == selection else { return }
                if case ArtazzenAPI.APIError.metadataUnavailable = error { needsMetadata = true }
                self.error = error.localizedDescription
            }
        }
    }
}
