# 架构审查 — 已确认问题

> 生成日期：2026-06-17

---

## A. 数据正确性（SwiftData 相关问题）

### A1. `TranslationCacheStore` — ModelContext 跨线程访问

**文件：** `Core/State/Stores/TranslationCacheStore.swift`
**严重程度：** 高

`ModelContext` 不是线程安全的。该 Store 在 `@MainActor` 的 `init` 中创建了 `backgroundContext`，但所有读写操作通过 `backgroundQueue.async { }` 分发到 DispatchQueue 线程执行：

```swift
private init() {
    self.backgroundContext = container.createBackgroundContext()  // @MainActor 上创建
}

func get(...) async -> String? {
    return await withCheckedContinuation { continuation in
        backgroundQueue.async { [weak self] in
            // 在 DispatchQueue 线程上访问/修改 ModelContext
            try self.backgroundContext.fetch(descriptor).first
            cache.lastAccessedAt = Date()
            try self.backgroundContext.save()
        }
    }
}
```

可能后果：EXC_BAD_ACCESS 崩溃、静默数据损坏、SwiftData 内部事务状态不一致。

**修复方向：** 改用 `@ModelActor`，或将 `ModelContext` 的创建移到 `backgroundQueue` 内部。

---

### A2. SwiftData 模型层 — 无版本迁移

**文件：** `Core/DataModels/Persistence/Persistence.swift`
**严重程度：** 高

`ModelConfiguration` 创建时没有关联任何 `VersionedSchema` 或 `SchemaMigrationPlan`。如果未来发生以下变更，`ModelContainer` 初始化会直接崩溃：

- 重命名属性
- 变更属性类型
- 添加/修改 `.unique` 约束
- 删除属性

当前代码在容器初始化失败时静默回退到空内存 Schema，导致：

- 所有已持久化的数据不可见
- 新写入仅存内存，app 重启后丢失
- 无日志提示用户数据已被清除

---

### A3. `AccountPersist.accessToken` / `refreshToken` — Codable 包含 Token

**文件：** `Core/DataModels/Domain/User.swift` (lines 96-174)
**严重程度：** 中

`accessToken` 和 `refreshToken` 虽然标记为 `@Transient`（SwiftData 不持久化），但仍在 `CodingKeys` 中且在 `encode(to:)` 中被序列化：

```swift
enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    // ...
}

func encode(to encoder: Encoder) throws {
    try container.encode(accessToken, forKey: .accessToken)
    try container.encode(refreshToken, forKey: .refreshToken)
}
```

`@Transient` 不影响 Codable。任何调用 `JSONEncoder().encode(accountPersist)` 的代码路径都会输出明文 token。当前虽然不存在这样的调用路径，但这是一个潜在泄露点。

**修复方向：** 从 `CodingKeys` 中移除这两个 case，或移除 Codable 实现（SwiftData 已提供持久化）。

---

### A4. `AccountPersist.passWord` — 未使用的废弃字段占用存储

**文件：** `Core/DataModels/Domain/User.swift` (lines 85, 103, 123, 144, 165)
**严重程度：** 低

`passWord: String` 字段：

- 存在于 SwiftData schema 中（未标记 `@Transient`），在 SQLite 中占用一列
- 存在于 `CodingKeys` 中（key: "password"），参与 Codable 编解码
- **没有代码将其设置为非空值**——便利构造器始终传入 `passWord: ""`（line 190）

这不是密码泄露（没有真实密码被写入），但属于废弃字段带来的：

- 不必要的磁盘空间占用
- Codable 序列化/反序列化开销
- 代码理解困惑

**建议：** 删除该字段及相关的 CodingKeys case。

---

### A5. `BookmarkCacheStore.performFullSync` — 同步过程中的不一致风险

**文件：** `Core/State/Stores/BookmarkCacheStore.swift`
**严重程度：** 中

三个问题：

1. **Stale `cachedIds`（lines 343-344）：** `cachedIds` 在 API 分页请求所有页面之后才被捕获。但 `@MainActor` 方法在网络调用处会让出（suspension points），期间用户可能通过 UI 增删书签。`deletedIds` 基于过期的 `cachedIds` 计算，可能误删活跃书签。

2. **无事务边界（lines 351-353）：** 每张插图单独调用 `addOrUpdateCache` + 单独 `context.save()`。App 被杀死在中间状态时，部分书签已保存、部分未保存。

3. **单条查询循环：** `addOrUpdateCache` 和 `markAsDeleted` 内部对每张插图执行独立的 `FetchDescriptor` + `context.fetch`。1000+ 书签 = 1000+ SQL 查询。

---

### A6. `BookmarkCacheService.removeImageCache(for:)` — 磁盘缓存清理为空操作

**文件：** `Core/Services/BookmarkCacheService.swift` (lines 178-180)
**严重程度：** 中

```swift
func removeImageCache(for illustIds: some Collection<Int>) async {
    // 只打日志，没有实际调用 cache.removeImage(...)
    Logger.cache.debug("清除 \(illustIds.count) 条插图缓存")
}
```

取消收藏或删除的作品，磁盘上的 Kingfisher 缓存永远不会清理。随时间增长，磁盘占用无限膨胀。

---

## B. 视图层 Bug

### B1. `FullscreenImageView` 页码指示器不更新

**文件：** `Shared/Components/Media/ImageViewer/FullscreenImageView.swift`
**严重程度：** 高（功能 Bug）

```swift
Text("\(currentPage + 1) / \(imageURLs.count)")
```

`currentPage` 只在 `onAppear` 时从 `initialPage` 设置一次（line 147），用户滑动翻页后**绝不更新**。始终显示 `1 / n`。

**修复方向：** 使用 `.scrollPosition(id:)`（iOS 17+）绑定当前页，或用 `GeometryReader` 检测 ScrollView 的滚动偏移。

---

### B2. `IllustDetailView` — 创建局部 Store 实例而非使用共享实例

**文件：** `Features/General/IllustDetailView.swift` (line 20)
**严重程度：** 中

```swift
@State private var illustStore = IllustStore()  // 创建新实例
```

`IllustStore` 是单例（`static let shared`）。当前代码创建了一个全新的空实例，不与应用的全局状态共享数据。该实例在视图释放时被销毁，任何存入其中的状态都会丢失。

**修复方向：** 改为 `@Environment(IllustStore.self) var illustStore` 或直接使用 `IllustStore.shared`。

---

### B3. `ProgressiveCachedAsyncImage` — URL 变更时 `loadBestAvailableImage` 被调用两次

**文件：** `Shared/Utils/ProgressiveCachedAsyncImage.swift`
**严重程度：** 低

当 `targetURL` 变更时：

1. `onChange(of: targetURL)` 触发 → 调用 `loadBestAvailableImage()`（第一次）
2. SwiftUI 重绘 → `else` 分支的 `placeholderView` 出现 → `.onAppear` 触发 → 再次调用 `loadBestAvailableImage()`（第二次）

虽然幂等（第二次调用查缓存后不会重复网络请求），但存在不必要的重复计算。

**修复方向：** 移除 `placeholderView` 上的 `.onAppear`，只保留 `onChange` 触发。

---

## C. 并发与线程安全

### C1. `PrefetchTracker` — 无保护的可变属性

**文件：** `Shared/Utils/PrefetchTracker.swift`
**严重程度：** 中

```swift
final class PrefetchTracker: @unchecked Sendable {
    var prefetchedUpToIndex: Int = 0   // 无锁、无 actor 保护
}
```

标记为 `@unchecked Sendable` 以通过编译，但没有任何同步机制。多线程环境下的读写操作是数据竞争。

---

### C2. `CacheManager` 被 `@MainActor` 过度约束

**文件：** `Shared/Utils/CacheManager.swift`
**严重程度：** 低

整个类标记为 `@MainActor`，但 `NSCache` 内部是线程安全的。这意味着任何后台线程的缓存访问都会被迫跳到主线程（如果调用方不在主线程上）。

---

### C3. `UgoiraView` — `CADisplayLink` 保留循环

**文件：** `Shared/Components/Media/Ugoira/UgoiraView.swift`
**严重程度：** 低

```swift
displayLink = CADisplayLink(target: DisplayLinkTarget { [self] timestamp in
    updateFrame(at: timestamp)
}, selector: ...)
```

`CADisplayLink` 强持有 `DisplayLinkTarget`，后者强持有闭包，闭包捕获了 `self`。`@State` 的存储容器是引用类型，形成保留循环。通常情况下 `onDisappear` → `stopPlayback()` → `invalidate()` 会断开循环，但如果 `onDisappear` 因 SwiftUI 生命周期异常未被调用，循环会导致泄漏。

**修复方向：** 在闭包中使用 `[weak self]`。

---

### C4. `UgoiraView` — 帧计时漂移

**文件：** `Shared/Components/Media/Ugoira/UgoiraView.swift`
**严重程度：** 低

```swift
accumulatedTime = 0  // 重置而非保留余量
```

每次帧切换时丢弃了亚帧时间余量。对于每帧 50ms 的动画，如果实际经过 55ms，多出的 5ms 被丢弃而非累积到下一帧。长时间播放后会有明显漂移。

**修复方向：** 改为 `accumulatedTime -= frameDelays[currentFrameIndex]`。

---

## D. 代码质量与维护性

### D1. `MainSplitView` 和 `IllustDetailView` — 巨型视图

**文件：** `Features/Home/MainSplitView.swift`, `Features/General/IllustDetailView.swift`
**严重程度：** 中

- `MainSplitView`：~380 行，10 个 `@State`
- `IllustDetailView`：~790 行，**21 个 `@State`**

`IllustDetailView` 同时负责：布局（macOS 分栏/iOS 单列）、全屏过渡动画（完整状态机）、评论面板、用户/作品/小说导航、收藏、屏蔽、保存、下载。违反单一职责原则，难以测试和维护。

**修复方向：** 拆分为 `IllustDetailToolbar`、`IllustDetailSplitLayout`、`FullscreenTransitionOverlay`、`NavigationCoordinator`。

---

### D2. Store 错误处理不一致

**文件：** 多个 `Core/State/Stores/*.swift`
**严重程度：** 中

| Store          | 设置 `self.error`  | 用户是否可见错误 |
| -------------- | :----------------: | :--------------: |
| `AccountStore` |   ✅ 大部分方法    |        ✅        |
| `IllustStore`  |      ❌ 从不       |     ❌ 静默      |
| `NovelStore`   | ❌ 没有 error 属性 |     ❌ 静默      |
| `SearchStore`  |   ❌ 使用 `try?`   |     ❌ 静默      |
| `UgoiraStore`  |   ✅ 状态机模式    |        ✅        |

大部分 Store 在网络/数据库错误时只打印 `Logger.error()`，用户无感知。

**建议：** 在所有 Store 中添加 `error: AppError?` 属性，在 catch 块中统一赋值。

---

### D3. `SearchStore` — 非 `final class`

**文件：** `Core/State/Stores/SearchStore.swift`
**严重程度：** 低

```swift
@MainActor
@Observable
class SearchStore {  // 非 final
```

其他所有 Store 均为 `final class`。应统一。

---

### D4. `NovelStore` / `UgoiraStore` — 未使用的 Combine 导入

**文件：** `Core/State/Stores/NovelStore.swift`, `Core/State/Stores/UgoiraStore.swift`
**严重程度：** 低

导入了 `import Combine` 但没有任何 `AnyCancellable`、`Publisher` 或 `Subject` 的使用。

---

### D5. 字符串字面量作为 Notification/UserDefaults Key

**文件：** `App/PixivApp.swift`
**严重程度：** 低

```swift
NotificationCenter.default.publisher(for: .init("ShowUpdateNotification"))
UserDefaults.standard.bool(forKey: "quit_after_window_closed")
```

两处均直接使用字符串字面量。没有定义为 `Notification.Name` 或 `static let` 常量，存在拼写错误风险。

---

### D6. 重复注入 Environment

**文件：** `App/PixivApp.swift` (lines 37-38)
**严重程度：** 低

```swift
.environment(BookmarkActionService.shared)
.environment(BookmarkActionService.shared)  // 重复
```

---

### D7. `SearchView` 搜索文本未 trim 空白

**文件：** `Features/Search/SearchView.swift` (line 128)
**严重程度：** 低

```swift
if !store.searchText.isEmpty {
```

纯空格字符串会通过检查，向 Pixiv API 发送无意义的搜索请求。

---

### D8. `KeychainHelper` — 缺少 `kSecAttrAccessible`

**文件：** `Core/Services/Sync/KeychainHelper.swift` (line 67)
**严重程度：** 低

```swift
private static func baseQuery(...) -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        // 未设置 kSecAttrAccessible
    ]
}
```

默认 `kSecAttrAccessibleWhenUnlocked`。建议改为 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 以防止 iCloud 备份。

---

### D9. `AccountStore.loadAccountsAsync` / `UserSettingStore.loadUserSettingAsync` — 名不副实的 "background" context

虽然方法名包含 "Async" 并创建了可选的 `backgroundContext`，但全部操作仍在 `@MainActor` 上串行执行。与直接使用 `mainContext` 无异。

---

## E. 性能

### E1. `TranslationCacheStore.save()` — 每次写入全量 count 查询

**文件：** `Core/State/Stores/TranslationCacheStore.swift` (line 84)

```swift
let totalCount = (try? self.backgroundContext.fetch(FetchDescriptor<TranslationCache>()).count) ?? 0
```

每次保存缓存条目时都执行全表 COUNT 查询。当缓存条目数 > 100k 时影响显著。

---

### E2. `BookmarkCacheStore` — 批量操作单条处理

在 `performFullSync` 中，每张插图独立执行：

- `FetchDescriptor` + `context.fetch` 判断是否存在
- `context.save()` 立即持久化
- `loadCachedBookmarks()` 重新加载全量

1000 张插图 = 3000+ 次 SwiftData 操作。

---

### E3. `ResponsiveGrid` — `onAppear` + 首次 `onChange` 重复计算

**文件：** `Shared/Components/Layout/ResponsiveGrid.swift`

`onAppear` 触发 `updateColumnCount(for: proxy.size.width)`，随后 `onChange(of: proxy.size.width)` 也以初始宽度触发，导致一次布局计算重复两次。
