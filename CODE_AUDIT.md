# Pixiv-SwiftUI 代码审计报告

> 生成日期: 2026-06-12
> 审计范围: `Pixiv-SwiftUI/` 主工程（约 296 个 Swift 文件）
> 审计维度: 架构设计、性能、安全性（基础设施层面）、用户体验
> 更新说明: 移除已完成的 A-3（Store 依赖注入，2026-06-12）、A-4（DTO 映射层，2026-06-12）、P-2（统一缓存策略，2026-06-12）、S-2（日志系统，2026-06-12）、S-1（Entitlements 声明，2026-06-12）、P-4（并发下载完整性，2026-06-12）

---

## 一、架构设计 (Architecture)

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

### 问题 P-3: CachedAsyncImage 的状态复用风险

**严重程度**: ★★（经代码审查确认非真实问题，见下方验证）
**文件**: `Shared/Utils/Helpers.swift`（CachedAsyncImage）

自定义 `CachedAsyncImage` 使用 `.task(priority: .low)` + `@State` 存储图片。在 LazyVStack 场景中，存在以下风险：
- Cell 被回收后重新入列，`@State` 仍持有旧图片数据，出现「闪一下旧图再变新图」的视觉问题
- Kingfisher 官方 `KFImage` 内部有 `ImageBinder` 负责处理复用场景的自洽逻辑，自定义方案未验证等价行为
- 异步任务取消时机不明确

**验证结论**（2026-06-12）: 经审查本项目 WaterfallGrid、LazyVStack/LazyVGrid 中所有 39 个 CachedAsyncImage 调用点，ForEach 全部使用 `Identifiable` 稳定标识。SwiftUI 的身份系统确保 LazyVStack 中不同 id 的视图不会互相复用 `@State`，视图滚出屏幕时随之一同销毁、滚回时全新创建。因此该风险在本项目中不存在。

**建议**:
- ~~在 `onDisappear` 中取消进行中的加载 Task~~
- ~~在 `urlString` 变化时强制重置 `loadedImage = nil`~~
- ~~考虑直接使用 `KFImage` 替代自定义方案，除非有明确的性能数据支持自定义方案更优~~

---

## 三、用户体验 (UX)

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

### 问题 UX-3: 首次启动缺少引导流程

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

## 四、其他

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

## 已关闭

### ✅ A-3: Store 间隐式双向依赖（2026-06-12 完成）

**方案**: 3 个轻量协议（AuthSessionProtocol / AppSettingsProtocol / CacheStorageProtocol）+ 构造函数注入 + NotificationCenter 解耦。

**变更**:
- 新增 3 个协议定义在 `Core/State/Base/`
- `AccountStore` 遵循 `AuthSessionProtocol`，`UserSettingStore` 遵循 `AppSettingsProtocol`
- 9 个核心 Store（IllustStore、BookmarksStore、NovelStore、SearchStore、MangaStore、DownloadStore、WebDAVSyncStore、NovelReaderStore、ThemeManager）通过 init 参数注入依赖，默认值保持 `.shared` 向后兼容
- `AccountStore.onAccountChanged()` 从直接调用 5 个 Store 的方法改为发 `Notification.Name.accountDidChange`，各 Store 在 init 中自行 observer 处理
- 删除 `hasCachedBookmarks`/`hasCachedUsers`/`hasCachedFollowing` 等隐蔽的 Store 间依赖

---

### ✅ P-2: 双重缓存策略不一致（2026-06-12 完成）

**方案**: 定义 `CacheStorageProtocol` 统一缓存抽象，消除 Store 自身的双层缓存模式。

**变更**:
- 新增 `CacheStorageProtocol` 协议，`CacheManager` 遵循
- 10 个 Store + 5 个 View 的 `cache` 属性类型从 `CacheManager` 改为 `CacheStorageProtocol`
- 删除「先检查自身数组 → 再查 CacheManager」的双层逻辑，统一为 `cache.get()` 单一路径
- 移除 4 个仅用于双层首检的 computed property（`hasCachedBookmarks` / `hasCachedUpdates` / `hasCachedFollowing` / `hasCachedUsers`）
- 净删除 ~80 行冗余代码

---

### ✅ A-4: SwiftData 领域模型双重职责（2026-06-12 完成）

**方案**: 引入 DTO → Domain → Persistence 三层映射，API 响应先解码为 DTO，再映射为 Domain 模型。

**变更**:
- 新增 `Core/DataModels/Network/DTO/` 目录，包含 8 个 DTO 类型
- 从 `Illusts`、`Tag`、`ImageUrls`、`MetaPages`、`MetaSinglePage`、`MetaPagesImageUrls`、`IllustSeries` 移除了 `Codable`（~300 行样板代码）
- 所有 API 端点改为解码 DTO 后再映射到 Domain 模型
- `User`/`ProfileImageUrls` 标记为 `@Model nonisolated`，移除僵尸 `Codable`
- 所有 DTO 类型和映射函数标记为 `nonisolated`，避免 actor 隔离泄漏

---

### ✅ S-2: Debug 日志泄露内部状态（2026-06-12 完成）

**方案**: 使用 `os_log` / `Logger` 统一替代 `print()`。

**变更**:
- 移除 49 个文件中 208 处 `print()` 调用，全部替换为 `Logger.<category>.<level>()`
- 新增 6 个 Logger 分类：`.search`、`.illust`、`.updater`、`.user`、`.general`
- 所有 Logger 属性标记为 `nonisolated` 以兼容 Swift 6 严格并发
- 对 URL、用户 ID、IP 等敏感信息添加 `privacy: .public` 显式标注
- 日志级别治理：~30 处成功消息从 `.debug` 提升为 `.info`，~30 处可恢复错误从 `.error` 降级为 `.warning`
- 移除约 200 处冗余的 `[ClassName]` 前缀字符串（`category` 参数已标识来源）
- 清理僵尸 `import os.log`（CrashReportExportService），合并私有 Logger 实例（IpCacheManager、TagTranslationService）

---

### ✅ S-1: 空 Entitlements 文件（2026-06-12 完成）

**方案**: 显式声明沙箱、网络、文件访问、Keychain 等 macOS/iOS entitlements，与 Xcode build settings 保持一致。

**变更**:
- `Pixiv-SwiftUI.entitlements` 从空 `<dict/>` 填充为 6 项 entitlement 声明
- `com.apple.security.app-sandbox` → 对应 `ENABLE_APP_SANDBOX = YES`
- `com.apple.security.network.client` + `.server` → 对应出站/入站网络连接
- `com.apple.security.files.user-selected.read-write` → 对应 `ENABLE_USER_SELECTED_FILES = readwrite`
- `com.apple.security.cs.allow-jit` → 对应 `ENABLE_HARDENED_RUNTIME = YES`（SwiftUI/调试需要）
- `keychain-access-groups` → 使用 `$(AppIdentifierPrefix)org.eu.eslzzyl.Pixiv-SwiftUI`，确保沙箱环境下 Keychain 可正常读写

---

### ✅ P-4: 并发下载 Range 请求完整性（2026-06-12 完成）

**方案**: 添加 206 响应验证 + 最终文件大小校验 + 失败自动回退单线程下载。

**变更**:
- `NetworkError` 新增 `rangeNotSupported` 错误类型
- `concurrentDownload` 每个分片下载完成后验证 HTTP 206 状态码，服务器忽略 Range 头时抛出 `rangeNotSupported`
- 所有分片完成后校验组装文件的实际大小是否等于预期总长度
- 分段下载失败（含 Range 不支持、完整性校验失败）时清理临时文件并自动降级为单线程 `downloadWithByteProgress`
- 取消错误 (`CancellationError`) 正确传播，仅清理临时文件不降级

---

## 优先级总览

| 优先级 | 分类 | 问题 | 预估工作量 |
|--------|------|------|-----------|
| 🔴 P0 | Security | ~~S-1 Entitlements 声明~~ ✅ | 已完成 |
| 🔴 P0 | Performance | ~~P-4 并发下载 Range 回退~~ ✅ | 已完成 |
| 🟡 P1 | UX | UX-2 网络模式切换无状态恢复 | 1天 |
| 🟢 P2 | UX | UX-3 首次引导流程 | 3-5天 |
| 🟢 P2 | Quality | O-1 SwiftLint 规则收紧 | 0.5天 |
| 🟢 P3 | Architecture | A-5 View 瘦身 | 持续改进 |
| ⚪ — | Performance | P-3 CachedAsyncImage 状态复用 | 非问题（SwiftUI 身份系统确保 @State 隔离） |

---

*注: 本审计报告排除了 Pixiv 社区约定俗成的事项（如 Client Secret 的公开使用、SNI 绕过策略、IP 硬编码等），聚焦于项目自身架构质量和可维护性问题。*
