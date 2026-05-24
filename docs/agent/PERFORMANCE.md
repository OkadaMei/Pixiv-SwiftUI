# 性能优化指南

本文档记录了 Pixiv-SwiftUI 项目当前已知的性能问题、分析及优化建议。

## 如何分析性能

### 工具

- **Xcode Instruments**: Time Profiler, SwiftUI 模板, Allocations
- **Xcode 视图层级调试 (View Hierarchy Debugger)**: 检查视图过度绘制
- **SwiftUI 的 `Self._printChanges()`**: 在视图 `body` 中插入 `let _ = Self._printChanges()` 可打印视图刷新原因

### 在调试中复现问题

在修改前后分别用 Instruments Time Profiler 在真机/设备上录制相同操作（如快速滚动瀑布流），对比主线程挂起时间。

---

## 性能问题清单

### 🔴 P0 — 严重影响帧率 / 响应速度

#### 1. `@Observable` 过度订阅导致大面积重渲染

**关键词**: `@Observable` 重渲染、Store 订阅、视图无效化

**问题描述**:
大量视图在 `body` 中直接读取 `@Environment(SomeStore.self)` 的深层嵌套属性，例如：

```swift
// 以下代码导致视图订阅了 settingStore.userSetting（整个对象）
settingStore.userSetting.feedPreviewQuality
settingStore.userSetting.showSearchPopularBookmarkCount
settingStore.filterIllusts()
```

在 Swift Observation 中，视图 `body` 内**读取过的 `@Observable` 属性**变化时会触发视图重新求值。`UserSettingStore` 有约 80 个属性，**任何一个属性变化**（如用户滑动一个开关），所有读取了该 Store 的视图都失效重算。

**影响范围**:

| 维度 | 数据 |
|------|------|
| 涉及文件 | ~50+ 视图文件 |
| `settingStore.userSetting.XXX` 深层访问 | 177 处 |
| 最大视图 | `IllustDetailView` 828 行、`SearchResultView` 655 行 |
| 多 Store 大视图 | 8 个视图同时使用 2-3 个 Store |
| 共享卡片组件 | `IllustCard`、`BookmarkCard` 在瀑布流中被高频复用 |

**影响文件**:
- `Pixiv-SwiftUI/Features/Search/SearchResultView.swift` — 3 Store，30+ 深层访问
- `Pixiv-SwiftUI/Features/General/IllustDetailView.swift` — 2 Store，大量深层访问
- `Pixiv-SwiftUI/Features/Home/RecommendView.swift` — 2 Store，10+ 深层访问
- `Pixiv-SwiftUI/Features/Bookmark/BookmarksPage.swift` — 深层访问 filter 设置
- `Pixiv-SwiftUI/Shared/Components/Card/IllustCard.swift` — 卡片组件，瀑布流中复用
- `Pixiv-SwiftUI/Shared/Components/Card/BookmarkCard.swift` — 同上

**优化建议**:
1. **提取子视图 + 参数传递**（推荐）：将大视图中依赖 Store 的区域拆成小视图，通过参数传入具体值，而非让子视图自己从 Store 读取。
2. **计算属性提取**：将 `settingStore.userSetting.XXX` 提取为局部 `let`，代码更清晰但无法彻底解决订阅粒度问题。
3. **拆分 `UserSettingStore`**：将 ~80 属性的巨无霸 Store 拆为多个按功能分类的小 Store。

---

#### 2. 主线程同步文件 I/O

**关键词**: 主线程阻塞、文件读取、以图搜图

**问题描述**:
`SearchView.swift` 中的 `searchWithImageURL` 方法标记为 `@MainActor`，但内部通过 `Data(contentsOf:)` 同步读取用户选择的文件，完全阻塞主线程。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Search/SearchView.swift` — `searchWithImageURL(_:)` 方法

**当前状态**: **✅ 已修复**（commit `c67a20a`）

**修复方式**: 将文件读取移至 `Task.detached` 后台线程，通过 `await .value` 将结果传回主线程上下文。

---

### 🟠 P1 — 高优先级

#### 3. WaterfallGrid 通过 GeometryReader 频繁触发列重算

**关键词**: GeometryReader、布局重算、列分布

**问题描述**:
`WaterfallGrid` 使用 `GeometryReader` 监听容器宽度变化，在 `.onChange(of: proxy.size.width)` 中触发完整的列重分布计算。在 iPad 多任务、屏幕旋转、键盘弹出等场景下会反复触发。

**涉及文件**:
- `Pixiv-SwiftUI/Shared/Components/Layout/WaterfallGrid.swift`（第 92-103 行）
- `Pixiv-SwiftUI/Shared/Components/Layout/ResponsiveGrid.swift`

**优化建议**:
- 对宽度变化增加缓冲/节流（如 100ms 间隔）
- 小变化（< 10pt）跳过重算
- 列分布计算移至后台线程

---

#### 4. `UserSetting` SwiftData 模型属性膨胀

**关键词**: SwiftData、模型设计、@Model

**问题描述**:
`UserSetting` (@Model) 包含约 80 个属性，导致：
- 每次读取加载大量数据（即使只需要一两个值）
- 行大小远大于实际需要
- 与 P0 #1 叠加，任何属性变化触发连锁重渲染

**涉及文件**:
- `Pixiv-SwiftUI/Core/DataModels/Persistence/UserSetting.swift`

**优化建议**:
- 按功能领域拆分为多个模型（如 `DisplaySettings`、`FilterSettings`、`QualitySettings`）
- 将纯 UI 配置移至 `UserDefaults`
- 计算属性添加 `@Transient`

---

#### 5. Store 全部在主线程进行 SwiftData 操作

**关键词**: 主线程、SwiftData 上下文、后台查询

**问题描述**:
几乎所有 Store 都直接用 `dataContainer.mainContext` 进行增删改查。只有 `TranslationCacheStore` 正确使用后台上下文。大查询（如全表扫描）时会卡住主线程。

**涉及文件**:
- `Pixiv-SwiftUI/Core/State/Stores/IllustStore.swift`
- `Pixiv-SwiftUI/Core/State/Stores/NovelStore.swift`
- `Pixiv-SwiftUI/Core/State/Stores/BookmarkCacheStore.swift`
- 以及其他使用 `mainContext` 的 Store

**优化建议**:
参照 `TranslationCacheStore` 的模式：
- `Pixiv-SwiftUI/Core/State/Stores/TranslationCacheStore.swift` — 使用 `DispatchQueue(qos: .utility)` + `backgroundContext`

---

#### 6. 未处理内存警告

**关键词**: 内存警告、Kingfisher 缓存、OOM

**问题描述**:
项目未实现 `UIApplication.didReceiveMemoryWarningNotification` 处理。系统内存不足时，Kingfisher 内存缓存（100MB）和书签缓存（50MB）不会被主动清理。

**涉及文件**:
- `Pixiv-SwiftUI/Core/Network/CacheConfig.swift` — 缓存配置

**优化建议**:
在 `AppDelegate` 或 `ScenePhase` 变化中监听内存警告，主动清理 Kingfisher 缓存：

```swift
NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
    ImageCache.default.clearMemoryCache()
    PixivImageLoader.sharedImageCache?.clearMemoryCache()
}
```

---

### 🟡 P2 — 中优先级

#### 7. 递归分页风险

**关键词**: 分页、无限循环、API 限流

**问题描述**:
`RecommendView.loadMoreData()` 中，当 API 返回空 `illusts` 但 `nextUrl` 非空时，会递归调用 `loadMoreData()`，可能导致无限 API 请求。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Home/RecommendView.swift`（第 382-385 行）

**优化建议**: 在递归路径中加入重试计数限制或延迟。

---

#### 8. SwiftData 计算属性未标记 `@Transient`

**关键词**: @Model、@Transient、SwiftData

**问题描述**:
`Illust` 模型中的 `safeAspectRatio`、`isSpoiler`、`isManga` 等 6 个计算属性未标注 `@Transient`，SwiftData 会尝试处理它们，增加不必要的开销。

**涉及文件**:
- `Pixiv-SwiftUI/Core/DataModels/Domain/Illust.swift`

**优化建议**:
```swift
@Transient
var safeAspectRatio: CGFloat { ... }
```

---

#### 9. ScrollOffsetPreferenceKey 每次滚动触发

**关键词**: PreferenceKey、滚动监听、视图重绘

**问题描述**:
`BookmarksPage` 通过 `ScrollOffsetPreferenceKey` 监听滚动偏移，`onPreferenceChange` 在每次滚动时触发（即使 1pt），配合 `withAnimation` 可能造成不必要的动画帧。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Bookmark/BookmarksPage.swift`（第 178 行）
- `Pixiv-SwiftUI/Shared/Utils/Helpers.swift`（`ScrollOffsetPreferenceKey` 定义）

**优化建议**:
对 `onPreferenceChange` 回调添加阈值判断，减少不必要动画触发。

---

#### 10. `NovelSpanRenderer` 中多余的 `.eraseToAnyView()`

**关键词**: AnyView、类型擦除

**问题描述**:
`uploadedImageView`、`jumpUriView`、`rubyTextView` 三个计算属性声明为 `some View` 但调用了 `.eraseToAnyView()`，返回 `AnyView`。属于无声的类型不匹配，且 AnyView 带来运行时类型擦除开销。

**涉及文件**:
- `Pixiv-SwiftUI/Shared/Components/Text/NovelSpanRenderer.swift`（第 139、216、238 行）

**优化建议**: 直接移除 `.eraseToAnyView()` 调用。

---

#### 11. 不必要的 `@Bindable`

**关键词**: @Bindable、观察开销

**问题描述**:
以下视图中 Store 仅用于读取，无需 `@Bindable`。`@Bindable` 比普通 `@Environment` 有额外的观察开销：

| 视图 | Store | 读/写 |
|------|-------|-------|
| `MainSplitView` | AccountStore | 只读 |
| `MainTabView` | AccountStore | 只读 |
| `ProfileButton` | AccountStore | 只读 |

**涉及文件**:
- `Pixiv-SwiftUI/Features/Home/MainSplitView.swift`
- `Pixiv-SwiftUI/Features/Home/MainTabView.swift`
- `Pixiv-SwiftUI/Shared/Components/Profile/ProfileButton.swift`

**优化建议**: 将 `@Bindable` 改为 `@Environment(StoreType.self)` 只读访问。

---

#### 12. `FetchDescriptor` 缺少 `fetchLimit`

**关键词**: SwiftData、查询、fetchLimit

**问题描述**:
大量 `FetchDescriptor` 没有设置 `fetchLimit`，可能一次拉取数千条记录。

**涉及文件**: 所有使用 `FetchDescriptor` 的 Store（共 48 处引用）

**优化建议**: 对分页/列表查询显式设置 `.fetchLimit`。

---

#### 13. 频繁查询字段缺少索引

**关键词**: SwiftData、索引、查询性能

**问题描述**:
`illustId`、`ownerId`、`createDate` 等常用于过滤/排序的字段未显式添加索引。目前仅 `@Attribute(.unique)` 字段有隐式索引。

**涉及文件**: 所有 SwiftData 模型文件

**优化建议**:
```swift
@Attribute(.unique) var id: Int
// 对频繁查询字段添加索引
@Attribute(.indexed) var ownerId: Int
```

---

### 🟢 P3 — 低优先级

#### 14. `.id()` 强制视图重建

**关键词**: 视图重建、ScrollView、.id()

**问题描述**:
分页组件使用 `.id(nextUrl)` 控制视图刷新，导致整个列表重建，丢弃滚动位置。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Home/RecommendView.swift`（第 152 行）
- `Pixiv-SwiftUI/Features/Home/UpdatesPage.swift`（第 103 行）
- `Pixiv-SwiftUI/Features/Bookmark/BookmarksPage.swift`（第 153 行）

**优化建议**: 将状态变化通过普通 `@State` 或 `@Observable` 属性驱动，而非改变 `.id()`。

---

#### 15. 多个 `onReceive` 无生命周期管理

**关键词**: NotificationCenter、订阅、内存泄漏

**问题描述**:
`MenuCommandHandler` 链式使用 7 个 `.onReceive(NotificationCenter.default.publisher(for: ...))`，所有订阅与视图共存，没有显式取消机制。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Menu/MenuCommandHandler.swift`（第 19-49 行）
- `Pixiv-SwiftUI/Features/Home/RecommendView.swift`
- `Pixiv-SwiftUI/Features/Home/UpdatesPage.swift`
- 等多个页面，共 20+ 处

**优化建议**:
- 对于低频通知（菜单命令）影响不大，可忽略
- 如需优化，可将多个订阅合并为单个 `onReceive`，或在 `onDisappear` 中取消

---

#### 16. 刷新无防抖

**关键词**: 防抖、刷新、并发加载

**问题描述**:
快速触发 `.refreshCurrentPage` 通知会导致并发 `refreshAll()` 调用。

**涉及文件**:
- `Pixiv-SwiftUI/Features/Home/RecommendView.swift`（第 259 行）

**优化建议**: 在 Store 侧添加 `isRefreshing` 状态锁，或使用 `Task` 的取消机制。

---

#### 17. Kingfisher 内存缓存 150MB

**关键词**: 内存、Kingfisher、缓存策略

**问题描述**:
默认内存缓存 100MB + 书签缓存 50MB，共 150MB 常驻内存。在低内存设备上可能触发系统压力。

**涉及文件**:
- `Pixiv-SwiftUI/Core/Network/CacheConfig.swift`

**优化建议**: 视设备内存大小动态调整缓存上限。

---

## 修改优先级建议

### 🥇 第一优先级（改动小，收益大）

| 序号 | 问题 | 预估工作量 | 备注 |
|------|------|-----------|------|
| #2 | 主线程同步 I/O | ✅ 已修复 | commit `c67a20a` |
| #6 | 内存警告处理 | ~0.1 天 | 几行代码 |
| #10 | 移除 `.eraseToAnyView()` | ~0.1 天 | 三处删除 |
| #11 | 移除不必要的 `@Bindable` | ~0.1 天 | 三处改动 |

### 🥈 第二优先级（结构性优化）

| 序号 | 问题 | 预估工作量 | 备注 |
|------|------|-----------|------|
| #1 | @Observable 过度订阅 | ~5.5 天 | 拆子视图+参数化 |
| #3 | GeometryReader 频繁重算 | ~0.5 天 | 加节流 |
| #8 | 计算属性 @Transient | ~0.1 天 | 加注解 |
| #12 | fetchLimit | ~0.3 天 | 逐个 Store |
| #13 | 字段索引 | ~0.2 天 | 加注解 |

### 🥉 第三优先级（架构级改动）

| 序号 | 问题 | 预估工作量 | 备注 |
|------|------|-----------|------|
| #4 | UserSetting 模型拆分 | ~3 天 | 影响面大 |
| #5 | Store 后台上下文 | ~2 天 | 逐个 Store |
| #14 | .id() 重建 | ~0.5 天 | 需改造分页逻辑 |
| #15 | onReceive 管理 | ~0.3 天 | 可选优化 |
| #16 | 刷新防抖 | ~0.2 天 | 加状态锁 |
| #17 | 缓存大小 | ~0.1 天 | 调参数 |
