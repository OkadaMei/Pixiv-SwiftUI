import Foundation
import SwiftData

/// 单个图片页面的元数据（主要用于获取原始图片 URL）
@Model
final class MetaSinglePage {
    var originalImageUrl: String?

    init(originalImageUrl: String? = nil) {
        self.originalImageUrl = originalImageUrl
    }
}
