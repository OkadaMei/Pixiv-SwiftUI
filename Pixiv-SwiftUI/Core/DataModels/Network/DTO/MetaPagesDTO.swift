import Foundation

/// 多页面图片的页面元数据中的 URL 集合 DTO
nonisolated struct MetaPagesImageUrlsDTO: Codable {
    let squareMedium: String
    let medium: String
    let large: String
    let original: String

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
        case original
    }
}

// MARK: - Mapping

extension MetaPagesImageUrlsDTO {
    nonisolated func toDomain() -> MetaPagesImageUrls {
        MetaPagesImageUrls(squareMedium: squareMedium, medium: medium, large: large, original: original)
    }

    nonisolated static func fromDomain(_ model: MetaPagesImageUrls) -> MetaPagesImageUrlsDTO {
        MetaPagesImageUrlsDTO(
            squareMedium: model.squareMedium,
            medium: model.medium,
            large: model.large,
            original: model.original
        )
    }
}

/// 多页面图片的页面元数据 DTO
nonisolated struct MetaPagesDTO: Codable {
    let imageUrls: MetaPagesImageUrlsDTO?

    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
    }
}

// MARK: - Mapping

extension MetaPagesDTO {
    nonisolated func toDomain() -> MetaPages {
        MetaPages(imageUrls: imageUrls?.toDomain())
    }

    nonisolated static func fromDomain(_ model: MetaPages) -> MetaPagesDTO {
        MetaPagesDTO(imageUrls: model.imageUrls.map { .fromDomain($0) })
    }
}

/// 单个图片页面的元数据 DTO（主要用于获取原始图片 URL）
nonisolated struct MetaSinglePageDTO: Codable {
    let originalImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case originalImageUrl = "original_image_url"
    }
}

// MARK: - Mapping

extension MetaSinglePageDTO {
    nonisolated func toDomain() -> MetaSinglePage {
        MetaSinglePage(originalImageUrl: originalImageUrl)
    }

    nonisolated static func fromDomain(_ model: MetaSinglePage) -> MetaSinglePageDTO {
        MetaSinglePageDTO(originalImageUrl: model.originalImageUrl)
    }
}
