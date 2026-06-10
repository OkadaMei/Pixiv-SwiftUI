# Pixiv-SwiftUI 代码审计报告

> 生成日期: 2026-06-10
> 审计范围: `Pixiv-SwiftUI/` 主工程（约 296 个 Swift 文件）
> 审计维度: 架构设计、性能、安全性（基础设施层面）、用户体验

---

## 一、架构设计 (Architecture)

### 问题 A-1: DIContainer 沦为死代码

**严重程度**: ★★★
**文件**: `Core/State/Base/DIContainer.swift`

`DIContainer` 定义了完整的 DI 框架（`NetworkService`、`AuthService`、`CacheService` 协议 + 实现），但 `NetworkServiceImpl.request` 直接 `preconditionFailure("not implemented")`，所有 Store 和 API 全部使用 `static let shared` 单例。

**影响**:
- 可测试性为零，无法 mock 依赖进行单元测试
- 容器本身占用代码量却无实际作用，误导后续开发者

**建议**:
- 方案 A：彻底移除 DIContainer，统一使用 shared 单例模式并明确约定
- 方案 B：真正实现 DI，通过 `@Environment` 或初始化注入方式管理依赖

---

### 问题 A-2: PixivAPI 协调器层过胖

**严重程度**: ★★★
**文件**: `Core/Network/PixivAPI.swift`（646 行）

`PixivAPI` 同时承担了以下职责：
- API 路由调度
- App API + Ajax API 双 Session 生命周期管理
- Token 刷新代理
- 各子 API（SearchAPI、IllustAPI 等）的懒加载初始化
- Ajax Cookie 状态管理

**影响**:
- 违反单一职责原则，修改任一职责需理解全部逻辑
- 646 行文件难以维护和测试
- Ajax 和 App API 两套认证体系的耦合使得任意一方的变更都可能影响另一方

**建议**:
拆分为三个独立模块：
```
PixivAPI (轻量协调) → APISessionManager (Token/Ajax Session生命周期)
                    → ApiRouter (端点和Header组装)
                    → 子API层 (业务无关)
```

---

### 问题 A-3: Store 间隐式双向依赖

**严重程度**: ★★
**涉及文件**: `AccountStore`、`UserSettingStore`、`ThemeManager`、`IllustStore` 等

当前依赖关系网：
- `ThemeManager` → `UserSettingStore.shared`
- `AccountStore` → `DataContainer.shared`
- `UserSettingStore` → `AccountStore.shared.currentUserId`
- `IllustStore` → `AccountStore.shared.currentUserId`、`CacheManager.shared`
- `DownloadStore` → `UserSettingStore.shared`

这些隐式依赖在初始化时序上尤其脆弱 —— `AppInitializer` 必须严格按顺序 `loadAccountsAsync() → loadUserSettingAsync()`，否则可能因依赖项未就绪而崩溃。

**建议**:
- 通过协议（Protocol）定义 Store 间接口，注入而非直接访问 `.shared`
- 或在 `AppInitializer` 中显式管理依赖图，初始化完成后冻结

---

### 问题 A-4: SwiftData 领域模型双重职责

**严重程度**: ★★
**涉及文件**: `Illust.swift`、`User.swift`、`Tag.swift` 等 Domain 模型

Domain 模型同时充当了：
1. API 响应 DTO（直接 `Decodable`）
2. SwiftData 持久化实体（`@Model`）

**影响**:
- API 响应结构的变化会直接破坏持久化数据兼容性
- `Codable` + `@Model` 双重注解导致大量样板代码（手动 `CodingKeys`、`init`/`encode`）
- 无法在不破坏序列化的情况下重构领域逻辑（如将 `Illusts` 拆分为多个子结构）
- SwiftData 的 `@Attribute(.unique)` 约束与 API 返回数据冲突时处理不明确

**建议**:
引入 DTO（`Network/`）→ Domain（`Domain/`）→ Persistence（`Persistence/`）三层映射：
```
APIResponse → DTO (Decodable) → Domain Model (纯Swift) → SwiftData Entity (@Model)
```
当前可先从 `Illusts`、`User` 等核心模型开始渐进式重构。

---

### 问题 A-5: View 层过重，业务逻辑内联

**严重程度**: ★★

| 文件 | 行数 |
|------|------|
| `SearchView.swift` | 676 |
| `RecommendView.swift` | 596 |
| `IllustCard.swift` | 468 |
| `NovelReaderView.swift` | 481 |

View 文件承担了过滤、排序、预取、缓存管理、分页逻辑等职责。例如 `RecommendView` 直接管理 `filteredIllusts` 计算、`shouldBlurMap` 构建、`prefetchTracker` 等——这些应属于 ViewModel 或 Store 的职责。

**影响**:
- 难以单元测试业务逻辑
- 多人协作时容易产生合并冲突
- 无法复用过滤/预取逻辑

**建议**:
- 抽取 `IllustFilterService` 管理过滤和 blur 判定逻辑
- 将 `shouldBlurMap` 和 `filteredIllusts` 的构建移入 Store 或专用的 `ViewModel`
- View 保持展示和交互逻辑，数据准备交由下层

---

## 二、性能 (Performance)

### 问题 P-1: CacheManager 内存泄漏隐患

**严重程度**: ★★★
**文件**: `Shared/Utils/CacheManager.swift`

`CacheManager` 使用 `[String: CacheEntry]` 字典缓存数据，其中 `CacheEntry.data` 是 `Any` 类型（类型擦除）。系统内存压力时无自动清理机制，仅有 `maxEntries = 100` 的软限制。

**具体风险**:
- `CacheEntry` 强引用任意类型对象，大对象（如大型 `[Illusts]` 数组）可能无法及时释放
- 未监听 `didReceiveMemoryWarningNotification`
- `cleanExpiredEntries()` 仅在 `cacheMap.count > maxEntries` 时触发，过期缓存可能长时间驻留
- `Any` 类型擦除意味着每次 `get<T>()` 都是运行时类型强转，存在 `as!` 失败风险

**建议**:
- 改用 `NSCache<NSString, CacheEntry>` —— 系统级的自动淘汰
- 或在 `AppInitializer` 中注册内存警告回调，调用 `CacheManager.clearAll()`
- 考虑引入 `DiskCache` + `MemoryCache` 两层架构而非单一字典
- 对缓存值类型使用泛型约束，避免 `Any`

---

### 问题 P-2: 双重缓存策略不一致

**严重程度**: ★★
**涉及文件**: `IllustStore`、`BookmarksStore`、`UpdatesStore`、`CacheManager`

各 Store 同时维护了：
1. 自身属性缓存（如 `rankingIllustsByMode`、`bookmarks`、`updates`）
2. `CacheManager` 内存字典缓存

两条路径的过期时间、失效策略、数据一致性均不一致：
```swift
// IllustStore 示例
self.rankingIllustsByMode[mode, default: []].append(contentsOf: result.illusts) // 属性缓存
cache.set(result, forKey: key, expiration: expiration)                           // CacheManager 缓存
```

读取时的优先逻辑也不统一，部分 Store 优先读 CacheManager，部分优先读自身属性。

**建议**:
- 统一缓存抽象：只用一个缓存层
- 或明确职责：`CacheManager` 负责持久化缓存 + 跨 session 恢复，Store 属性负责当前 session 状态

---

### 问题 P-3: CachedAsyncImage 的状态复用风险

**严重程度**: ★★
**文件**: `Shared/Utils/Helpers.swift`（CachedAsyncImage）

自定义 `CachedAsyncImage` 使用 `.task(priority: .low)` + `@State` 存储图片。在 LazyVStack 场景中，存在以下风险：
- Cell 被回收后重新入列，`@State` 仍持有旧图片数据，出现「闪一下旧图再变新图」的视觉问题
- Kingfisher 官方 `KFImage` 内部有 `ImageBinder` 负责处理复用场景的自洽逻辑，自定义方案未验证等价行为
- 异步任务取消时机不明确

**建议**:
- 在 `onDisappear` 中取消进行中的加载 Task
- 在 `urlString` 变化时强制重置 `loadedImage = nil`
- 考虑直接使用 `KFImage` 替代自定义方案，除非有明确的性能数据支持自定义方案更优

---

### 问题 P-4: 并发下载 Range 请求在直连模式下的完整性

**严重程度**: ★
**文件**: `Core/Network/Client/NetworkClient.swift` 中的 `concurrentDownload`

分片并发下载策略先通过 Range 请求获取文件大小，再分片并行下载。以下情况未充分处理：
- 服务器不支持 206 Partial Content 时的回退策略
- 分片下载完成后各分片拼接时的完整性校验
- `DirectConnection` 模式下 Range 响应头与标准 URLSession 差异

**建议**:
- Range 请求失败时自动降级为单线程完整下载
- 下载完成后对拼接文件的 size 做完整性校验

---

## 三、安全性 (Security — Infrastructure)

### 问题 S-1: 空 Entitlements 文件

**严重程度**: ★★
**文件**: `Pixiv-SwiftUI.entitlements`

Entitlements 文件为空 `<dict/>`，但项目使用 Keychain 存储 token、可能涉及网络扩展、沙箱文件访问等功能。苹果在提交 App Store 时会强制校验 entitlements 与能力的一致性。

**建议**:
- 显式声明 `keychain-access-groups`
- 若涉及网络扩展或跨进程访问，按需添加对应 entitlement
- 至少保留 `com.apple.security.app-sandbox`（macOS）等基础的沙箱声明

---

### 问题 S-2: Debug 日志泄露内部状态

**严重程度**: ★★
**涉及文件**: 多处

Release 构建中存在大量 `print()` 语句，包含：
- URL、文件路径、用户 ID 等标识信息
- API 返回的数据结构片段
- 内部状态变更日志

```swift
// 示例
print("[DirectImageDataProvider] 开始加载: \(self.url.absoluteString)")
print("[BookmarksStore] fetchBookmarks: restrict=\(capturedRestrict), userId=\(userId)")
```

**建议**:
- 统一使用 `os_log` / `Logger` 替代 `print()`，在产品构建中自动移除
- 或对敏感日志添加 `#if DEBUG` 编译条件

---

## 四、用户体验 (UX)

### 问题 UX-1: 全局错误处理不统一

**严重程度**: ★★★
**涉及文件**: `UpdatesStore`、`IllustStore`、`SearchStore` 等多数 Store

各 Store 的错误处理策略不统一：

| Store | 失败时行为 |
|-------|-----------|
| `UpdatesStore.fetchUpdates()` | 仅 `print("Failed: \(error)")`，`isLoadingUpdates` 通过 defer 置 false，用户无感知 |
| `IllustStore.loadMoreRanking()` | 空 catch，用户无感知 |
| `AccountStore.loadAccounts()` | 设置 `self.error = AppError.databaseError(...)`，但 View 层未统一监听 |
| `SearchStore` | 部分方法透传 throw，由 View 层 catch |

存在以下问题：
- 部分加载失败后 UI 永远停留在 loading 状态
- 无统一的 Toast / Alert 错误呈现通道
- 无自动重试机制

**建议**:
- 引入 `ErrorWrapper` 统一状态管理（`isError: Bool`、`errorMessage: String`、`retryAction: () -> Void`）
- 在 `App` 层或 `ContentView` 层注册全局错误 Toast
- 网络错误自动重试策略（如指数退避）

---

### 问题 UX-2: 网络模式切换无状态恢复

**严重程度**: ★★
**文件**: `Core/Network/NetworkMode.swift`

`NetworkModeStore` 支持在「标准模式」和「直连模式」之间实时切换，但切换后：
- 正在进行的网络请求不会自动取消并重试
- 已因网络问题失败的请求不会自动恢复
- UI 状态停留在错误/空状态，用户需要手动下拉刷新

**建议**:
- 切换网络模式时发送 `Notification`，各 Store 监听并自动刷新当前展示内容
- 或在切换时提供一个「刷新当前页面」的轻提示

---

### 问题 UX-3: 搜索缺少输入防抖 (Debounce)

**严重程度**: ★★
**文件**: `Features/Search/SearchView.swift`

搜索输入框未实现输入防抖，在连续快速输入时会触发多次 API 请求。不仅浪费用户流量，还可能因请求返回顺序导致搜索结果与输入不匹配。

**建议**:
```swift
// 在 SearchStore 或 SearchView 中添加防抖
.task(id: searchText) {
    try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
    guard !Task.isCancelled else { return }
    await performSearch()
}
```
同时在 `searchText` 变化时自动取消前一个 Task。

---

### 问题 UX-4: 首次启动缺少引导流程

**严重程度**: ★★

新用户首次安装后直接进入 `AuthView`（登录页），缺少：
- 应用功能介绍或引导页
- 游客模式的功能范围说明
- 语言/主题/内容过滤等初始化设置向导
- 对 Pixiv 平台的使用条款确认（当前仅依赖 Pixiv OAuth 的同意页）

**影响**:
新用户流失风险较高 —— 未登录状态下能做什么、不能做什么没有明确指引。

**建议**:
- 首次启动时展示 2-3 屏的功能介绍（可跳过）
- 游客模式下提供「登录后可使用的功能」提示
- 登录成功后引导完成基础设置（内容过滤偏好、图片质量等）

---

## 五、其他

### 问题 O-1: SwiftLint 配置过于宽松

**文件**: `.swiftlint.yml`

当前配置关闭了多项对代码质量有实质影响的规则：

| 规则 | 状态 | 影响 |
|------|------|------|
| `function_body_length` | disabled | 部分函数（如 View body）可无限膨胀 |
| `type_body_length` | disabled | 单文件可达数千行 |
| `line_length` | warning: 1000 | 1000 字符的行几乎不可读 |
| `cyclomatic_complexity` | warning: 20 | 分支复杂度 20 意味着极难测试 |

**建议**:
逐步收紧规则，至少开启 `function_body_length`（warning: 50, error: 100）和合理的 `line_length`（warning: 120, error: 200）。

---

### 问题 O-2: macOS 回退逻辑中 NSAppearance 可能已被废弃

**文件**: `Core/State/ThemeManager.swift`（L59-68）

```swift
NSApp.appearance = appearance
NSApp.windows.forEach { $0.appearance = appearance }
```
在 macOS 14+ 中，`NSAppearance` 的直接设置已被标记为 deprecated，推荐使用 `NSWindow.appearance` 或 SwiftUI 的 `preferredColorScheme`。

---

## 优先级总览

| 优先级 | 分类 | 问题 | 预估工作量 |
|--------|------|------|-----------|
| 🔴 P0 | UX | UX-1 全局错误处理不统一 | 3-5天 |
| 🔴 P0 | Performance | P-1 CacheManager 内存泄漏隐患 | 1-2天 |
| 🟡 P1 | Architecture | A-2 PixivAPI 重构 | 5-7天 |
| 🟡 P1 | Architecture | A-4 引入 DTO 映射层 | 5-10天 |
| 🟡 P1 | UX | UX-3 搜索防抖 | 0.5天 |
| 🟢 P2 | Architecture | A-3 Store 依赖注入 | 3-5天 |
| 🟢 P2 | Performance | P-2 统一缓存策略 | 2-3天 |
| 🟢 P2 | UX | UX-4 首次引导流程 | 3-5天 |
| 🟢 P3 | Architecture | A-5 View 瘦身 | 持续改进 |
| 🔵 P4 | 其他 | O-1 SwiftLint 配置、O-2 macOS API | 按需 |

---

*注: 本审计报告排除了 Pixiv 社区约定俗成的事项（如 Client Secret 的公开使用、SNI 绕过策略、IP 硬编码等），聚焦于项目自身架构质量和可维护性问题。*
