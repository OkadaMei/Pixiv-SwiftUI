import Foundation

/// 图片基础 URL 集合 DTO
nonisolated struct ImageUrlsDTO: Codable, Hashable {
    let squareMedium: String
    let medium: String
    let large: String

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
    }
}

// MARK: - Mapping

extension ImageUrlsDTO {
    nonisolated func toDomain() -> ImageUrls {
        ImageUrls(squareMedium: squareMedium, medium: medium, large: large)
    }

    nonisolated static func fromDomain(_ model: ImageUrls) -> ImageUrlsDTO {
        ImageUrlsDTO(squareMedium: model.squareMedium, medium: model.medium, large: model.large)
    }
}
