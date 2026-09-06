import CoreGraphics
import ImageIO
import XCTest

@testable import ArtazzenCore

final class ArtworkImageTests: XCTestCase {
    private let url = URL(string: "https://example.com/images/artwork.jpg")!

    private func imageData(orientation: Int = 1) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 800, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(
            destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testThumbnailLimitsDecodedPixels() throws {
        let image = try ArtworkImageLoader.thumbnail(data: imageData(), maxPixelSize: 200)
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 100)
    }

    func testThumbnailAppliesCameraOrientation() throws {
        let image = try ArtworkImageLoader.thumbnail(
            data: imageData(orientation: 6), maxPixelSize: 200)
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 200)
    }

    func testHTMLResponseIsNotTreatedAsAnImage() throws {
        XCTAssertThrowsError(
            try ArtworkImageLoader.thumbnail(
                data: Data("<html>Sign in</html>".utf8), maxPixelSize: 200))
    }

    func testHTTPFailureCanBeRetriedAndSuccessIsCached() async throws {
        let server = ImageServer(data: try imageData())
        let loader = ArtworkImageLoader(transport: { try await server.respond($0) })
        do {
            _ = try await loader.load(url: url, maxPixelSize: 200)
            XCTFail("Expected the first request to fail")
        } catch ArtworkImageLoader.ImageError.httpStatus(let code) {
            XCTAssertEqual(code, 403)
        }
        let image = try await loader.load(url: url, maxPixelSize: 200, reload: true)
        XCTAssertEqual(image.width, 200)
        _ = try await loader.load(url: url, maxPixelSize: 200)
        let requests = await server.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(requests.last?.url, url)
    }

    func testCredentialsInImageURLAreRejectedBeforeTransport() async throws {
        let loader = ArtworkImageLoader(transport: { _ in
            XCTFail("Must not send embedded credentials")
            throw URLError(.badURL)
        })
        do {
            _ = try await loader.load(
                url: URL(string: "https://admin:secret@example.com/image.jpg")!, maxPixelSize: 200)
            XCTFail("Expected invalid URL")
        } catch ArtworkImageLoader.ImageError.invalidURL {
            // Expected.
        }
    }
}

private actor ImageServer {
    let data: Data
    private(set) var requests: [URLRequest] = []

    init(data: Data) { self.data = data }

    func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (
            data,
            HTTPURLResponse(
                url: request.url!, statusCode: requests.count == 1 ? 403 : 200,
                httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!
        )
    }
}
