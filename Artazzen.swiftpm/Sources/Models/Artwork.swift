import Foundation

struct Artwork: Codable, Identifiable, Hashable {
    var id: String { filename }
    let filename: String
    var title: String
    var description: String
    var caption: String
    var tags: [String]
    var artist: String
    var copyright: String
    var collection: String
    var status: ArtworkStatus
    var aiGenerated: Bool
    var aiFields: [AIField]
    let detectedAt: Double

    enum ArtworkStatus: String, Codable, CaseIterable {
        case pending, approved, hidden
    }

    enum AIField: String, Codable, CaseIterable {
        case title, caption, description, tags
    }

    var url: String?

    enum CodingKeys: String, CodingKey {
        case filename, name, title, description, caption, tags
        case artist, copyright, collection, status, url
        case aiGenerated = "ai_generated"
        case aiFields = "ai_fields"
        case detectedAt = "detected_at"
    }

    init(
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

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    var imageURL: URL? {
        if let url, !url.isEmpty {
            return URL(string: url)
        }
        return nil
    }

    func imageURL(relativeTo base: URL) -> URL? {
        if let url, !url.isEmpty {
            if let absolute = URL(string: url), absolute.scheme != nil {
                return absolute
            }
            return URL(string: url, relativeTo: base)?.absoluteURL
        }
        return base.appendingPathComponent("static/images/\(filename)")
    }

    func resolved(relativeTo base: URL) -> Artwork {
        var copy = self
        copy.url = imageURL(relativeTo: base)?.absoluteString
        return copy
    }

    static func fromSidecar(
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
    }

    static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        lhs.filename == rhs.filename
    }
}

/// Backend image sidecar fields (see ArtazzenDotCom `ImageSidecar.schema.json`).
struct SidecarPayload: Decodable, Equatable {
    var title: String = ""
    var description: String = ""
    var caption: String = ""
    var tags: [String] = []
    var artist: String = ""
    var copyright: String = ""
    var collection: String = ""
    var status: Artwork.ArtworkStatus = .pending
    var aiGenerated: Bool = false
    var aiFields: [Artwork.AIField] = []
    var detectedAt: Double = 0

    enum CodingKeys: String, CodingKey {
        case title, description, caption, tags, artist, copyright, collection, status
        case aiGenerated = "ai_generated"
        case aiFields = "ai_fields"
        case detectedAt = "detected_at"
    }

    init() {}

    init(from decoder: Decoder) throws {
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

struct CollectionSummary: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var count: Int?

    var displayName: String {
        if let title, !title.isEmpty { return title }
        return id
    }
}
