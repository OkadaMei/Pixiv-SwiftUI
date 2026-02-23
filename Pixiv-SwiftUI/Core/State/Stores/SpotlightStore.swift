import Foundation
import Observation

@MainActor
@Observable
final class SpotlightStore {
    static let shared = SpotlightStore()

    private let api = SpotlightAPI()
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .hours(23)

    var articles: [SpotlightArticle] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var error: AppError?
    var nextUrl: String?

    private var isLocked: Bool = false

    private var cacheKey: String { "spotlight_articles" }

    func fetch(forceRefresh: Bool = false) async {
        if isLocked { return }
        isLocked = true
        defer { isLocked = false }

        if !forceRefresh {
            if let cached: [SpotlightArticle] = cache.get(forKey: cacheKey) {
                articles = cached
                return
            }
        }

        isLoading = true
        error = nil

        do {
            let result = try await api.getSpotlightArticles()
            articles = result.articles
            nextUrl = result.nextUrl
            cache.set(articles, forKey: cacheKey, expiration: expiration)
        } catch {
            self.error = AppError.networkError(error.localizedDescription)
        }

        isLoading = false
    }

    func loadMore() async {
        if isLocked { return }
        guard let url = nextUrl, !isLoadingMore else { return }

        isLocked = true
        defer { isLocked = false }

        isLoadingMore = true

        do {
            let result = try await api.getSpotlightArticlesByURL(url)
            let newArticles = result.articles.filter { new in
                !articles.contains(where: { $0.id == new.id })
            }
            articles.append(contentsOf: newArticles)
            nextUrl = result.nextUrl
        } catch {
            self.error = AppError.networkError(error.localizedDescription)
        }

        isLoadingMore = false
    }

    func clear() {
        articles = []
        nextUrl = nil
        error = nil
    }
}

@MainActor
@Observable
final class SpotlightDetailStore {
    private let api = SpotlightAPI()

    var detail: SpotlightArticleDetail?
    var isLoading: Bool = false
    var error: AppError?

    func fetch(url: String, languageCode: Int = 0) async {
        isLoading = true
        error = nil

        do {
            detail = try await api.fetchArticleDetail(url: url, languageCode: languageCode)
        } catch {
            self.error = AppError.networkError(error.localizedDescription)
        }

        isLoading = false
    }

    func clear() {
        detail = nil
        error = nil
    }
}
