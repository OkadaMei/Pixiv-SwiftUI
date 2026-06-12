import Foundation
import SwiftData

/// 图片基础 URL 集合
@Model
final class ImageUrls {
    var squareMedium: String
    var medium: String
    var large: String

    init(squareMedium: String, medium: String, large: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
    }
}
