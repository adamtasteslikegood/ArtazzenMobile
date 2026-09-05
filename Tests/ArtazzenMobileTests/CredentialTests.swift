import Foundation
import XCTest

@testable import ArtazzenCore

final class CredentialTests: XCTestCase {
    func testConnectionNormalizesIdentityAndPreservesPassword() throws {
        let first = try Connection(
            server: " https://EXAMPLE.com:443/ ", username: " admin ", password: " secret ")
        let second = try Connection(
            server: "https://example.com", username: "admin", password: "different")
        XCTAssertEqual(first.credentialKey, second.credentialKey)
        XCTAssertEqual(first.password, " secret ")
        XCTAssertNotEqual(
            first.credentialKey,
            try Connection(server: "https://example.com", username: "other", password: "x")
                .credentialKey
        )
    }

    func testInvalidURLsAndBlankCredentialsAreRejected() {
        for server in [
            "relative", "file:///tmp/a", "http://example.com", "https://u:p@example.com",
            "https://example.com?q=x", "https://example.com/#x",
        ] {
            XCTAssertThrowsError(
                try Connection(server: server, username: "admin", password: "secret"))
        }
        XCTAssertThrowsError(
            try Connection(server: "https://example.com", username: " ", password: "secret"))
        XCTAssertThrowsError(
            try Connection(server: "https://example.com", username: "admin", password: "  "))
    }

    @MainActor
    func testLegacyMigrationOnlyRemovesPasswordAfterSuccessfulWrite() async throws {
        let name = "ArtazzenMigration-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("https://example.com", forKey: SettingsStorage.serverURL)
        defaults.set("admin", forKey: SettingsStorage.username)
        defaults.set("legacy", forKey: SettingsStorage.password)
        let store = TestCredentialStore()
        store.failWrites = true
        let failed = AppSession(defaults: defaults, credentialStore: store)
        XCTAssertFalse(failed.hasCredentials)
        XCTAssertNotNil(failed.lastError)
        XCTAssertEqual(defaults.string(forKey: SettingsStorage.password), "legacy")
        store.failWrites = false
        let migrated = AppSession(defaults: defaults, credentialStore: store)
        XCTAssertTrue(migrated.hasCredentials)
        XCTAssertEqual(migrated.password, "legacy")
        XCTAssertNil(defaults.string(forKey: SettingsStorage.password))
        let restored = AppSession(defaults: defaults, credentialStore: store)
        XCTAssertEqual(restored.password, "legacy")
    }

    @MainActor
    func testExistingKeychainValueWinsOverLegacyPassword() async throws {
        let name = "ArtazzenMigration-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("https://example.com", forKey: SettingsStorage.serverURL)
        defaults.set("admin", forKey: SettingsStorage.username)
        defaults.set("old", forKey: SettingsStorage.password)
        let identity = try Connection(
            server: "https://example.com", username: "admin", password: "new")
        let store = TestCredentialStore()
        store.values[identity.credentialKey] = "new"
        let session = AppSession(defaults: defaults, credentialStore: store)
        XCTAssertEqual(session.password, "new")
        XCTAssertNil(defaults.string(forKey: SettingsStorage.password))
        session.username = "other"
        session.loadDraftPassword()
        XCTAssertEqual(session.password, "")
        XCTAssertTrue(session.hasCredentials)
    }
}
