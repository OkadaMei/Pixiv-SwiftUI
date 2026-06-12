import Foundation

/// 插画排行榜响应 DTO — 使用 IllustDTO 而非直接解码 @Model
nonisolated struct IllustRankingResponseDTO: Codable {
    let illusts: [IllustDTO]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case illusts
        case nextUrl = "next_url"
    }
}
