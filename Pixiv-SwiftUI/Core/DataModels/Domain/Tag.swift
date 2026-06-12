import Foundation
import SwiftData

/// 标签信息
@Model
final class Tag {
    var name: String
    var translatedName: String?

    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }
}
