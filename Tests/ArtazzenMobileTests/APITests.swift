import Foundation
import XCTest

@testable import ArtazzenCore

final class APITests: XCTestCase {
    private func api(_ server: TestServer) -> ArtazzenAPI {
        ArtazzenAPI(
            baseURL: URL(string: "https://example.com")!, username: "admin", password: " secret ",
            transport: { try await server.respond($0) })
    }

    func testPreviewDecodesWrapperNameAndSendsPreviewFlag() async throws {
        let server = TestServer()
        await server.enqueue(
            "/admin/ai/regenerate",
            .init(
                json:
                    #"{"updated":[{"name":"a.jpg","metadata":{"title":"Generated","ai_fields":["title"]}}],"errors":[]}"#
            ))
        let artwork = try await api(server).regenerateFields(image: "a.jpg", fields: [.title])
        XCTAssertEqual(artwork?.filename, "a.jpg")
        XCTAssertEqual(artwork?.title, "Generated")
        let requests = await server.recorded()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(body["preview"] as? Bool, true)
        XCTAssertEqual(body["force"] as? Bool, true)
        XCTAssertEqual(body["fields"] as? [String], ["title"])
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Basic " + Data("admin: secret ".utf8).base64EncodedString())
    }

    func testPreviewRejectsServerErrorsAndMismatchedArtwork() async {
        for response in [
            #"{"updated":[],"errors":[{"name":"a.jpg","error":"AI failed"}]}"#,
            #"{"updated":[{"name":"other.jpg","metadata":{"title":"Wrong"}}],"errors":[]}"#,
            #"{"updated":[],"errors":[]}"#,
            "invalid",
        ] {
            let server = TestServer()
            await server.enqueue("/admin/ai/regenerate", .init(json: response))
            do {
                _ = try await api(server).regenerateFields(image: "a.jpg", fields: [.title])
                XCTFail("Invalid generation must throw")
            } catch {
                // Expected; the caller preserves the draft.
            }
        }
    }

    func testSaveEncodesPlusFilenameAndAIProvenanceAndAccepts303() async throws {
        let server = TestServer()
        let name = "a #+?.jpg"
        await server.enqueue("/admin/metadata/" + name, .init(status: 303, json: ""))
        let artwork = Artwork(
            filename: name, title: "A+B & C", aiGenerated: true, aiFields: [.title])
        try await api(server).saveMetadata(artwork)
        let requests = await server.recorded()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/admin/metadata/" + name)
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.url?.fragment)
        let body = String(data: request.httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("title=A%2BB%20%26%20C"))
        XCTAssertTrue(body.contains("ai_fields=title"))
        XCTAssertTrue(body.contains("ai_generated=true"))
        XCTAssertFalse(body.contains("collections="))
    }

    func testUploadUsesActualMediaTypeAndConfirmsFilename() async throws {
        let server = TestServer()
        await server.enqueue(
            "/admin/upload",
            .init(json: #"{"saved":["new.png"],"skipped":[],"duplicates":[],"pending":[]}"#))
        let response = try await api(server).upload(
            imageData: Data("PNG bytes".utf8), filename: "new.png", contentType: "image/png")
        XCTAssertEqual(response.saved, ["new.png"])
        let requests = await server.recorded()
        let body = String(data: requests[0].httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"files\"; filename=\"new.png\""))
        XCTAssertTrue(body.contains("Content-Type: image/png"))
        XCTAssertTrue(body.contains("PNG bytes"))
    }

    func testPreviewMergePreservesDraftAndManualEditClearsProvenance() {
        var draft = Artwork(
            filename: "a.jpg", title: "Old", caption: "Unsaved", tags: ["manual"], artist: "Artist")
        let preview = Artwork(
            filename: "a.jpg", title: "Generated", caption: "Server caption", tags: ["server"])
        draft.applyPreview(preview, field: .title)
        XCTAssertEqual(draft.title, "Generated")
        XCTAssertEqual(draft.caption, "Unsaved")
        XCTAssertEqual(draft.tags, ["manual"])
        XCTAssertEqual(draft.artist, "Artist")
        XCTAssertEqual(draft.aiFields, [.title])
        draft.title = "Human edit"
        XCTAssertTrue(draft.aiFields.isEmpty)
        draft.applyPreview(Artwork(filename: "other.jpg", title: "Wrong"), field: .title)
        XCTAssertEqual(draft.title, "Human edit")
    }
}
