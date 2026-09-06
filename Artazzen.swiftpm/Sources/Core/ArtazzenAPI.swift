import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public actor ArtazzenAPI {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport
    public let baseURL: URL
    private let credentials: (username: String, password: String)

    public init(
        baseURL: URL, username: String, password: String,
        transport: @escaping Transport = { try await ArtazzenAPI.send($0) }
    ) {
        self.transport = transport
        self.baseURL = baseURL
        self.credentials = (username, password)
    }

    private func authHeader() -> String {
        let encoded = Data("\(credentials.username):\(credentials.password)".utf8)
            .base64EncodedString()
        return "Basic \(encoded)"
    }

    private func resolveURL(_ path: String) -> URL {
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(clean)
    }

    private func request(
        _ path: String, method: String = "GET", body: Data? = nil
    ) async throws -> Data {
        var req = URLRequest(url: resolveURL(path))
        req.httpMethod = method
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(req)
        guard 200..<300 ~= response.statusCode else {
            throw APIError.requestFailed
        }
        return data
    }

    struct PendingResponse: Decodable {
        let pending: [PendingItem]
        let gallery: [GalleryItem]
    }

    struct PendingItem: Decodable {
        let name: String
        let url: String
        let metadata: SidecarPayload?
    }

    struct GalleryItem: Decodable {
        let name: String
        let url: String
        let sidecar: SidecarPayload

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
            sidecar = try SidecarPayload(from: decoder)
        }

        private enum CodingKeys: String, CodingKey {
            case name, url
        }
    }

    func fetchFiles() async throws -> PendingResponse {
        let data = try await request("/admin/api/new-files")
        return try JSONDecoder().decode(PendingResponse.self, from: data)
    }

    func artworks(from response: PendingResponse) -> (pending: [Artwork], gallery: [Artwork]) {
        let pending = response.pending.map {
            Artwork.fromSidecar(
                filename: $0.name,
                url: $0.url,
                sidecar: $0.metadata,
                relativeTo: baseURL
            )
        }
        let gallery = response.gallery.map {
            Artwork.fromSidecar(
                filename: $0.name,
                url: $0.url,
                sidecar: $0.sidecar,
                relativeTo: baseURL
            )
        }
        return (pending, gallery)
    }

    public func saveMetadata(_ artwork: Artwork) async throws {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "title", value: artwork.title),
            URLQueryItem(name: "description", value: artwork.description),
            URLQueryItem(name: "caption", value: artwork.caption),
            URLQueryItem(name: "tags", value: artwork.tags.joined(separator: ", ")),
            URLQueryItem(name: "artist", value: artwork.artist),
            URLQueryItem(name: "copyright", value: artwork.copyright),
            URLQueryItem(name: "collection", value: artwork.collection),
            URLQueryItem(name: "action", value: "save"),
            URLQueryItem(
                name: "ai_fields", value: artwork.aiFields.map(\.rawValue).joined(separator: ",")),
            URLQueryItem(name: "ai_generated", value: artwork.aiGenerated ? "true" : "false"),
        ]
        let body = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(
            using: .utf8)
        var req = URLRequest(url: resolveURL("admin/metadata/\(artwork.filename)"))
        req.httpMethod = "POST"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (_, response) = try await transport(req)
        guard 200..<300 ~= response.statusCode || response.statusCode == 303 else {
            throw APIError.requestFailed
        }
    }

    struct RegenRequest: Codable {
        let images: [String]
        let fields: [String]?
        let force: Bool
        let preview: Bool
    }

    struct RegenResponse: Decodable {
        struct Updated: Decodable {
            let name: String
            let metadata: SidecarPayload
        }
        let updated: [Updated]
        let errors: [[String: String]]
    }

    public func regenerateFields(
        image: String, fields: [Artwork.AIField], force: Bool = true
    ) async throws -> Artwork? {
        let body = try JSONEncoder().encode(
            RegenRequest(
                images: [image],
                fields: fields.map(\.rawValue),
                force: force,
                preview: true
            ))
        let data = try await request("/admin/ai/regenerate", method: "POST", body: body)
        let response = try JSONDecoder().decode(RegenResponse.self, from: data)
        guard response.errors.isEmpty,
            let updated = response.updated.first(where: { $0.name == image })
        else { throw APIError.generationFailed }
        return Artwork.fromSidecar(
            filename: updated.name, url: nil, sidecar: updated.metadata, relativeTo: baseURL)
    }

    public func upload(
        imageData: Data, filename: String, contentType: String = "image/jpeg"
    ) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        var req = URLRequest(url: resolveURL("admin/upload"))
        req.httpMethod = "POST"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await transport(req)
        guard 200..<300 ~= response.statusCode else {
            throw APIError.requestFailed
        }
        let result = try JSONDecoder().decode(UploadResponse.self, from: data)
        guard
            result.saved.contains(filename)
                || result.duplicates.contains(where: { $0.name == filename })
        else {
            throw APIError.uploadSkipped
        }
        return result
    }

    public func unapprove(_ name: String) async throws {
        _ = try await request("/admin/unapprove/\(name)", method: "POST")
    }

    public func delete(_ name: String) async throws {
        _ = try await request("/admin/delete/\(name)", method: "POST")
    }

    public func fetchCollections() async throws -> [CollectionSummary] {
        struct Response: Codable { let collections: [CollectionSummary] }
        let data = try await request("/admin/api/collections")
        return try JSONDecoder().decode(Response.self, from: data).collections
    }

    public func fetchConfig() async throws -> AIConfig {
        let data = try await request("/admin/config")
        return try JSONDecoder().decode(AIConfigResponse.self, from: data).ai
    }

    public func updateConfig(_ config: AIConfig) async throws {
        struct Body: Codable { let ai: AIConfig }
        let body = try JSONEncoder().encode(Body(ai: config))
        _ = try await request("/admin/config", method: "POST", body: body)
    }

    public struct UploadResponse: Decodable {
        struct Duplicate: Decodable { let name: String }
        let saved: [String]
        let skipped: [String]
        let duplicates: [Duplicate]
        let pending: [PendingItem]
    }

    public static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(
            for: request, delegate: NoRedirects())
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed }
        return (data, http)
    }

    public enum APIError: LocalizedError {
        case requestFailed, generationFailed, uploadSkipped, metadataUnavailable
        public var errorDescription: String? {
            switch self {
            case .requestFailed:
                return "The server rejected the request. Check the connection and credentials."
            case .generationFailed: return "AI generation failed. Your draft has been kept."
            case .uploadSkipped:
                return "The server did not save this image. Check its format and size."
            case .metadataUnavailable:
                return "The image was saved, but its metadata could not be loaded. Retry loading."
            }
        }
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
