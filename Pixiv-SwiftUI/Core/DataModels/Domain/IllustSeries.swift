import Foundation
import SwiftData

/// 插画系列信息
@Model
final class IllustSeries {
    var id: Int
    var title: String?

    init(id: Int, title: String? = nil) {
        self.id = id
        self.title = title
    }
}
