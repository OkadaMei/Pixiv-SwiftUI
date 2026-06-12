import Foundation
import SwiftData

/// 多页面图片的页面元数据中的 URL 集合
@Model
final class MetaPagesImageUrls {
    var squareMedium: String
    var medium: String
    var large: String
    var original: String

    init(squareMedium: String, medium: String, large: String, original: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
        self.original = original
    }
}
