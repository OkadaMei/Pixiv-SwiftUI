import Foundation

/// 插画信息 DTO — 严格匹配 Pixiv App API JSON 格式，纯 Codable 结构体
nonisolated struct IllustDTO: Codable {
    let id: Int
    let title: String
    let type: String
    let imageUrls: ImageUrlsDTO
    let caption: String
    let restrict: Int
    let user: UserDTO
    let tags: [TagDTO]
    let tools: [String]
    let createDate: String
    let pageCount: Int
    let width: Int
    let height: Int
    let sanityLevel: Int
    let xRestrict: Int
    let metaSinglePage: MetaSinglePageDTO?
    let metaPages: [MetaPagesDTO]
    let totalView: Int
    let totalBookmarks: Int
    let isBookmarked: Bool
    let bookmarkRestrict: String?
    let visible: Bool
    let isMuted: Bool
    let illustAIType: Int
    let series: IllustSeriesDTO?
    let illustBookStyle: Int?
    let totalComments: Int?
    let restrictionAttributes: [String]
    let ownerId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case imageUrls = "image_urls"
        case caption
        case restrict
        case user
        case tags
        case tools
        case createDate = "create_date"
        case pageCount = "page_count"
        case width
        case height
        case sanityLevel = "sanity_level"
        case xRestrict = "x_restrict"
        case metaSinglePage = "meta_single_page"
        case metaPages = "meta_pages"
        case totalView = "total_view"
        case totalBookmarks = "total_bookmarks"
        case isBookmarked = "is_bookmarked"
        case bookmarkRestrict = "bookmark_restrict"
        case visible
        case isMuted = "is_muted"
        case illustAIType = "illust_ai_type"
        case series
        case illustBookStyle = "illust_book_style"
        case totalComments = "total_comments"
        case restrictionAttributes
        case ownerId
    }
}

// MARK: - Mapping

extension IllustDTO {
    nonisolated func toDomain() -> Illusts {
        Illusts(
            id: id,
            title: title,
            type: type,
            imageUrls: imageUrls.toDomain(),
            caption: caption,
            restrict: restrict,
            user: user.toDomain(),
            tags: tags.map { $0.toDomain() },
            tools: tools,
            createDate: createDate,
            pageCount: pageCount,
            width: width,
            height: height,
            sanityLevel: sanityLevel,
            xRestrict: xRestrict,
            metaSinglePage: metaSinglePage?.toDomain(),
            metaPages: metaPages.map { $0.toDomain() },
            totalView: totalView,
            totalBookmarks: totalBookmarks,
            isBookmarked: isBookmarked,
            bookmarkRestrict: bookmarkRestrict,
            visible: visible,
            isMuted: isMuted,
            illustAIType: illustAIType,
            series: series?.toDomain(),
            illustBookStyle: illustBookStyle,
            totalComments: totalComments,
            restrictionAttributes: restrictionAttributes,
            ownerId: ownerId ?? "guest"
        )
    }

    nonisolated static func fromDomain(_ illust: Illusts) -> IllustDTO {
        IllustDTO(
            id: illust.id,
            title: illust.title,
            type: illust.type,
            imageUrls: .fromDomain(illust.imageUrls),
            caption: illust.caption,
            restrict: illust.restrict,
            user: .fromDomain(illust.user),
            tags: illust.tags.map { .fromDomain($0) },
            tools: illust.tools,
            createDate: illust.createDate,
            pageCount: illust.pageCount,
            width: illust.width,
            height: illust.height,
            sanityLevel: illust.sanityLevel,
            xRestrict: illust.xRestrict,
            metaSinglePage: illust.metaSinglePage.map { .fromDomain($0) },
            metaPages: illust.metaPages.map { .fromDomain($0) },
            totalView: illust.totalView,
            totalBookmarks: illust.totalBookmarks,
            isBookmarked: illust.isBookmarked,
            bookmarkRestrict: illust.bookmarkRestrict,
            visible: illust.visible,
            isMuted: illust.isMuted,
            illustAIType: illust.illustAIType,
            series: illust.series.map { .fromDomain($0) },
            illustBookStyle: illust.illustBookStyle,
            totalComments: illust.totalComments,
            restrictionAttributes: illust.restrictionAttributes,
            ownerId: illust.ownerId
        )
    }
}
