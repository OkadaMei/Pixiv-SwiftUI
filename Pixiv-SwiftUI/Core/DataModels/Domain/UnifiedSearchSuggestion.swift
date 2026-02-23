import Foundation

enum TagMatchType: Int, Codable {
    case exactName = 0
    case prefixName = 1
    case exactTranslation = 2
    case prefixTranslation = 3
    case containsName = 4
    case containsTranslation = 5
}

enum SuggestionSource: Codable {
    case localTranslation(matchType: TagMatchType)
    case officialAPI
}

struct UnifiedSearchSuggestion: Identifiable, Hashable {
    let id: String
    let tagName: String
    let displayTranslation: String?
    let source: SuggestionSource

    init(tagName: String, displayTranslation: String?, source: SuggestionSource) {
        self.id = tagName
        self.tagName = tagName
        self.displayTranslation = displayTranslation
        self.source = source
    }

    var matchType: TagMatchType? {
        switch source {
        case .localTranslation(let type):
            return type
        case .officialAPI:
            return nil
        }
    }

    var isLocalMatch: Bool {
        if case .localTranslation = source {
            return true
        }
        return false
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tagName)
    }

    static func == (lhs: UnifiedSearchSuggestion, rhs: UnifiedSearchSuggestion) -> Bool {
        return lhs.tagName == rhs.tagName
    }
}
