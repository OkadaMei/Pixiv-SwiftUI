# A-5 View 层瘦身重构方案

> 创建日期: 2026-06-16
> 关联审计问题: CODE_AUDIT.md → A-5 View 层过重，业务逻辑内联
> 预估总工时: 10-14 天
> 最后更新: 2026-06-16（Phase 1 + Phase 6 已完成）

---

## 一、现状分析

审计报告指出 4 个「过重」的 View 文件，但经深入探查，实际问题范围更广：

| 文件 | 行数 | `@State` 数 | 核心问题 |
|------|------|:-----------:|----------|
| `IllustDetailView.swift` | 789 ✅ | **~10 UI** | ~~22 个 `@State`~~ → 已抽取至 `IllustDetailViewModel`（378 行） |
| `SearchResultView.swift` | 872 | **10+** | 搜索过滤/排序/分页逻辑全部内联，自定义 `SearchFilterState` 结构体 |
| `SearchView.swift` | 657 | **15** | SauceNAO 图片搜索完整流程（文件读取→安全作用域→编码→导航） |
| `RecommendView.swift` | 583 | **13** | 直接调用 `PixivAPI.shared` + `CacheManager.shared`，绕过 Store 层 |
| `IllustCard.swift` | 467 | 0 | 创建私有 `IllustStore()` 实例，内联书签切换逻辑 |
| `NovelDetailView.swift` | 444 ✅ | **~10 UI** | ~~15 个 `@State`~~ → 已抽取至 `NovelDetailViewModel`（189 行） |

**对比标杆**：`NovelReaderStore`（763 行）将所有业务逻辑收归 Store，View 仅 468 行且 `@State` 只有 6 个。

---

## 二、架构决策

### 2.1 统一模式：`@Observable` 类（Store / ViewModel）

项目已有 26 个 Store，只有 1 个 ViewModel（`DataExportViewModel`）。为保持一致性：

- **全局共享状态** → Store（如书签列表、用户设置），放在 `Core/State/Stores/`
- **Feature 局部状态** → ViewModel，放在对应 `Features/` 子目录下
- **View 只保留** `@Environment` 引用 + 1 个 Feature ViewModel 的 `@State`

命名规则：
- Store：`@MainActor @Observable final class XxxStore`，可含 `static let shared`
- ViewModel：`@MainActor @Observable final class XxxViewModel`，不含 shared

### 2.2 文件放置规则

```
Features/
├── Home/
│   ├── RecommendView.swift          # View（瘦身）
│   ├── RecommendViewModel.swift     # NEW — Feature 局部状态
│   └── ...
├── Search/
│   ├── SearchView.swift
│   ├── SearchViewModel.swift        # NEW — 搜索编排 + SauceNAO
│   ├── SearchResultView.swift
│   ├── SearchResultViewModel.swift  # NEW — 过滤/排序/分页
│   └── ...
├── General/
│   ├── IllustDetailView.swift
│   ├── IllustDetailViewModel.swift  # NEW — 详情页状态
│   └── ...
└── Novel/
    ├── NovelDetail/
    │   ├── NovelDetailView.swift
    │   └── NovelDetailViewModel.swift  # NEW
    └── ...
```

### 2.3 ViewModel 模板

遵循 `DataExportViewModel` 已有模式：

```swift
import Foundation
import Observation

@MainActor
@Observable
final class XxxViewModel {
    // MARK: - Observable State
    var isLoading = false
    var error: AppError?
    // ...

    // MARK: - Dependencies
    private let api: PixivAPI
    private let cache: CacheStorageProtocol

    init(
        api: PixivAPI = .shared,
        cache: CacheStorageProtocol = CacheManager.shared
    ) {
        self.api = api
        self.cache = cache
    }

    // MARK: - Actions
    func doSomething() async { ... }
}
```

---

## 三、逐文件重构计划

### ✅ Phase 1: `IllustDetailView` → + `IllustDetailViewModel`（已完成 2026-06-16）

**问题**：1128 行，22 个 `@State`，是全项目最重的 View。

**抽取到 `IllustDetailViewModel` 的内容**：

| 原 View 中的位置 | 抽取内容 | ViewModel 属性/方法 |
|-----------------|---------|-------------------|
| L20 `@State currentPage` | 多页图当前页 | `var currentPage: Int` |
| L23 `@State isFollowLoading` | 关注加载状态 | `var isFollowLoading: Bool` |
| L24-28 `@State relatedIllusts*` | 相关推荐完整分页 | `var relatedIllusts: [Illusts]`, `func loadRelated()`, `func loadMoreRelated()` |
| L36-37 `@State isFollowed/isBookmarked` | 书签/关注状态 | `var isFollowed: Bool`, `var isBookmarked: Bool`, `func toggleBookmark()`, `func toggleFollow()` |
| L38 `@State isBlockTriggered` | 屏蔽流程 | `func blockUser()` |
| L39 `@State totalComments` | 评论数 | `var totalComments: Int?` |
| L43 `@State shouldLoadRelated` | 相关推荐懒加载 | 内部逻辑 |
| L46-47 `@State showDeleteConfirmation/isDeleting` | 删除功能 | `func deleteIllust()` |
| L59-61 `@State isSaving/pendingSaveURL/navigateToDownloadTasks` | 下载保存 | `func saveImage()` |

**保留在 View 的**：
- `isCommentsPanelPresented`, `isFullscreen` — 纯 UI 状态
- `capturedImageFrame`, `transitionPhase`, `transitionProgress` 等 — 全屏转场动画状态（~8 个 `@State`）
- `@Namespace private var animation`
- 所有 `@Environment` 属性

**重构后 View 签名**：
```swift
struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ToastPresenter.self) var toast
    let illust: Illusts
    @State private var vm: IllustDetailViewModel
    // UI-only @State: currentPage, isFullscreen, isCommentsPanelPresented, 转场动画状态
}
```

**实际结果**：View 从 1128 行降至 **789 行**（-30%），ViewModel 新增 **378 行**。

---

### Phase 2: `SearchView` → + `SearchViewModel`

**问题**：SauceNAO 图片搜索完整流程（~80 行 async 文件操作 + 安全作用域资源管理）内联在 View 中。

**抽取到 `SearchViewModel` 的内容**：

| 原 View 中的位置 | 抽取内容 | ViewModel 属性/方法 |
|-----------------|---------|-------------------|
| L33-67 | 瀑布流列数/列高计算 | `func masonryColumns(for:) -> [MasonryColumn]` |
| L85-163 | SauceNAO 搜索完整流程 | `func startSauceNaoSearch()`, `func searchWithImageURL(_:)`, `func searchWithImageData(_:)` |
| L169-178 | 搜索词标准化 | `func performSearch()` |
| L180-200 | 搜索编排（添加历史 + 设置 store + 预加载 + 导航） | 内含在 `performSearch()` |
| L24-27 | `@State showSauceNaoOptions / isSearchingByImage` | ViewModel 属性 |

**不抽取的**：
- `@Environment` 依赖保留
- `.searchable` 修饰器保留在 View（SwiftUI 声明式 API）
- UI 布局逻辑保留

**预估**：View 从 657 行降至 ~450 行。

---

### Phase 3: `SearchResultView` → + `SearchResultViewModel`

**问题**：872 行，自定义 `SearchFilterState` 结构体 + 10 个 `@State` + 完整分页逻辑。

**抽取到 `SearchResultViewModel` 的内容**：

| 原 View 中的位置 | 抽取内容 | ViewModel 属性/方法 |
|-----------------|---------|-------------------|
| L4-21 | `SearchFilterState` 结构体 | 移入 ViewModel 作为内部类型 |
| L24-44 | `@State tabSelection, sortOption, filterState, prefetchTracker, shouldBlurFromCache` | 全部移入 VM |
| L46-89 | `filteredIllusts/filteredUsers/filteredNovels` 计算属性 | VM 计算属性 |
| L91-211 | `performIllustSearch()`, `loadMoreIllustResults()` 等 4 个分页方法 | VM 方法 |
| L220-240 | 自动加载 burst 逻辑 + 暂停标志 | VM 内部状态 |

**与 `SearchResultStore` 的职责划分**：
- `SearchResultStore`（已存在，1008 行）：管理全局搜索结果缓存、伪热门排序算法
- `SearchResultViewModel`（新建）：会话级过滤/排序状态 + 分页编排，持有当前搜索会话的所有 UI 相关状态

**预估**：View 从 872 行降至 ~550 行。

---

### Phase 4: `RecommendView` → + `RecommendViewModel`

**问题**：直接调用 `PixivAPI.shared` 和 `CacheManager.shared`，13 个 `@State`，自行管理缓存策略。

**抽取到 `RecommendViewModel` 的内容**：

| 原 View 中的位置 | 抽取内容 | ViewModel 属性/方法 |
|-----------------|---------|-------------------|
| L5-14 | `@State illusts, filteredIllusts, shouldBlurMap, isLoading, nextUrl, hasMoreData, error` | VM 全部属性 |
| L37-51 | `recalculateFilteredIllusts()` | VM 方法 |
| L65-68 | `cacheKey` 计算 | VM 内部 |
| L190-260 | `loadMoreData()`, `refreshAll()`, `prefetchIfNeeded()` | VM 方法 |
| L375-400 | `fetchData()` — 直接 API 调用 | **改为通过 IllustStore** 或 VM 内封装 |

**关键变更**：删除 View 对 `PixivAPI.shared` 的直接引用，改为 VM 内部依赖注入。

**预估**：View 从 583 行降至 ~350 行，`@State` 从 13 降至 ~3。

---

### Phase 5: `IllustCard` — 轻量化

**问题**：467 行，内部创建 `IllustStore()` 实例，书签切换逻辑内联。

**方案**：
1. **删除私有 `IllustStore` 创建**：书签切换通过闭包回调传递（`onBookmarkToggle: ((Illusts) -> Void)?`）
2. **或者**：通过 `@Environment` 获取父级 Store
3. 将 `isR18/isSpoiler/isAI` 等派生属性移至 `Illusts` 模型扩展或 `IllustCardViewModel`

**注意**：`IllustCard` 是全项目最常用的组件（39 个调用点），修改需确保接口兼容。

**预估**：View 从 467 行降至 ~350 行。

---

### ✅ Phase 6: `NovelDetailView` → + `NovelDetailViewModel`（已完成 2026-06-16）

**问题**：15 个 `@State`，4 个独立 `Task {}` 块。

**抽取到 `NovelDetailViewModel` 的内容**：

| 原 View 中的位置 | 抽取内容 | ViewModel 属性/方法 |
|-----------------|---------|-------------------|
| 书签状态 + 切换 | `var isBookmarked`, `func toggleBookmark()` |
| 关注状态 + 切换 | `var isFollowed`, `func toggleFollow()` |
| 屏蔽流程 | `func blockUser()` |
| EPUB 导出 | `func exportEPUB()` |
| 评论数 | `var totalComments: Int?` |

**实际结果**：View 从 593 行降至 **444 行**（-25%），ViewModel 新增 **189 行**。

---

## 四、执行顺序与优先级

```
Phase 1 ──► Phase 2 ──► Phase 3
   │                         │
   └──► Phase 4              └──► Phase 5
                                         │
                              Phase 6 ◄───┘
```

| Phase | 文件 | 新增文件 | 预估工时 | 风险 | 状态 |
|-------|------|---------|---------|------|------|
| **1** | `IllustDetailView` | `IllustDetailViewModel.swift` | 3-4 天 | 低 — 纯逻辑抽取，View 不改签名 | ✅ 已完成 |
| **2** | `SearchView` | `SearchViewModel.swift` | 1.5-2 天 | 中 — SauceNAO 流程涉及安全作用域资源 | 待实施 |
| **3** | `SearchResultView` | `SearchResultViewModel.swift` | 2-3 天 | 高 — 与已有 `SearchResultStore` 职责边界需仔细划分 | 待实施 |
| **4** | `RecommendView` | `RecommendViewModel.swift` | 2 天 | 中 — 需消除对 `PixivAPI.shared` 的直接引用 | 待实施 |
| **5** | `IllustCard` | 无（修改现有） | 0.5 天 | 低 — 但影响 39 个调用点，需全量回归 | 待实施 |
| **6** | `NovelDetailView` | `NovelDetailViewModel.swift` | 1-1.5 天 | 低 — 标准抽取 | ✅ 已完成 |

---

## 五、PR 拆分策略

建议分 3 个 PR 提交，降低每次变更的审查负担：

| PR | 包含 Phase | 预估工时 | 说明 | 状态 |
|----|-----------|---------|------|------|
| **PR 1** | 1 + 6 | 4-5.5 天 | 详情页重构（IllustDetail + NovelDetail） | ✅ 已完成 |
| **PR 2** | 2 + 3 | 3.5-5 天 | 搜索模块重构（SearchView + SearchResultView） | 待实施 |
| **PR 3** | 4 + 5 | 2.5 天 | 首页 + 卡片组件重构（RecommendView + IllustCard） | 待实施 |

---

## 六、重构后目标状态

| 指标 | 重构前 | 重构后（Phase 1+6 完成） | 最终目标 |
|------|--------|------------------------|---------|
| View 最大行数 | 1128 (`IllustDetailView`) | **789** | ~550 |
| View 最大 `@State` 数 | 22 | **~10**（纯 UI/导航） | ≤ 8 |
| View 中的 `Task {}` 业务逻辑 | 8+ 处 | **0 处** | 0 处 |
| View 直接 API 调用 | 3 处 | **0 处** | 0 处 |
| View 直接 CacheManager 调用 | 1 处 | **0 处** | 0 处 |
| 新增 ViewModel 文件 | 0 | **2**（`IllustDetailVM`, `NovelDetailVM`） | 5 |
| 新增 ViewModel 文件 | 0 | 5（`IllustDetailVM`, `SearchVM`, `SearchResultVM`, `RecommendVM`, `NovelDetailVM`） |

---

## 七、验证方案

每个 Phase 完成后需通过：

1. **编译检查**
   ```bash
   # macOS
   xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug \
     -destination 'platform=macOS' build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"

   # iOS Simulator
   xcodebuild -project Pixiv-SwiftUI.xcodeproj -scheme Pixiv-SwiftUI -configuration Debug \
     -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
   ```

2. **代码规范**
   ```bash
   swiftlint lint
   ```

3. **手动回归测试清单**
   - [ ] 首页推荐刷新 / 无限滚动 / 内容类型切换
   - [ ] 搜索流程：文字搜索 + 历史记录 + 趋势标签 + 建议
   - [ ] SauceNAO 图片搜索（iOS + macOS）
   - [ ] 搜索结果：标签页切换 / 过滤 / 排序 / 日期范围
   - [x] 插画详情页：书签 / 关注 / 屏蔽 / 相关推荐 / 全屏
   - [x] 小说详情页：书签 / 关注 / EPUB 导出
   - [ ] IllustCard 在所有列表中的书签切换
