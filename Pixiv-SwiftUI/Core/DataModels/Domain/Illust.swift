import Foundation
import SwiftData

/// 插画信息
@Model
final class Illusts {
    @Attribute(.unique) var id: Int
    var ownerId: String = "guest"
    var title: String
    var type: String
    var imageUrls: ImageUrls
    var caption: String
    var restrict: Int
    var user: User
    var tags: [Tag]
    var tools: [String]
    var createDate: String
    var pageCount: Int
    var width: Int
    var height: Int
    var sanityLevel: Int
    var xRestrict: Int
    var metaSinglePage: MetaSinglePage?
    var metaPages: [MetaPages]
    var totalView: Int
    var totalBookmarks: Int
    var isBookmarked: Bool
    var bookmarkRestrict: String?
    var visible: Bool
    var isMuted: Bool
    var illustAIType: Int
    var series: IllustSeries?
    var illustBookStyle: Int?
    var totalComments: Int?
    var restrictionAttributes: [String]

    /// 获取安全的宽高比，防止出现 0 或非有限数值
    var safeAspectRatio: CGFloat {
        let widthValue = CGFloat(width)
        let heightValue = CGFloat(height)
        guard heightValue > 0 else { return 1.0 }
        let ratio = widthValue / heightValue
        return ratio.isFinite && ratio > 0 ? ratio : 1.0
    }

    /// 是否为剧透内容（集中定义，避免各卡片重复遍历 tags）
    var isSpoiler: Bool {
        let spoilerTags: Set<String> = ["ネタバレ", "spoiler", "ネタバレ注意"]
        return tags.contains { spoilerTags.contains($0.name.lowercased()) }
    }

    var isManga: Bool {
        type == "manga"
    }

    func mangaImageUrl(at index: Int) -> String? {
        guard isManga, index < metaPages.count else { return nil }
        let imageUrl = metaPages[index].imageUrls
        return imageUrl?.original ?? imageUrl?.large ?? imageUrl?.medium
    }

    var allMangaImageUrls: [String] {
        guard isManga else { return [] }
        return metaPages.compactMap { $0.imageUrls?.original ?? $0.imageUrls?.large ?? $0.imageUrls?.medium }
    }

    /// 获取作品的图片URL列表 (用于缓存预取)
    func getImageURLs(quality: BookmarkCacheQuality, allPages: Bool) -> [String] {
        var urls: [String] = []

        if pageCount == 1 || !allPages {
            if let url = getSingleImageURL(quality: quality) {
                urls.append(url)
            }
        } else {
            for metaPage in metaPages {
                if let imageUrls = metaPage.imageUrls {
                    let url: String
                    switch quality {
                    case .original:
                        url = imageUrls.original
                    case .large:
                        url = imageUrls.large
                    case .medium:
                        url = imageUrls.medium
                    }
                    urls.append(url)
                }
            }
        }

        return urls
    }

    /// 获取单页图片URL
    func getSingleImageURL(quality: BookmarkCacheQuality) -> String? {
        switch quality {
        case .original:
            return metaSinglePage?.originalImageUrl ?? imageUrls.large
        case .large:
            return imageUrls.large
        case .medium:
            return imageUrls.medium
        }
    }

    init(id: Int, title: String, type: String, imageUrls: ImageUrls, caption: String, restrict: Int, user: User, tags: [Tag], tools: [String], createDate: String, pageCount: Int, width: Int, height: Int, sanityLevel: Int, xRestrict: Int, metaSinglePage: MetaSinglePage?, metaPages: [MetaPages], totalView: Int, totalBookmarks: Int, isBookmarked: Bool, bookmarkRestrict: String?, visible: Bool, isMuted: Bool, illustAIType: Int, series: IllustSeries? = nil, illustBookStyle: Int? = nil, totalComments: Int? = nil, restrictionAttributes: [String] = [], ownerId: String = "guest") {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.type = type
        self.imageUrls = imageUrls
        self.caption = caption
        self.restrict = restrict
        self.user = user
        self.tags = tags
        self.tools = tools
        self.createDate = createDate
        self.pageCount = pageCount
        self.width = width
        self.height = height
        self.sanityLevel = sanityLevel
        self.xRestrict = xRestrict
        self.metaSinglePage = metaSinglePage
        self.metaPages = metaPages
        self.totalView = totalView
        self.totalBookmarks = totalBookmarks
        self.isBookmarked = isBookmarked
        self.bookmarkRestrict = bookmarkRestrict
        self.visible = visible
        self.isMuted = isMuted
        self.illustAIType = illustAIType
        self.series = series
        self.illustBookStyle = illustBookStyle
        self.totalComments = totalComments
        self.restrictionAttributes = restrictionAttributes
    }
}
