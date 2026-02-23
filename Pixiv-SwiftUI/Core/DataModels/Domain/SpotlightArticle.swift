import Foundation

struct SpotlightArticle: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let pureTitle: String
    let thumbnail: String
    let articleUrl: String
    let publishDate: Date

    var displayTitle: String {
        if pureTitle.hasSuffix(" -") {
            return String(pureTitle.dropLast(2))
        }
        return pureTitle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pureTitle = "pure_title"
        case thumbnail
        case articleUrl = "article_url"
        case publishDate = "publish_date"
    }
}

struct SpotlightResponse: Codable {
    let spotlightArticles: [SpotlightArticle]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case spotlightArticles = "spotlight_articles"
        case nextUrl = "next_url"
    }
}

struct SpotlightWork: Identifiable, Hashable {
    let id: Int
    let title: String
    let user: String
    let userImage: String
    let userLink: String
    let showImage: String
    let artworkLink: String

    init?(title: String?, user: String?, userImage: String?, userLink: String?, showImage: String?, artworkLink: String?) {
        guard let title = title, !title.isEmpty,
              let user = user, !user.isEmpty,
              let userImage = userImage, !userImage.isEmpty,
              let userLink = userLink, !userLink.isEmpty,
              let showImage = showImage, !showImage.isEmpty,
              let artworkLink = artworkLink, !artworkLink.isEmpty else {
            return nil
        }

        self.title = title
        if user.lowercased().hasPrefix("by ") {
            self.user = String(user.dropFirst(3))
        } else if user.lowercased().hasPrefix("by") {
            self.user = String(user.dropFirst(2))
        } else {
            self.user = user
        }
        self.userImage = userImage
        self.userLink = userLink
        self.showImage = showImage
        self.artworkLink = artworkLink

        if let url = URL(string: artworkLink) {
            self.id = Int(url.pathComponents.last ?? "0") ?? 0
        } else {
            self.id = 0
        }
    }
}

struct SpotlightArticleDetail {
    let description: String
    let works: [SpotlightWork]
    let rankingArticles: [SpotlightRelatedArticle]
    let recommendedArticles: [SpotlightRelatedArticle]
}

struct SpotlightRelatedArticle: Identifiable, Hashable {
    let id: Int
    let title: String
    let thumbnail: String
    let articleUrl: String
    let category: String
}
