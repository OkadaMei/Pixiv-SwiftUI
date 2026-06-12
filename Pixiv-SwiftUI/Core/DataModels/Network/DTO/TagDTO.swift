import Foundation

/// 标签信息 DTO
nonisolated struct TagDTO: Codable {
    let name: String
    let translatedName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
}

// MARK: - Mapping

extension TagDTO {
    nonisolated func toDomain() -> Tag {
        Tag(name: name, translatedName: translatedName)
    }

    nonisolated static func fromDomain(_ model: Tag) -> TagDTO {
        TagDTO(name: model.name, translatedName: model.translatedName)
    }
}
