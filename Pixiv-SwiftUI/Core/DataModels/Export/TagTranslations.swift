import Foundation

/// 标签翻译数据模型（多语言版本）
/// tags 为 [tagName: [languageCode: translation]]
/// 例: { "R-18": { "zh": "18禁" }, "オリジナル": { "zh": "原创" } }
struct TagTranslations: Codable {
    let timestamp: String
    let tags: [String: [String: String]]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case tags
    }
}
