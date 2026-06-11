import Foundation

/// 搜索相关API
@MainActor
final class SearchAPI {
    private let client = NetworkClient.shared

    init() {}

    private func requireAuthHeaders() throws -> [String: String] {
        guard let headers = SessionManager.shared.authHeaders else {
            throw NetworkError.invalidResponse
        }
        return headers
    }

    /// 获取搜索建议
    func getSearchAutoCompleteKeywords(word: String) async throws -> [SearchTag] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/search/autocomplete")
        components?.queryItems = [
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: word)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: SearchAutoCompleteResponse.self
        )

        return response.tags
    }

    /// 搜索插画
    func getSearchIllust(
        word: String,
        sort: String = "date_desc",
        searchTarget: String = "partial_match_for_tags",
        offset: Int = 0
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/illust")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: IllustsResponse.self
        )

        return response.illusts
    }

    /// 搜索用户
    func getSearchUser(word: String, offset: Int = 0) async throws -> [UserPreviews] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/user")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: UserPreviewsResponse.self
        )

        return response.userPreviews
    }

    /// 获取热门标签
    func getIllustTrendTags() async throws -> [TrendTag] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/trending-tags/illust")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android")
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: TrendingTagsResponse.self
        )

        return response.trendTags
    }

    /// 搜索插画（新版本）
    func searchIllusts(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        searchAIType: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        let response = try await searchIllustsPage(
            word: word,
            searchTarget: searchTarget,
            sort: sort,
            searchAIType: searchAIType,
            startDate: startDate,
            endDate: endDate,
            offset: offset,
            limit: limit
        )
        return response.illusts
    }

    func searchIllustsPage(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        searchAIType: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> IllustsResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/illust")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let searchAIType {
            queryItems.append(URLQueryItem(name: "search_ai_type", value: String(searchAIType)))
        }

        if let formattedStartDate = formatDate(startDate) {
            queryItems.append(URLQueryItem(name: "start_date", value: formattedStartDate))
        }

        if let formattedEndDate = formatDate(endDate) {
            queryItems.append(URLQueryItem(name: "end_date", value: formattedEndDate))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: IllustsResponse.self
        )
    }

    /// 搜索小说（新版本）
    func searchNovels(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        searchAIType: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Novel] {
        let response = try await searchNovelsPage(
            word: word,
            searchTarget: searchTarget,
            sort: sort,
            searchAIType: searchAIType,
            startDate: startDate,
            endDate: endDate,
            offset: offset,
            limit: limit
        )
        return response.novels
    }

    func searchNovelsPage(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        searchAIType: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/novel")
        var queryItems = [
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "include_translated_tag_results", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let searchAIType {
            queryItems.append(URLQueryItem(name: "search_ai_type", value: String(searchAIType)))
        }

        if let formattedStartDate = formatDate(startDate) {
            queryItems.append(URLQueryItem(name: "start_date", value: formattedStartDate))
        }

        if let formattedEndDate = formatDate(endDate) {
            queryItems.append(URLQueryItem(name: "end_date", value: formattedEndDate))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: NovelResponse.self
        )
    }

    private func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
