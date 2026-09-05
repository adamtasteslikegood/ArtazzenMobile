import Foundation
import Observation

enum SettingsStorage {
    static let serverURL = "az-server-url"
    static let username = "az-username"
    static let password = "az-password"
    static let darkMode = "az-dark-mode"
    static let defaultServerURL = "https://artazzen.com"
}

@MainActor
@Observable
final class AppSession {
    var serverURLString: String
    var username: String
    var password: String
    var pending: [Artwork] = []
    var gallery: [Artwork] = []
    var collections: [CollectionSummary] = []
    var aiConfig = AIConfig(
        enabled: true,
        model: "gpt-4o-mini",
        temperature: 0.6,
        maxOutputTokens: 600
    )
    var isLoading = false
    var lastError: String?
    var lastMessage: String?

    var baseURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var hasCredentials: Bool {
        baseURL != nil && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        let defaults = UserDefaults.standard
        serverURLString =
            defaults.string(forKey: SettingsStorage.serverURL)
            ?? SettingsStorage.defaultServerURL
        username = defaults.string(forKey: SettingsStorage.username) ?? ""
        password = defaults.string(forKey: SettingsStorage.password) ?? ""
    }

    func persistConnection() {
        let defaults = UserDefaults.standard
        defaults.set(serverURLString, forKey: SettingsStorage.serverURL)
        defaults.set(username, forKey: SettingsStorage.username)
        defaults.set(password, forKey: SettingsStorage.password)
    }

    func makeAPI() throws -> ArtazzenAPI {
        guard let baseURL else {
            throw ArtazzenAPI.APIError.requestFailed
        }
        return ArtazzenAPI(
            baseURL: baseURL,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }

    func refresh() async {
        guard hasCredentials else {
            lastError = "Add the gallery URL and admin username in Settings."
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let api = try makeAPI()
            let files = try await api.fetchFiles()
            let mapped = await api.artworks(from: files)
            pending = mapped.pending
            gallery = mapped.gallery
            collections = (try? await api.fetchCollections()) ?? []
            if let config = try? await api.fetchConfig() {
                aiConfig = config
            }
            lastMessage = "Loaded \(pending.count) pending, \(gallery.count) gallery."
        } catch {
            lastError = "Could not reach the Artazzen admin API. Check URL and credentials."
        }
    }

    func approve(_ artwork: Artwork) async {
        do {
            let api = try makeAPI()
            var approved = artwork
            approved.status = .approved
            try await api.saveMetadata(approved)
            pending.removeAll { $0.filename == artwork.filename }
            if !gallery.contains(approved) {
                gallery.insert(approved, at: 0)
            }
        } catch {
            lastError = "Approve failed for \(artwork.filename)."
        }
    }

    func hide(_ artwork: Artwork) {
        pending.removeAll { $0.filename == artwork.filename }
    }

    func save(_ artwork: Artwork) async {
        do {
            let api = try makeAPI()
            try await api.saveMetadata(artwork)
            await refresh()
            lastMessage = "Saved \(artwork.filename)."
        } catch {
            lastError = "Save failed for \(artwork.filename)."
        }
    }

    func upload(imageData: Data, filename: String) async {
        do {
            let api = try makeAPI()
            try await api.upload(imageData: imageData, filename: filename)
            await refresh()
            lastMessage = "Uploaded \(filename)."
        } catch {
            lastError = "Upload failed for \(filename)."
        }
    }

    func regenerate(image: String, fields: [Artwork.AIField]) async -> Artwork? {
        do {
            let api = try makeAPI()
            let updated = try await api.regenerateFields(image: image, fields: fields)
            if let updated {
                await refresh()
                return updated.resolved(relativeTo: api.baseURL)
            }
        } catch {
            lastError = "AI regenerate failed."
        }
        return nil
    }

    func saveAIConfig() async {
        do {
            let api = try makeAPI()
            try await api.updateConfig(aiConfig)
            lastMessage = "Saved AI settings."
        } catch {
            lastError = "Could not save AI settings."
        }
    }
}
