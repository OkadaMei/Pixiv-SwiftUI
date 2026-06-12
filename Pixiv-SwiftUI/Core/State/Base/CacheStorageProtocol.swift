import Foundation

/// 统一缓存存储协议
///
/// 所有 Store 通过此协议访问缓存，而非直接依赖 `CacheManager.shared`。
/// 定义核心的 get/set/isValid/remove/clearAll 操作，
/// 不含静态 Key 工厂方法（那些属于 CacheManager 的实现细节）。
protocol CacheStorageProtocol: AnyObject {
    /// 缓存数据
    func set<T>(_ data: T, forKey key: String, expiration: CacheExpiration)

    /// 获取缓存数据（惰性过期检查）
    func get<T>(forKey key: String) -> T?

    /// 检查缓存是否有效（未过期且存在）
    func isValid(forKey key: String) -> Bool

    /// 获取缓存时间戳
    func timestamp(forKey key: String) -> Date?

    /// 清除指定缓存
    func remove(forKey key: String)

    /// 清除所有缓存
    func clearAll()
}
