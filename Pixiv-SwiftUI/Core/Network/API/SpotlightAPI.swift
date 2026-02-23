import Foundation
import SwiftSoup

final class SpotlightAPI {
    private let client = NetworkClient.shared

    func getSpotlightArticles(category: String = "all") async throws -> (articles: [SpotlightArticle], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/spotlight/articles")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "category", value: category)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: [:],
            responseType: SpotlightResponse.self
        )

        return (response.spotlightArticles, response.nextUrl)
    }

    func getSpotlightArticlesByURL(_ urlString: String) async throws -> (articles: [SpotlightArticle], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: [:],
            responseType: SpotlightResponse.self
        )

        return (response.spotlightArticles, response.nextUrl)
    }

    func fetchArticleDetail(url: String, languageCode: Int = 0) async throws -> SpotlightArticleDetail {
        let html = try await fetchHTML(url: url)
        return try parseArticleHTML(html, languageCode: languageCode)
    }

    private func fetchHTML(url: String) async throws -> String {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidResponse
        }

        let headers: [String: String] = [
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.26 Safari/537.36",
            "Referer": "https://www.pixivision.net/zh/"
        ]

        return try await client.getRaw(url: requestURL, headers: headers)
    }

    private func parseArticleHTML(_ html: String, languageCode: Int) throws -> SpotlightArticleDetail {
        let doc = try SwiftSoup.parse(html)

        guard let article = try doc.getElementsByTag("article").first(),
              let amBody = try article.getElementsByClass("am__body").first() else {
            return SpotlightArticleDetail(description: "", works: [], rankingArticles: [], recommendedArticles: [])
        }

        var nodes = try amBody.children()
        var description = ""

        if let firstClass = try nodes.first()?.attr("class"), firstClass.contains("_feature") {
            if let featureContainer = nodes.first() {
                description = try extractFeatureDescription(from: featureContainer)
            }
            nodes = try nodes.first()?.children() ?? nodes
        } else {
            if let header = try article.getElementsByClass("am__header").first() {
                description = try extractDescription(from: header)
            }
        }

        var works: [SpotlightWork] = []

        for node in nodes {
            do {
                guard let nodeClass = try node.attr("class").nilIfEmpty,
                      nodeClass.contains("illust") else {
                    continue
                }

                var artworkLink: String?
                var showImage: String?
                var title: String?
                var userLink: String?
                var user: String?
                var userImage: String?

                let links = try node.getElementsByTag("a")
                for link in links {
                    guard let href = try link.attr("href").nilIfEmpty else { continue }

                    if href.contains("/artworks/") {
                        artworkLink = href
                        let imgs = try node.getElementsByTag("img")
                        if imgs.count > 1 {
                            showImage = try imgs[1].attr("src")
                        }
                        if let titleElement = try node.getElementsByTag("h3").first() {
                            title = try titleElement.text()
                        }
                    } else if href.contains("/users/") {
                        userLink = href
                        if let userElement = try node.getElementsByTag("p").first() {
                            user = try userElement.text()
                        }
                        let imgs = try node.getElementsByTag("img")
                        if !imgs.isEmpty {
                            userImage = try imgs[0].attr("src")
                        }
                    }
                }

                if let work = SpotlightWork(
                    title: title,
                    user: user,
                    userImage: userImage,
                    userLink: userLink,
                    showImage: showImage,
                    artworkLink: artworkLink
                ) {
                    works.append(work)
                }
            } catch {
                continue
            }
        }

        let rankingArticles = try extractRelatedArticles(doc: doc, category: "Ranking Area")
        let recommendedArticles = try extractRelatedArticles(doc: doc, category: "Osusume Area")

        return SpotlightArticleDetail(
            description: description,
            works: works,
            rankingArticles: rankingArticles,
            recommendedArticles: recommendedArticles
        )
    }

    private func extractRelatedArticles(doc: Document, category: String) throws -> [SpotlightRelatedArticle] {
        guard let sidebar = try doc.getElementsByClass("sidebar-container").first() else {
            return []
        }

        guard let section = try sidebar.getElementsByAttributeValue("data-gtm-category", category).first() else {
            return []
        }

        var articles: [SpotlightRelatedArticle] = []
        let listItems = try section.getElementsByClass("alc__articles-list-item")

        for item in listItems {
            guard let link = try item.getElementsByClass("asc__thumbnail-container").first()?.getElementsByTag("a").first(),
                  let href = try link.attr("href").nilIfEmpty else {
                continue
            }

            let thumbnail: String
            if let thumbDiv = try item.getElementsByClass("_thumbnail").first(),
               let style = try thumbDiv.attr("style").nilIfEmpty {
                let pattern = #"background-image:\s*url\(['"]?([^'")\s]+)['"]?\)"#
                if let range = style.range(of: pattern, options: .regularExpression) {
                    let urlMatch = style[range]
                    let start = urlMatch.firstIndex(of: "(") ?? urlMatch.startIndex
                    let end = urlMatch.lastIndex(of: ")") ?? urlMatch.endIndex
                    let urlString = String(urlMatch[urlMatch.index(after: start)..<end])
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                    thumbnail = urlString
                } else {
                    continue
                }
            } else {
                continue
            }

            let title: String
            if let titleElement = try item.getElementsByClass("asc__title").first() {
                title = try titleElement.text()
            } else {
                continue
            }

            let categoryLabel: String
            if let categoryElement = try item.getElementsByClass("_category-label").first() {
                categoryLabel = try categoryElement.text()
            } else {
                categoryLabel = ""
            }

            let articleId: Int
            if let lastComponent = href.split(separator: "/").last,
               let id = Int(lastComponent) {
                articleId = id
            } else {
                articleId = 0
            }

            let baseUrl = "https://www.pixivision.net"
            let articleUrl = href.hasPrefix("http") ? href : baseUrl + href

            let relatedArticle = SpotlightRelatedArticle(
                id: articleId,
                title: title,
                thumbnail: thumbnail,
                articleUrl: articleUrl,
                category: categoryLabel
            )
            articles.append(relatedArticle)
        }

        return articles
    }

    private func extractFeatureDescription(from container: Element) throws -> String {
        let paragraphElements = try container.getElementsByClass("_feature-article-body__paragraph")
        for element in paragraphElements {
            let paragraphs = try element.getElementsByTag("p")
            let texts = paragraphs.compactMap { try? $0.text() }.filter { !$0.isEmpty }
            if !texts.isEmpty {
                return texts.joined(separator: "\n\n")
            }
        }
        return ""
    }

    private func extractDescription(from header: Element) throws -> String {
        let paragraphs = try header.getElementsByTag("p")
        return paragraphs.compactMap { try? $0.text() }.joined(separator: "\n\n")
    }
}

extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}
