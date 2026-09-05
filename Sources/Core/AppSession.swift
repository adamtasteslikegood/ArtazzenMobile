import Foundation
import Observation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum SettingsStorage {
    public static let serverURL = "az-server-url"
    public static let username = "az-username"
    static let password = "az-password"
    public static let darkMode = "az-dark-mode"
    public static let defaultServerURL = "https://artazzen.com"
}

@MainActor
@Observable
public final class AppSession {
    public var serverURLString: String
    public var username: String
    public var password: String
    public private(set) var pending: [Artwork] = []
    public private(set) var gallery: [Artwork] = []
    public private(set) var collections: [CollectionSummary] = []
    public var aiConfig = AIConfig.defaults {
        didSet { configDirty = true }
    }
    public private(set) var hasLoadedConfig = false
    public private(set) var isLoading = false
    public private(set) var isSavingConfig = false
    public private(set) var mutations: Set<String> = []
    public private(set) var previews: Set<String> = []
    public private(set) var connectionID = UUID()
    public var lastError: String?
    public var lastMessage: String?
    public private(set) var collectionsError: String?
    public private(set) var configError: String?

    private var connection: Connection?
    private let defaults: UserDefaults
    private let credentialStore: any CredentialStore
    private let transport: ArtazzenAPI.Transport
    private var filesRequest = UUID()
    private var configRequest = UUID()
    private var collectionsRequest = UUID()
    private var revision = 0
    private var configDirty = false

    public var hasCredentials: Bool { connection != nil }
    public var activeServer: String? { connection?.baseURL.absoluteString }

    public init(
        defaults: UserDefaults = .standard,
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        transport: @escaping ArtazzenAPI.Transport = { try await ArtazzenAPI.send($0) }
    ) {
        self.defaults = defaults
        self.credentialStore = credentialStore
        self.transport = transport
        serverURLString =
            defaults.string(forKey: SettingsStorage.serverURL) ?? SettingsStorage.defaultServerURL
        username = defaults.string(forKey: SettingsStorage.username) ?? ""
        password = ""
        restoreConnection()
    }

    private func restoreConnection() {
        guard
            let identity = try? Connection(
                server: serverURLString, username: username, password: "lookup")
        else {
            return
        }
        do {
            if let saved = try credentialStore.read(key: identity.credentialKey) {
                password = saved
                defaults.removeObject(forKey: SettingsStorage.password)
            } else if let legacy = defaults.string(forKey: SettingsStorage.password) {
                try credentialStore.write(legacy, key: identity.credentialKey)
                password = legacy
                defaults.removeObject(forKey: SettingsStorage.password)
            }
            connection = try? Connection(
                server: serverURLString, username: username, password: password)
        } catch { lastError = error.localizedDescription }
    }

    public func loadDraftPassword() {
        password = ""
        guard
            let identity = try? Connection(
                server: serverURLString, username: username, password: "lookup")
        else {
            return
        }
        do { password = try credentialStore.read(key: identity.credentialKey) ?? "" } catch {
            lastError = error.localizedDescription
        }
    }

    public func connect() async {
        lastError = nil
        lastMessage = nil
        do {
            let selected = try Connection(
                server: serverURLString, username: username, password: password)
            try credentialStore.write(selected.password, key: selected.credentialKey)
            defaults.set(selected.baseURL.absoluteString, forKey: SettingsStorage.serverURL)
            defaults.set(selected.username, forKey: SettingsStorage.username)
            connection = selected
            connectionID = UUID()
            pending = []
            gallery = []
            collections = []
            mutations = []
            previews = []
            hasLoadedConfig = false
            isSavingConfig = false
            configDirty = false
            configError = nil
            collectionsError = nil
            await refresh()
        } catch { lastError = error.localizedDescription }
    }

    private func makeAPI() throws -> ArtazzenAPI {
        guard let connection else { throw CredentialError.invalidConnection }
        return ArtazzenAPI(
            baseURL: connection.baseURL, username: connection.username,
            password: connection.password, transport: transport
        )
    }

    public func refresh() async {
        guard mutations.isEmpty else { return }
        let generation = connectionID
        let request = UUID()
        let startingRevision = revision
        filesRequest = request
        isLoading = true
        lastError = nil
        lastMessage = nil
        defer { if generation == connectionID && filesRequest == request { isLoading = false } }
        do {
            let api = try makeAPI()
            let files = try await api.fetchFiles()
            let mapped = await api.artworks(from: files)
            guard generation == connectionID, filesRequest == request, revision == startingRevision
            else { return }
            pending = mapped.pending
            gallery = mapped.gallery
            lastMessage = "Loaded \(pending.count) pending, \(gallery.count) gallery."
        } catch {
            guard generation == connectionID, filesRequest == request, revision == startingRevision
            else { return }
            lastError = "Could not load artwork. \(error.localizedDescription)"
        }
        guard generation == connectionID, filesRequest == request else { return }
        await retryCollections()
        guard generation == connectionID, filesRequest == request else { return }
        await retryConfig()
    }

    public func retryCollections() async {
        let generation = connectionID
        let request = UUID()
        collectionsRequest = request
        do {
            let result = try await makeAPI().fetchCollections()
            guard generation == connectionID, request == collectionsRequest else { return }
            collections = result
            collectionsError = nil
        } catch {
            guard generation == connectionID, request == collectionsRequest else { return }
            collectionsError = "Collections could not be loaded. Retry."
        }
    }

    public func retryConfig() async {
        guard !isSavingConfig else { return }
        let generation = connectionID
        let request = UUID()
        configRequest = request
        do {
            let result = try await makeAPI().fetchConfig()
            guard generation == connectionID, request == configRequest else { return }
            if !hasLoadedConfig || !configDirty {
                aiConfig = result
                configDirty = false
            }
            hasLoadedConfig = true
            configError = nil
        } catch {
            guard generation == connectionID, request == configRequest else { return }
            configError = "AI settings could not be loaded. Retry."
        }
    }
}

extension AppSession {
    @discardableResult
    public func approve(_ artwork: Artwork) async -> Bool {
        await save(artwork)
    }

    public func hide(_ artwork: Artwork) {
        guard mutations.isEmpty else { return }
        revision += 1
        pending.removeAll { $0.filename == artwork.filename }
    }

    // A mutation invalidates older reads even on the same connection.
    // Ready -> Saving -> confirmed local update, or retained draft + error.
    @discardableResult
    public func save(_ artwork: Artwork) async -> Bool {
        guard !mutations.contains(artwork.filename), previews.isEmpty else { return false }
        let generation = connectionID
        mutations.insert(artwork.filename)
        revision += 1
        lastError = nil
        lastMessage = nil
        defer { if generation == connectionID { mutations.remove(artwork.filename) } }
        do {
            try await makeAPI().saveMetadata(artwork)
            guard generation == connectionID else { return false }
            revision += 1
            var approved = artwork
            approved.status = .approved
            pending.removeAll { $0.filename == artwork.filename }
            gallery.removeAll { $0.filename == artwork.filename }
            gallery.insert(approved, at: 0)
            lastMessage = "Saved and approved \(artwork.filename)."
            return true
        } catch {
            guard generation == connectionID else { return false }
            lastError = "Save failed for \(artwork.filename). \(error.localizedDescription)"
            return false
        }
    }

    public func upload(
        imageData: Data, filename: String, contentType: String = "image/jpeg"
    ) async throws -> Artwork {
        guard !mutations.contains(filename) else { throw ArtazzenAPI.APIError.requestFailed }
        let generation = connectionID
        mutations.insert(filename)
        revision += 1
        defer { if generation == connectionID { mutations.remove(filename) } }
        let api = try makeAPI()
        let response = try await api.upload(
            imageData: imageData, filename: filename, contentType: contentType)
        guard generation == connectionID else { throw CancellationError() }
        revision += 1
        if let item = response.pending.first(where: { $0.name == filename }) {
            let artwork = Artwork.fromSidecar(
                filename: item.name, url: item.url, sidecar: item.metadata, relativeTo: api.baseURL
            )
            pending.removeAll { $0.filename == filename }
            pending.insert(artwork, at: 0)
            return artwork
        }
        return try await uploadedArtwork(filename: filename)
    }

    public func uploadedArtwork(filename: String) async throws -> Artwork {
        let generation = connectionID
        let api = try makeAPI()
        do {
            let files = try await api.fetchFiles()
            let mapped = await api.artworks(from: files)
            guard generation == connectionID else { throw CancellationError() }
            guard
                let artwork = (mapped.pending + mapped.gallery).first(where: {
                    $0.filename == filename
                })
            else {
                throw ArtazzenAPI.APIError.metadataUnavailable
            }
            return artwork
        } catch {
            if generation != connectionID { throw CancellationError() }
            throw ArtazzenAPI.APIError.metadataUnavailable
        }
    }

    public func regenerate(image: String, fields: [Artwork.AIField]) async -> Artwork? {
        guard !previews.contains(image), !mutations.contains(image) else { return nil }
        let generation = connectionID
        previews.insert(image)
        lastError = nil
        lastMessage = nil
        defer { if generation == connectionID { previews.remove(image) } }
        do {
            let result = try await makeAPI().regenerateFields(image: image, fields: fields)
            guard generation == connectionID else { return nil }
            return result
        } catch {
            guard generation == connectionID else { return nil }
            lastError = "AI preview failed. Your draft has been kept."
            return nil
        }
    }

    public func saveAIConfig() async {
        guard hasLoadedConfig, !isSavingConfig else { return }
        let generation = connectionID
        let config = aiConfig
        configRequest = UUID()
        isSavingConfig = true
        lastError = nil
        lastMessage = nil
        defer { if generation == connectionID { isSavingConfig = false } }
        do {
            try await makeAPI().updateConfig(config)
            guard generation == connectionID else { return }
            if aiConfig == config { configDirty = false }
            lastMessage = "Saved AI settings."
        } catch {
            guard generation == connectionID else { return }
            lastError = "Could not save AI settings."
        }
    }
}
