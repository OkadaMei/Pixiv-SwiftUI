import Foundation

/// 插画系列信息 DTO
nonisolated struct IllustSeriesDTO: Codable {
    let id: Int
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}

// MARK: - Mapping

extension IllustSeriesDTO {
    nonisolated func toDomain() -> IllustSeries {
        IllustSeries(id: id, title: title)
    }

    nonisolated static func fromDomain(_ model: IllustSeries) -> IllustSeriesDTO {
        IllustSeriesDTO(id: model.id, title: model.title)
    }
}
