import XCTest

@testable import ArtazzenMobile

final class ArtworkTests: XCTestCase {
    let sampleJSON = """
        {
            "filename": "test.jpg",
            "title": "Test Artwork",
            "description": "A test description",
            "caption": "Test caption",
            "tags": ["abstract", "botanical"],
            "artist": "Test Artist",
            "copyright": "© 2026",
            "collection": "Test Collection",
            "status": "approved",
            "ai_generated": true,
            "ai_fields": ["title", "description"],
            "detected_at": 1718000000.0
        }
        """.data(using: .utf8)!

    func testDecode() throws {
        let artwork = try JSONDecoder().decode(Artwork.self, from: sampleJSON)
        XCTAssertEqual(artwork.filename, "test.jpg")
        XCTAssertEqual(artwork.title, "Test Artwork")
        XCTAssertEqual(artwork.caption, "Test caption")
        XCTAssertEqual(artwork.tags, ["abstract", "botanical"])
        XCTAssertEqual(artwork.artist, "Test Artist")
        XCTAssertEqual(artwork.copyright, "© 2026")
        XCTAssertEqual(artwork.collection, "Test Collection")
        XCTAssertEqual(artwork.status, .approved)
        XCTAssertTrue(artwork.aiGenerated)
        XCTAssertEqual(artwork.aiFields, [.title, .description])
        XCTAssertEqual(artwork.id, "test.jpg")
        XCTAssertNil(artwork.url)
        XCTAssertNil(artwork.imageURL)
    }

    func testEncode() throws {
        let artwork = try JSONDecoder().decode(Artwork.self, from: sampleJSON)
        let encoded = try JSONEncoder().encode(artwork)
        let decoded = try JSONDecoder().decode(Artwork.self, from: encoded)
        XCTAssertEqual(artwork.filename, decoded.filename)
        XCTAssertEqual(artwork.tags, decoded.tags)
        XCTAssertEqual(artwork.aiFields, decoded.aiFields)
    }

    func testPendingStatus() throws {
        let json = """
            {
                "filename": "pending.jpg",
                "title": "",
                "description": "",
                "caption": "",
                "tags": [],
                "artist": "",
                "copyright": "",
                "collection": "",
                "status": "pending",
                "ai_generated": false,
                "ai_fields": [],
                "detected_at": 0
            }
            """.data(using: .utf8)!
        let artwork = try JSONDecoder().decode(Artwork.self, from: json)
        XCTAssertEqual(artwork.status, .pending)
        XCTAssertFalse(artwork.aiGenerated)
        XCTAssertTrue(artwork.aiFields.isEmpty)
    }

    func testImageURLFallsBackToRelativeStaticImagePath() throws {
        let artwork = try JSONDecoder().decode(Artwork.self, from: sampleJSON)
        let baseURL = URL(string: "https://example.com/")!

        XCTAssertEqual(
            artwork.imageURL(relativeTo: baseURL)?.absoluteString,
            "https://example.com/static/images/test.jpg"
        )
    }

    func testExplicitImageURLTakesPrecedence() throws {
        let json = """
            {
                "filename": "test.jpg", "title": "", "description": "", "caption": "",
                "tags": [], "artist": "", "copyright": "", "collection": "",
                "status": "hidden", "ai_generated": false, "ai_fields": [],
                "detected_at": 0, "url": "https://cdn.example.com/test.jpg"
            }
            """.data(using: .utf8)!
        let artwork = try JSONDecoder().decode(Artwork.self, from: json)

        XCTAssertEqual(
            artwork.imageURL(relativeTo: URL(string: "https://example.com/")!)?.absoluteString,
            "https://cdn.example.com/test.jpg"
        )
    }

    func testDecodeAcceptsBackendNameKey() throws {
        let json = """
            {
                "name": "from-api.jpg",
                "title": "Named",
                "url": "/images/from-api.jpg",
                "status": "approved",
                "ai_generated": false,
                "detected_at": 1
            }
            """.data(using: .utf8)!
        let artwork = try JSONDecoder().decode(Artwork.self, from: json)
        XCTAssertEqual(artwork.filename, "from-api.jpg")
        let resolved = artwork.imageURL(relativeTo: URL(string: "https://artazzen.com/")!)
        XCTAssertEqual(resolved?.absoluteString, "https://artazzen.com/images/from-api.jpg")
    }

    func testPendingAndGalleryPayloadMapping() async throws {
        let json = """
            {
              "pending": [
                {
                  "name": "new.jpg",
                  "url": "/images/new.jpg",
                  "metadata": {
                    "title": "Fresh",
                    "status": "pending",
                    "ai_generated": true,
                    "ai_fields": ["title"],
                    "detected_at": 9
                  }
                }
              ],
              "gallery": [
                {
                  "name": "live.jpg",
                  "url": "/images/live.jpg",
                  "title": "Live",
                  "status": "approved",
                  "collection": "botanical",
                  "ai_generated": false,
                  "detected_at": 8
                }
              ]
            }
            """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ArtazzenAPI.PendingResponse.self, from: json)
        XCTAssertEqual(decoded.pending.first?.name, "new.jpg")
        XCTAssertEqual(decoded.pending.first?.metadata?.title, "Fresh")
        XCTAssertEqual(decoded.gallery.first?.name, "live.jpg")
        XCTAssertEqual(decoded.gallery.first?.sidecar.title, "Live")
        XCTAssertEqual(decoded.gallery.first?.sidecar.status, .approved)

        let api = ArtazzenAPI(
            baseURL: URL(string: "https://artazzen.com/")!,
            username: "admin",
            password: "x"
        )
        let mapped = await api.artworks(from: decoded)
        XCTAssertEqual(mapped.pending.first?.filename, "new.jpg")
        XCTAssertEqual(mapped.pending.first?.title, "Fresh")
        XCTAssertEqual(
            mapped.gallery.first?.url,
            "https://artazzen.com/images/live.jpg"
        )
    }

    func testCollectionsRegistryDecode() throws {
        let json = """
            {"collections":[{"id":"botanical","title":"Botanical","count":4}]}
            """.data(using: .utf8)!
        struct Response: Codable { let collections: [CollectionSummary] }
        let decoded = try JSONDecoder().decode(Response.self, from: json)
        XCTAssertEqual(decoded.collections.first?.id, "botanical")
        XCTAssertEqual(decoded.collections.first?.displayName, "Botanical")
        XCTAssertEqual(decoded.collections.first?.count, 4)
    }
}
