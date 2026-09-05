import Foundation

package struct AIConfig: Codable, Equatable {
    package static var defaults: AIConfig {
        AIConfig(enabled: true, model: "gpt-4o-mini", temperature: 0.6, maxOutputTokens: 600)
    }
    package var enabled: Bool
    package var model: String
    package var temperature: Double
    package var maxOutputTokens: Int

    package init(enabled: Bool, model: String, temperature: Double, maxOutputTokens: Int) {
        self.enabled = enabled
        self.model = model
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }

    package enum CodingKeys: String, CodingKey {
        case enabled, model, temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

package struct AIConfigResponse: Codable {
    package let ai: AIConfig
}
