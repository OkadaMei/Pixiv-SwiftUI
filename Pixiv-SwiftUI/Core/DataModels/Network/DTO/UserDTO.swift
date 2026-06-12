import Foundation

/// 用户头像 URL 集合 DTO
nonisolated struct ProfileImageUrlsDTO: Codable, Hashable {
    let px16x16: String?
    let px50x50: String?
    let px170x170: String?
    let medium: String?

    init(px16x16: String? = nil, px50x50: String? = nil, px170x170: String? = nil, medium: String? = nil) {
        self.px16x16 = px16x16
        self.px50x50 = px50x50
        self.px170x170 = px170x170
        self.medium = medium
    }

    enum CodingKeys: String, CodingKey {
        case px16x16 = "px_16x16"
        case px50x50 = "px_50x50"
        case px170x170 = "px_170x170"
        case medium
    }
}

// MARK: - Mapping

extension ProfileImageUrlsDTO {
    nonisolated func toDomain() -> ProfileImageUrls {
        ProfileImageUrls(
            px16x16: px16x16,
            px50x50: px50x50,
            px170x170: px170x170,
            medium: medium
        )
    }

    nonisolated static func fromDomain(_ model: ProfileImageUrls) -> ProfileImageUrlsDTO {
        ProfileImageUrlsDTO(
            px16x16: model.px16x16,
            px50x50: model.px50x50,
            px170x170: model.px170x170,
            medium: model.medium
        )
    }
}

/// 用户信息 DTO
/// 用户信息 DTO
nonisolated struct UserDTO: Codable, Hashable {
    let profileImageUrls: ProfileImageUrlsDTO?
    let id: StringIntValue
    let name: String
    let account: String
    let mailAddress: String?
    let isPremium: Bool?
    let xRestrict: Int?
    let isMailAuthorized: Bool?
    let requirePolicyAgreement: Bool?
    let isAcceptRequest: Bool?
    let isFollowed: Bool?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.stringValue)
    }

    static func == (lhs: UserDTO, rhs: UserDTO) -> Bool {
        lhs.id.stringValue == rhs.id.stringValue
    }

    enum CodingKeys: String, CodingKey {
        case profileImageUrls = "profile_image_urls"
        case id
        case name
        case account
        case mailAddress = "mail_address"
        case isPremium = "is_premium"
        case xRestrict = "x_restrict"
        case isMailAuthorized = "is_mail_authorized"
        case requirePolicyAgreement = "require_policy_agreement"
        case isAcceptRequest = "is_accept_request"
        case isFollowed = "is_followed"
    }
}

// MARK: - Mapping

extension UserDTO {
    nonisolated func toDomain() -> User {
        User(
            profileImageUrls: profileImageUrls?.toDomain(),
            id: id,
            name: name,
            account: account,
            mailAddress: mailAddress,
            isPremium: isPremium,
            xRestrict: xRestrict,
            isMailAuthorized: isMailAuthorized,
            requirePolicyAgreement: requirePolicyAgreement,
            isAcceptRequest: isAcceptRequest,
            isFollowed: isFollowed
        )
    }

    nonisolated static func fromDomain(_ model: User) -> UserDTO {
        UserDTO(
            profileImageUrls: model.profileImageUrls.map { .fromDomain($0) },
            id: model.id,
            name: model.name,
            account: model.account,
            mailAddress: model.mailAddress,
            isPremium: model.isPremium,
            xRestrict: model.xRestrict,
            isMailAuthorized: model.isMailAuthorized,
            requirePolicyAgreement: model.requirePolicyAgreement,
            isAcceptRequest: model.isAcceptRequest,
            isFollowed: model.isFollowed
        )
    }
}
