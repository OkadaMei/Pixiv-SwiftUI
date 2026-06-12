import Foundation
import SwiftData

/// 多页面图片的页面元数据
@Model
final class MetaPages {
    var imageUrls: MetaPagesImageUrls?

    init(imageUrls: MetaPagesImageUrls? = nil) {
        self.imageUrls = imageUrls
    }
}
