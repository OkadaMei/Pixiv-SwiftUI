import Foundation

/// 应用设置协议
///
/// 提供用户偏好设置的只读访问，供 Store 在业务逻辑中使用，
/// 替代直接访问 `UserSettingStore.shared.userSetting`。
protocol AppSettingsProtocol: AnyObject {
    /// 默认私密收藏
    var defaultPrivateLike: Bool { get }

    /// 是否启用收藏缓存（Bookmark Cache）
    var bookmarkCacheEnabled: Bool { get }

    /// 下载时是否保存元数据
    var saveMetadata: Bool { get }

    /// 最大并行下载任务数
    var maxRunningTask: Int { get }

    /// 首选翻译服务 ID
    var translatePrimaryServiceId: String { get }

    /// 翻译目标语言（原始值，可能为 "system"）
    var translateTargetLanguage: String { get }

    /// 是否自定义主题色
    var isCustomTheme: Bool { get }

    /// 自定义主题色 hex
    var customThemeColor: Int { get }

    /// 预设主题色种子
    var seedColor: Int { get }

    /// 主题模式: 0=跟随系统 1=浅色 2=深色
    var colorSchemeMode: Int { get }

    /// 将原始语言设置解析为实际语言代码
    func resolveTargetLanguage(_ raw: String) -> String
}
