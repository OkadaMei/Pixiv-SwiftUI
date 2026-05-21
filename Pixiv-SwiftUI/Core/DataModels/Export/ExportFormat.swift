import Foundation

struct ExportHeader: Codable {
    let version: Int
    let type: ExportDataType
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case version
        case type
        case exportedAt = "exported_at"
    }
}

enum ExportDataType: String, Codable {
    case searchHistory
    case glanceHistory
    case muteData
    case crashReport
}

struct SearchHistoryExport: Codable {
    let tagHistory: [TagHistoryItem]
    let bookTags: [String]

    enum CodingKeys: String, CodingKey {
        case tagHistory = "tag_history"
        case bookTags = "book_tags"
    }
}

struct TagHistoryItem: Codable {
    let name: String
    let translatedName: String?
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
        case type
    }
}

struct GlanceHistoryExport: Codable {
    let illustHistory: [IllustHistoryItem]
    let novelHistory: [NovelHistoryItem]

    enum CodingKeys: String, CodingKey {
        case illustHistory = "illust_history"
        case novelHistory = "novel_history"
    }
}

struct IllustHistoryItem: Codable, Sendable {
    let illustId: Int
    let viewedAt: Int64
    let title: String?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case illustId = "illust_id"
        case viewedAt = "viewed_at"
        case title
        case userName = "user_name"
    }
}

struct NovelHistoryItem: Codable, Sendable {
    let novelId: Int
    let viewedAt: Int64
    let title: String?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case viewedAt = "viewed_at"
        case title
        case userName = "user_name"
    }
}

struct MuteDataExport: Codable {
    let banTags: [BanTagItem]
    let banUserIds: [BanUserIdItem]
    let banIllustIds: [BanIllustIdItem]
    let banNovelIds: [BanNovelIdItem]
    let banNovelTitleKeywords: [String]
    let banNovelSeriesKeywords: [String]
    let banNovelCaptionKeywords: [String]

    init(
        banTags: [BanTagItem],
        banUserIds: [BanUserIdItem],
        banIllustIds: [BanIllustIdItem],
        banNovelIds: [BanNovelIdItem] = [],
        banNovelTitleKeywords: [String] = [],
        banNovelSeriesKeywords: [String] = [],
        banNovelCaptionKeywords: [String] = []
    ) {
        self.banTags = banTags
        self.banUserIds = banUserIds
        self.banIllustIds = banIllustIds
        self.banNovelIds = banNovelIds
        self.banNovelTitleKeywords = banNovelTitleKeywords
        self.banNovelSeriesKeywords = banNovelSeriesKeywords
        self.banNovelCaptionKeywords = banNovelCaptionKeywords
    }

    enum CodingKeys: String, CodingKey {
        case banTags = "ban_tags"
        case banUserIds = "ban_user_ids"
        case banIllustIds = "ban_illust_ids"
        case banNovelIds = "ban_novel_ids"
        case banNovelTitleKeywords = "ban_novel_title_keywords"
        case banNovelSeriesKeywords = "ban_novel_series_keywords"
        case banNovelCaptionKeywords = "ban_novel_caption_keywords"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.banTags = try container.decodeIfPresent([BanTagItem].self, forKey: .banTags) ?? []
        self.banUserIds = try container.decodeIfPresent([BanUserIdItem].self, forKey: .banUserIds) ?? []
        self.banIllustIds = try container.decodeIfPresent([BanIllustIdItem].self, forKey: .banIllustIds) ?? []
        self.banNovelIds = try container.decodeIfPresent([BanNovelIdItem].self, forKey: .banNovelIds) ?? []
        self.banNovelTitleKeywords = try container.decodeIfPresent([String].self, forKey: .banNovelTitleKeywords) ?? []
        self.banNovelSeriesKeywords = try container.decodeIfPresent([String].self, forKey: .banNovelSeriesKeywords) ?? []
        self.banNovelCaptionKeywords = try container.decodeIfPresent([String].self, forKey: .banNovelCaptionKeywords) ?? []
    }
}

struct BanTagItem: Codable, Sendable {
    let name: String
    let translatedName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
}

struct BanUserIdItem: Codable, Sendable {
    let userId: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
    }
}

struct BanIllustIdItem: Codable, Sendable {
    let illustId: Int
    let name: String?

    enum CodingKeys: String, CodingKey {
        case illustId = "illust_id"
        case name
    }
}

struct BanNovelIdItem: Codable, Sendable {
    let novelId: Int
    let name: String?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case name
    }
}

enum ImportConflictStrategy: String, Identifiable {
    case merge
    case replace
    case cancel

    var id: String { rawValue }
}
