import Foundation

public struct Artwork: Codable, Identifiable, Hashable {
    public var id: String { filename }
    public let filename: String
    public var title: String {
        didSet { if title != oldValue { aiFields.removeAll { $0 == .title } } }
    }
    public var description: String {
        didSet { if description != oldValue { aiFields.removeAll { $0 == .description } } }
    }
    public var caption: String {
        didSet { if caption != oldValue { aiFields.removeAll { $0 == .caption } } }
    }
    public var tags: [String] {
        didSet { if tags != oldValue { aiFields.removeAll { $0 == .tags } } }
    }
    public var artist: String
    public var copyright: String
    public var collection: String
    public var status: ArtworkStatus
    public var aiGenerated: Bool
    public var aiFields: [AIField]
    public let detectedAt: Double

    public enum ArtworkStatus: String, Codable, CaseIterable {
        case pending, approved, hidden
    }

    public enum AIField: String, Codable, CaseIterable {
        case title, caption, description, tags
    }

    public var url: String?

    public enum CodingKeys: String, CodingKey {
        case filename, name, title, description, caption, tags
        case artist, copyright, collection, status, url
        case aiGenerated = "ai_generated"
        case aiFields = "ai_fields"
        case detectedAt = "detected_at"
    }

    public init(
        filename: String,
        title: String = "",
        description: String = "",
        caption: String = "",
        tags: [String] = [],
        artist: String = "",
        copyright: String = "",
        collection: String = "",
        status: ArtworkStatus = .pending,
        aiGenerated: Bool = false,
        aiFields: [AIField] = [],
        detectedAt: Double = 0,
        url: String? = nil
    ) {
        self.filename = filename
        self.title = title
        self.description = description
        self.caption = caption
        self.tags = tags
        self.artist = artist
        self.copyright = copyright
        self.collection = collection
        self.status = status
        self.aiGenerated = aiGenerated
        self.aiFields = aiFields
        self.detectedAt = detectedAt
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let filenameKey = try container.decodeIfPresent(String.self, forKey: .filename)
        let nameKey = try container.decodeIfPresent(String.self, forKey: .name)
        guard let resolved = filenameKey ?? nameKey, !resolved.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .filename,
                in: container,
                debugDescription: "Artwork requires filename or name"
            )
        }
        filename = resolved
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright) ?? ""
        collection = try container.decodeIfPresent(String.self, forKey: .collection) ?? ""
        status =
            try container.decodeIfPresent(ArtworkStatus.self, forKey: .status) ?? .pending
        aiGenerated = try container.decodeIfPresent(Bool.self, forKey: .aiGenerated) ?? false
        aiFields = try container.decodeIfPresent([AIField].self, forKey: .aiFields) ?? []
        detectedAt = try container.decodeIfPresent(Double.self, forKey: .detectedAt) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filename, forKey: .filename)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(caption, forKey: .caption)
        try container.encode(tags, forKey: .tags)
        try container.encode(artist, forKey: .artist)
        try container.encode(copyright, forKey: .copyright)
        try container.encode(collection, forKey: .collection)
        try container.encode(status, forKey: .status)
        try container.encode(aiGenerated, forKey: .aiGenerated)
        try container.encode(aiFields, forKey: .aiFields)
        try container.encode(detectedAt, forKey: .detectedAt)
        try container.encodeIfPresent(url, forKey: .url)
    }

    public var imageURL: URL? {
        if let url, !url.isEmpty {
            return URL(string: url)
        }
        return nil
    }

    public func imageURL(relativeTo base: URL) -> URL? {
        if let url, !url.isEmpty {
            if let absolute = URL(string: url), absolute.scheme != nil {
                return absolute
            }
            return URL(string: url, relativeTo: base)?.absoluteURL
        }
        return base.appendingPathComponent("static/images/\(filename)")
    }

    public func resolved(relativeTo base: URL) -> Artwork {
        var copy = self
        copy.url = imageURL(relativeTo: base)?.absoluteString
        return copy
    }

    public static func fromSidecar(
        filename: String,
        url: String?,
        sidecar: SidecarPayload?,
        relativeTo base: URL
    ) -> Artwork {
        let payload = sidecar ?? SidecarPayload()
        return Artwork(
            filename: filename,
            title: payload.title,
            description: payload.description,
            caption: payload.caption,
            tags: payload.tags,
            artist: payload.artist,
            copyright: payload.copyright,
            collection: payload.collection,
            status: payload.status,
            aiGenerated: payload.aiGenerated,
            aiFields: payload.aiFields,
            detectedAt: payload.detectedAt,
            url: url
        ).resolved(relativeTo: base)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
    }

    public func fieldValue(_ field: AIField) -> [String] {
        switch field {
        case .title: return [title]
        case .description: return [description]
        case .caption: return [caption]
        case .tags: return tags
        }
    }

    public mutating func applyPreview(_ preview: Artwork, field: AIField) {
        guard filename == preview.filename else { return }
        switch field {
        case .title: title = preview.title
        case .description: description = preview.description
        case .caption: caption = preview.caption
        case .tags: tags = preview.tags
        }
        if !aiFields.contains(field) { aiFields.append(field) }
        aiGenerated = true
    }

    public static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        lhs.filename == rhs.filename
    }
}

/// Backend image sidecar fields (see ArtazzenDotCom `ImageSidecar.schema.json`).
public struct SidecarPayload: Decodable, Equatable {
    public var title: String = ""
    public var description: String = ""
    public var caption: String = ""
    public var tags: [String] = []
    public var artist: String = ""
    public var copyright: String = ""
    public var collection: String = ""
    public var status: Artwork.ArtworkStatus = .pending
    public var aiGenerated: Bool = false
    public var aiFields: [Artwork.AIField] = []
    public var detectedAt: Double = 0

    public enum CodingKeys: String, CodingKey {
        case title, description, caption, tags, artist, copyright, collection, status
        case aiGenerated = "ai_generated"
        case aiFields = "ai_fields"
        case detectedAt = "detected_at"
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright) ?? ""
        collection = try container.decodeIfPresent(String.self, forKey: .collection) ?? ""
        status =
            try container.decodeIfPresent(Artwork.ArtworkStatus.self, forKey: .status)
            ?? .pending
        aiGenerated = try container.decodeIfPresent(Bool.self, forKey: .aiGenerated) ?? false
        aiFields =
            try container.decodeIfPresent([Artwork.AIField].self, forKey: .aiFields) ?? []
        detectedAt = try container.decodeIfPresent(Double.self, forKey: .detectedAt) ?? 0
    }
}

public struct CollectionSummary: Codable, Identifiable, Hashable {
    public let id: String
    public var title: String?
    public var count: Int?

    public var displayName: String {
        if let title, !title.isEmpty { return title }
        return id
    }
}
