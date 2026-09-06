import Foundation
import ImageIO

/// Public artwork uses the server-provided URL, independently of admin credentials.
public actor ArtworkImageLoader {
    public static let shared = ArtworkImageLoader()
    private let cache = NSCache<NSString, CGImage>()
    private let transport: ArtazzenAPI.Transport

    public init(
        transport: @escaping ArtazzenAPI.Transport = { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ImageError.invalidResponse }
            return (data, http)
        }
    ) {
        self.transport = transport
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    public func load(url: URL, maxPixelSize: Int, reload: Bool = false) async throws -> CGImage {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil, url.user == nil, url.password == nil
        else { throw ImageError.invalidURL }
        let pixels = min(max(maxPixelSize, 64), 2048)
        let key = "\(url.absoluteString)|\(pixels)" as NSString
        if !reload, let cached = cache.object(forKey: key) { return cached }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if reload { request.cachePolicy = .reloadIgnoringLocalCacheData }
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard 200..<300 ~= response.statusCode else {
            throw ImageError.httpStatus(response.statusCode)
        }
        let image = try Self.thumbnail(data: data, maxPixelSize: pixels)
        cache.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }

    static func thumbnail(data: Data, maxPixelSize: Int) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { throw ImageError.unsupportedImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw ImageError.unsupportedImage }
        return image
    }

    public enum ImageError: LocalizedError {
        case invalidURL, invalidResponse, unsupportedImage
        case httpStatus(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Image address unavailable"
            case .invalidResponse: return "Invalid server response"
            case .unsupportedImage: return "Image could not be decoded"
            case .httpStatus(let code): return "Image request failed (HTTP \(code))"
            }
        }
    }
}
