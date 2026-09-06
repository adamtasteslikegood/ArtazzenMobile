import Foundation

public struct AIConfig: Codable, Equatable {
    public static var defaults: AIConfig {
        AIConfig(enabled: true, model: "gpt-4o-mini", temperature: 0.6, maxOutputTokens: 600)
    }
    public var enabled: Bool
    public var model: String
    public var temperature: Double
    public var maxOutputTokens: Int

    public init(enabled: Bool, model: String, temperature: Double, maxOutputTokens: Int) {
        self.enabled = enabled
        self.model = model
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }

    public enum CodingKeys: String, CodingKey {
        case enabled, model, temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

public struct AIConfigResponse: Codable {
    public let ai: AIConfig
}
