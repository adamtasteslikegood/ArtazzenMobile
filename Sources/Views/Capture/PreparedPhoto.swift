import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepare once off the main actor; body rendering only uses a small cached preview.
struct PreparedPhoto: Sendable {
    let data: Data
    let thumbnail: Data
    let fileExtension: String
    let contentType: String

    init(data: Data) throws {
        guard data.count <= 50 * 1024 * 1024 else { throw PreparationError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let identifier = CGImageSourceGetType(source),
            let type = UTType(identifier as String),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1200,
                ] as CFDictionary)
        else { throw PreparationError.unreadable }
        let preview = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                preview, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw PreparationError.unreadable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PreparationError.unreadable }
        thumbnail = preview as Data
        let suffix = type.preferredFilenameExtension ?? ""
        if ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "tif"].contains(suffix) {
            self.data = data
            fileExtension = suffix == "tif" ? "tiff" : suffix
            contentType = type.preferredMIMEType ?? "application/octet-stream"
        } else {
            // HEIC and other picker formats are not accepted by the backend.
            let encoded = NSMutableData()
            guard
                let output = CGImageDestinationCreateWithData(
                    encoded, UTType.jpeg.identifier as CFString, 1, nil)
            else {
                throw PreparationError.unreadable
            }
            CGImageDestinationAddImageFromSource(
                output, source, 0,
                [
                    kCGImageDestinationLossyCompressionQuality: 0.95
                ] as CFDictionary)
            guard CGImageDestinationFinalize(output) else { throw PreparationError.unreadable }
            self.data = encoded as Data
            fileExtension = "jpg"
            contentType = "image/jpeg"
        }
        guard self.data.count <= 50 * 1024 * 1024 else { throw PreparationError.tooLarge }
    }

    enum PreparationError: LocalizedError {
        case unreadable, tooLarge
        var errorDescription: String? {
            switch self {
            case .unreadable: return "This photo could not be prepared. Choose another image."
            case .tooLarge: return "Choose an image smaller than 50 MB."
            }
        }
    }
}
