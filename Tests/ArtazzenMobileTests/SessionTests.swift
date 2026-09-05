import Foundation
import XCTest

@testable import ArtazzenCore

final class SessionTests: XCTestCase {
    @MainActor
    private func session(
        _ server: TestServer, store: TestCredentialStore = TestCredentialStore()
    ) -> AppSession {
        let name = "ArtazzenTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return AppSession(
            defaults: defaults, credentialStore: store, transport: { try await server.respond($0) })
    }

    @MainActor
    private func connect(_ session: AppSession) async {
        session.serverURLString = "https://example.com"
        session.username = "admin"
        session.password = "password"
        await session.connect()
    }

    @MainActor
    func testApprovalWaitsAndRejectsDuplicateUntilConfirmed() async throws {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        let artwork = try XCTUnwrap(session.pending.first)
        let gate = RequestGate()
        await server.enqueue("/admin/metadata/a.jpg", .init(status: 303, json: "", gate: gate))
        let task = Task { await session.approve(artwork) }
        await server.waitForRequests(4)
        XCTAssertEqual(session.pending.count, 1)
        XCTAssertTrue(session.mutations.contains("a.jpg"))
        let duplicate = await session.approve(artwork)
        XCTAssertFalse(duplicate)
        await gate.release()
        let success = await task.value
        XCTAssertTrue(success)
        XCTAssertTrue(session.pending.isEmpty)
        XCTAssertEqual(session.gallery.count, 1)
        let requests = await server.recorded()
        XCTAssertEqual(requests.count, 4)
    }

    @MainActor
    func testFailedApprovalRetainsCardAndAllowsRetry() async throws {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        let artwork = try XCTUnwrap(session.pending.first)
        await server.enqueue("/admin/metadata/a.jpg", .init(status: 500, json: "{}"))
        let failed = await session.approve(artwork)
        XCTAssertFalse(failed)
        XCTAssertEqual(session.pending.first?.filename, artwork.filename)
        XCTAssertTrue(session.gallery.isEmpty)
        XCTAssertTrue(session.mutations.isEmpty)
        XCTAssertNotNil(session.lastError)
        let retried = await session.approve(artwork)
        XCTAssertTrue(retried)
        XCTAssertNil(session.lastError)
    }

    @MainActor
    func testOlderRefreshCannotResurrectApprovedArtwork() async throws {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        let artwork = try XCTUnwrap(session.pending.first)
        let gate = RequestGate()
        await server.enqueue(
            "/admin/api/new-files",
            .init(
                json: #"{"pending":[{"name":"a.jpg","url":"/images/a.jpg"}],"gallery":[]}"#,
                gate: gate
            ))
        let refresh = Task { await session.refresh() }
        await server.waitForRequests(4)
        let saved = await session.approve(artwork)
        XCTAssertTrue(saved)
        await gate.release()
        await refresh.value
        XCTAssertTrue(session.pending.isEmpty)
        XCTAssertEqual(session.gallery.first?.filename, "a.jpg")
        XCTAssertFalse(session.isLoading)
    }

    @MainActor
    func testDraftEditsDoNotChangeActiveConnection() async throws {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        session.serverURLString = "https://other.example"
        session.username = "other"
        session.password = "other-password"
        _ = await session.approve(try XCTUnwrap(session.pending.first))
        let requests = await server.recorded()
        let last = try XCTUnwrap(requests.last)
        XCTAssertEqual(last.url?.host, "example.com")
        XCTAssertEqual(
            last.value(forHTTPHeaderField: "Authorization"),
            "Basic " + Data("admin:password".utf8).base64EncodedString())
    }

    @MainActor
    func testLateOldAccountResponseDoesNotReplaceNewAccount() async {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        let gate = RequestGate()
        await server.enqueue(
            "/admin/api/new-files",
            .init(
                json: #"{"pending":[{"name":"old.jpg","url":"/images/old.jpg"}],"gallery":[]}"#,
                gate: gate
            ))
        let old = Task { await session.refresh() }
        await server.waitForRequests(4)
        session.serverURLString = "https://new.example"
        session.password = "new-password"
        await session.connect()
        await gate.release()
        await old.value
        XCTAssertEqual(session.activeServer, "https://new.example")
        XCTAssertEqual(session.pending.first?.filename, "a.jpg")
        XCTAssertFalse(session.isLoading)
    }

    @MainActor
    func testPartialLoadPreventsSavingUnloadedConfigAndRetries() async {
        let server = TestServer()
        await server.enqueue("/admin/config", .init(status: 500, json: "{}"))
        await server.enqueue("/admin/api/collections", .init(status: 500, json: "{}"))
        let session = session(server)
        await connect(session)
        XCTAssertEqual(session.pending.count, 1)
        XCTAssertFalse(session.hasLoadedConfig)
        XCTAssertNotNil(session.configError)
        XCTAssertNotNil(session.collectionsError)
        await session.saveAIConfig()
        var requests = await server.recorded()
        XCTAssertEqual(requests.count, 3)
        await session.retryConfig()
        XCTAssertTrue(session.hasLoadedConfig)
        XCTAssertNil(session.configError)
        await session.retryCollections()
        XCTAssertNil(session.collectionsError)
        requests = await server.recorded()
        XCTAssertEqual(requests.count, 5)
    }

    @MainActor
    func testRefreshPreservesUnsavedConfigEdits() async {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        session.aiConfig.model = "edited"
        await session.refresh()
        XCTAssertEqual(session.aiConfig.model, "edited")
    }

    @MainActor
    func testInvalidConnectionAndStorageFailureDoNotActivate() async {
        let server = TestServer()
        let store = TestCredentialStore()
        let session = session(server, store: store)
        session.username = "admin"
        session.password = ""
        await session.connect()
        XCTAssertFalse(session.hasCredentials)
        var requests = await server.recorded()
        XCTAssertTrue(requests.isEmpty)
        store.failWrites = true
        session.password = "valid"
        await session.connect()
        XCTAssertFalse(session.hasCredentials)
        XCTAssertNotNil(session.lastError)
        requests = await server.recorded()
        XCTAssertTrue(requests.isEmpty)
    }

    @MainActor
    func testUploadSkippedDoesNotCreateArtwork() async {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        await server.enqueue(
            "/admin/upload",
            .init(json: #"{"saved":[],"skipped":["new.jpg"],"duplicates":[],"pending":[]}"#))
        do {
            _ = try await session.upload(imageData: Data([1]), filename: "new.jpg")
            XCTFail("Skipped upload must throw")
        } catch {
            XCTAssertFalse(session.pending.contains { $0.filename == "new.jpg" })
        }
    }

    @MainActor
    func testSavedUploadWithFailedMetadataReadRequiresReadRetry() async {
        let server = TestServer()
        let session = session(server)
        await connect(session)
        await server.enqueue(
            "/admin/upload",
            .init(json: #"{"saved":["new.jpg"],"skipped":[],"duplicates":[],"pending":[]}"#))
        await server.enqueue("/admin/api/new-files", .init(status: 500, json: "{}"))
        do {
            _ = try await session.upload(imageData: Data([1]), filename: "new.jpg")
            XCTFail("Metadata failure must be distinguished from upload failure")
        } catch ArtazzenAPI.APIError.metadataUnavailable {
            await server.enqueue(
                "/admin/api/new-files",
                .init(
                    json: #"{"pending":[{"name":"new.jpg","url":"/images/new.jpg"}],"gallery":[]}"#)
            )
            let artwork = try? await session.uploadedArtwork(filename: "new.jpg")
            XCTAssertEqual(artwork?.filename, "new.jpg")
        } catch { XCTFail("Unexpected error: \(error)") }
        let requests = await server.recorded()
        XCTAssertEqual(requests.filter { $0.url?.path == "/admin/upload" }.count, 1)
    }
}
