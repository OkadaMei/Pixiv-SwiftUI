import Foundation

/// 插画相关API
@MainActor
final class IllustAPI {
    private let client = NetworkClient.shared

    init() {}

    private func requireAuthHeaders() throws -> [String: String] {
        guard let headers = SessionManager.shared.authHeaders else {
            throw NetworkError.invalidResponse
        }
        return headers
    }

    /// 获取推荐插画
    func getRecommendedIllusts(
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.recommendIllusts)
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "include_ranking_label", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [IllustDTO]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self,
            isLongContent: true
        )

        return (response.illusts.map { $0.toDomain() }, response.nextUrl)
    }

    /// 获取排行榜插画
    func getIllustRanking(
        mode: String = "day",
        date: String? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/illust/ranking")
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let date = date {
            components?.queryItems?.append(URLQueryItem(name: "date", value: date))
        }

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [IllustDTO]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self
        )

        return (response.illusts.map { $0.toDomain() }, response.nextUrl)
    }

    /// 获取系列插画列表
    func getIllustSeries(
        seriesId: Int,
        filter: String = "for_ios",
        offset: Int = 0
    ) async throws -> IllustSeriesResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/illust/series")
        components?.queryItems = [
            URLQueryItem(name: "illust_series_id", value: String(seriesId)),
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: IllustSeriesResponse.self
        )
    }

    func getIllustSeriesByURL(_ urlString: String) async throws -> IllustSeriesResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: IllustSeriesResponse.self
        )
    }

    /// 获取插画详情
    func getIllustDetail(illustId: Int) async throws -> Illusts {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.illustDetail)
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illust: IllustDTO
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self
        )

        return response.illust.toDomain()
    }

    /// 获取相关插画
    func getRelatedIllusts(
        illustId: Int,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/illust/related")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId)),
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [IllustDTO]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self
        )

        return (response.illusts.map { $0.toDomain() }, response.nextUrl)
    }

    /// 通过 URL 获取插画列表（用于分页）
    func getIllustsByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [IllustDTO]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self
        )

        return (response.illusts.map { $0.toDomain() }, response.nextUrl)
    }

    /// 获取插画评论
    func getIllustComments(illustId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v3/illust/comments")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: CommentResponse.self
        )
    }

    /// 获取评论的回复列表
    func getIllustCommentsReplies(commentId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/illust/comment/replies")
        components?.queryItems = [
            URLQueryItem(name: "comment_id", value: String(commentId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: CommentResponse.self
        )
    }

    /// 发送插画评论
    func postIllustComment(illustId: Int, comment: String, parentCommentId: Int? = nil) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/illust/comment/add") else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["illust_id"] = String(illustId)
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

        var headers = try requireAuthHeaders()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    /// 删除插画评论
    func deleteIllustComment(commentId: Int) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/illust/comment/delete") else {
            throw NetworkError.invalidResponse
        }

        var formComponents = URLComponents()
        formComponents.queryItems = [URLQueryItem(name: "comment_id", value: String(commentId))]
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        var headers = try requireAuthHeaders()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    /// 获取动图元数据
    func getUgoiraMetadata(illustId: Int) async throws -> UgoiraMetadataResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/ugoira/metadata")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: UgoiraMetadataResponse.self
        )
    }

    /// 通过 URL 获取排行榜插画列表（用于分页）
    func getIllustRankingByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [IllustDTO]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: try requireAuthHeaders(),
            responseType: Response.self
        )

        return (response.illusts.map { $0.toDomain() }, response.nextUrl)
    }

    /// 删除插画或漫画
    func deleteIllust(illustId: Int, type: String = "illust") async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/illust/delete") else {
            throw NetworkError.invalidResponse
        }

        var bodyItems: [URLQueryItem] = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        if type == "manga" {
            bodyItems.append(URLQueryItem(name: "type", value: "manga"))
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = bodyItems

        guard let body = components?.query?.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        var headers = try requireAuthHeaders()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: body,
            headers: headers,
            responseType: EmptyResponse.self
        )
    }
}

/// 空响应（用于不需要返回内容的请求）
private struct EmptyResponse: Decodable {}
