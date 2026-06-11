import Foundation

/// 小说相关 API
@MainActor
final class NovelAPI {
    private let client = NetworkClient.shared

    init() {}

    private func requireAuthHeaders() throws -> [String: String] {
        guard let headers = SessionManager.shared.authHeaders else {
            throw NetworkError.invalidResponse
        }
        return headers
    }

    /// 获取推荐小说
    func getRecommendedNovels(offset: Int = 0) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/recommended")
        components?.queryItems = [
            URLQueryItem(name: "include_privacy_policy", value: "true"),
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "include_ranking_novels", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelResponse.self)
    }

    /// 获取关注用户的新作
    /// 注意：首次请求不要传递 offset 参数，否则会返回 400 错误
    func getFollowingNovels(restrict: String = "public", offset: Int? = nil) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/follow")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "restrict", value: restrict),
        ]
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelResponse.self)
    }

    /// 获取用户收藏的小说
    func getUserBookmarkNovels(userId: Int, restrict: String = "public", offset: Int = 0) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/user/bookmarks/novel")
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: String(userId)),
            URLQueryItem(name: "restrict", value: restrict),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelResponse.self)
    }

    /// 获取小说详情
    func getNovelDetail(novelId: Int) async throws -> Novel {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/novel/detail")
        components?.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let novel: Novel
        }

        let response = try await client.get(from: url, headers: try requireAuthHeaders(), responseType: Response.self)
        return response.novel
    }

    /// 通过 URL 获取小说列表（用于分页）
    func getNovelsByURL(_ urlString: String) async throws -> NovelResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelResponse.self)
    }

    /// 获取小说评论
    func getNovelComments(novelId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/comment")
        components?.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: CommentResponse.self)
    }

    /// 发送小说评论
    func postNovelComment(novelId: Int, comment: String, parentCommentId: Int? = nil) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/comment/add") else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["novel_id"] = String(novelId)
        body["comment"] = comment

        if let parentCommentId {
            body["parent_comment_id"] = String(parentCommentId)
        }

        var formComponents = URLComponents()
        formComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: try requireAuthHeaders(),
            responseType: EmptyResponse.self
        )
    }

    /// 删除小说评论
    func deleteNovelComment(commentId: Int) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/comment/delete") else {
            throw NetworkError.invalidResponse
        }

        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "comment_id", value: String(commentId))]
        let formData = components.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: try requireAuthHeaders(),
            responseType: EmptyResponse.self
        )
    }

    /// 获取小说正文内容
    func getNovelContent(novelId: Int) async throws -> NovelReaderContent {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/text/\(novelId)") else {
            throw NetworkError.invalidResponse
        }

        let response: String = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: String.self
        )

        let novelJsonString = response
            .replacingOccurrences(of: "\\\n", with: "\\\\n")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        guard let novelJsonData = novelJsonString.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(NovelReaderContent.self, from: novelJsonData)
    }

    /// 获取小说排行榜
    func getNovelRanking(mode: String, date: String? = nil, offset: Int = 0) async throws -> NovelRankingResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/ranking")
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: "30"),
        ]

        if let date = date {
            components?.queryItems?.append(URLQueryItem(name: "date", value: date))
        }

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: NovelResponse.self
        )

        return NovelRankingResponse(
            novels: response.novels,
            nextUrl: response.nextUrl
        )
    }

    /// 通过 URL 获取排行榜小说列表（用于分页）
    func getNovelRankingByURL(_ urlString: String) async throws -> NovelResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelResponse.self)
    }

    /// 删除小说
    func deleteNovel(novelId: Int) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/delete") else {
            throw NetworkError.invalidResponse
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId))
        ]
        let formData = components.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: try requireAuthHeaders(),
            responseType: EmptyResponse.self
        )
    }

    /// 收藏小说
    func bookmarkNovel(novelId: Int, restrict: String = "public") async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/bookmark/add") else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["novel_id"] = String(novelId)
        body["restrict"] = restrict

        var formComponents = URLComponents()
        formComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: try requireAuthHeaders(),
            responseType: EmptyResponse.self
        )
    }

    /// 取消收藏小说
    func unbookmarkNovel(novelId: Int) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/bookmark/delete") else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["novel_id"] = String(novelId)

        var formComponents = URLComponents()
        formComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: try requireAuthHeaders(),
            responseType: EmptyResponse.self
        )
    }

    /// 获取小说系列信息
    func getNovelSeries(seriesId: Int) async throws -> NovelSeriesResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/series")
        components?.queryItems = [
            URLQueryItem(name: "series_id", value: String(seriesId)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelSeriesResponse.self)
    }

    /// 通过 URL 获取系列内容（用于分页）
    func getNovelSeriesByURL(_ urlString: String) async throws -> NovelSeriesResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: try requireAuthHeaders(), responseType: NovelSeriesResponse.self)
    }
}
