import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    /// 缓存过滤结果，避免每次 body 重求值时全量重跑 O(n) filterIllusts()
    @State private var filteredIllusts: [Illusts] = []
    /// 预计算 shouldBlur 字典（key: illust.id），避免在 body 求值路径中
    /// 反复 O(n) 搜索 filteredIllusts
    @State private var shouldBlurMap: [Int: Bool] = [:]
    @State private var isLoading = true
    @State private var nextUrl: String?
    @State private var hasMoreData = true
    @State private var error: String?

    @State private var recommendedUsers: [UserPreviews] = []
    @State private var isLoadingRecommended = false
    @State private var hasCachedUsers = false
    @State private var isInitialLoadInProgress = false

    @State private var contentType: TypeFilterButton.ContentType = .illust

    @Environment(UserSettingStore.self) var settingStore
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager

    @State private var searchStore = SearchStore.shared

    /// 预取进度追踪器（引用类型，避免 @State 触发不必要的视图重绘）
    @State private var prefetchTracker = PrefetchTracker()

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)
    private let usersCacheKey = "recommend_users_0"

    /// 重新计算 filteredIllusts + shouldBlurMap 缓存
    private func recalculateFilteredIllusts() {
        let base = settingStore.filterIllusts(illusts)
        switch contentType {
        case .all, .manga:
            filteredIllusts = base
        case .illust:
            filteredIllusts = base.filter { $0.type != "manga" }
        }
        // Dictionary 提供 O(1) 查询，比数组线性搜索快得多
        shouldBlurMap = Dictionary(
            uniqueKeysWithValues: filteredIllusts.map {
                ($0.id, settingStore.userSetting.shouldBlurIllust($0))
            }
        )
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private var cacheKey: String {
        let typeSuffix = contentType == .manga ? "_manga" : "_illust"
        return isLoggedIn ? "recommend\(typeSuffix)_0" : "walkthrough\(typeSuffix)_0"
    }

    private func mainList(containerWidth: CGFloat) -> some View {
        let dynamicColumnCount = ResponsiveGrid.columnCount(for: containerWidth, userSetting: settingStore.userSetting)
        let horizontalPadding: CGFloat = 24
        let availableWidth = containerWidth - horizontalPadding
        let waterfallWidth = availableWidth > 0 ? availableWidth : nil

        return ScrollView {
            VStack(spacing: 0) {
                if !isLoggedIn {
                    LoginBannerView(onLogin: {
                        showAuthView = true
                    })
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                if isLoggedIn {
                    RecommendedArtistsList(
                        recommendedUsers: $recommendedUsers,
                        isLoadingRecommended: $isLoadingRecommended,
                        onRefresh: loadRecommendedUsers
                    )

                    Spacer()
                        .frame(height: 16)

                    if accountStore.isWebLoggedIn {
                        RecommendTagGroupList(
                            tagGroups: searchStore.recommendByTagGroups,
                            isLoading: searchStore.isLoadingRecommendedTags
                        )
                    }

                    Spacer()
                        .frame(height: 8)
                }

                HStack {
                    Text(contentType == .manga ? String(localized: "漫画") : (isLoggedIn ? String(localized: "插画") : String(localized: "热门")))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if filteredIllusts.isEmpty && isLoading {
                    SkeletonIllustWaterfallGrid(
                        columnCount: dynamicColumnCount,
                        itemCount: skeletonItemCount,
                        width: waterfallWidth
                    )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 400)
                    .transition(.opacity)
                } else if filteredIllusts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(String(localized: "没有加载到推荐内容"))
                            .foregroundColor(.gray)
                        Button(action: loadMoreData) {
                            Text(String(localized: "重新加载"))
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                        IllustCard(
                            illust: illust,
                            columnCount: dynamicColumnCount,
                            columnWidth: columnWidth,
                            expiration: DefaultCacheExpiration.recommend,
                            feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                            shouldBlur: shouldBlur(for: illust),
                            accentColor: themeManager.currentColor
                        )
                        .equatable()
                        .onTapGesture {
                            path.append(illust)
                        }
                        .onAppear {
                            prefetchIfNeeded(from: illust)
                        }
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity)

                    if hasMoreData && !isLoading {
                        LazyVStack {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                                .padding()
                                .id(nextUrl)
                                .onAppear {
                                    loadMoreData()
            }
            .onFilterSettingsChange(from: settingStore, perform: recalculateFilteredIllusts)
        }                    } else if !filteredIllusts.isEmpty {
                        Text(String(localized: "已经到底了"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .refreshable {
            await refreshAll()
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    mainList(containerWidth: proxy.size.width)
                    errorView
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            .navigationTitle(String(localized: "推荐"))
            .toolbar {
                ToolbarItem {
                    TypeFilterButton(
                        selectedType: $contentType,
                        restrict: nil,
                        selectedRestrict: .constant(nil as TypeFilterButton.RestrictType?),
                        showAll: false,
                        cacheFilter: .constant(nil)
                    )
                    .menuIndicator(.hidden)
                }
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                ToolbarItem {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
                .hideSharedBackgroundIfAvailable()
                #endif
                #if os(macOS)
                ToolbarItem {
                    RefreshButton(refreshAction: { await refreshAll() })
                }
                #endif
            }
            .pixivNavigationDestinations()
            .onAppear {
                loadCachedData()
                loadCachedUsers()

                if illusts.isEmpty {
                    guard !isInitialLoadInProgress else { return }
                    isInitialLoadInProgress = true
                    Task {
                        defer { isInitialLoadInProgress = false }

                        if isLoggedIn {
                            _ = await (loadRecommendedUsersAsync(), refreshIllusts(forceRefresh: false))
                            if accountStore.isWebLoggedIn {
                                await searchStore.fetchRecommendedTags()
                            }
                        } else {
                            await refreshIllusts(forceRefresh: false)
                        }
                    }
                } else {
                    if isLoggedIn {
                        loadRecommendedUsers()
                        if accountStore.isWebLoggedIn, searchStore.recommendByTagGroups.isEmpty {
                            Task {
                                await searchStore.fetchRecommendedTags()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
            .onChange(of: accountStore.navigationRequest) { _, newValue in
                if let request = newValue {
                    switch request {
                    case .userDetail(let userId):
                        path.append(User(id: .string(userId), name: "", account: ""))
                    case .illustDetail(let illust):
                        path.append(illust)
                    }
                    accountStore.navigationRequest = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
                Task {
                    await refreshAll()
                }
            }
            .onChange(of: accountStore.currentUserId) { _, _ in
                Task {
                    illusts = []
                    recalculateFilteredIllusts()
                    nextUrl = nil
                    hasMoreData = true
                    recommendedUsers = []
                    hasCachedUsers = false
                    isLoadingRecommended = true
                    if accountStore.isLoggedIn {
                        _ = await (refreshIllusts(), refreshRecommendedUsers())
                        if accountStore.isWebLoggedIn {
                            await searchStore.fetchRecommendedTags(forceRefresh: true)
                        }
                    } else {
                        await refreshIllusts()
                    }
                }
            }
            .onChange(of: contentType) { _, _ in
                Task {
                    illusts = []
                    recalculateFilteredIllusts()
                    nextUrl = nil
                    hasMoreData = true
                    await refreshIllusts(forceRefresh: false)
                }
            }
        }
    }

    private var errorView: some View {
        Group {
            if let error = error {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)

                    Button(action: loadMoreData) {
                        Text("重试")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
        }
    }

    private func loadCachedData() {
        if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
            illusts = cached.0
            recalculateFilteredIllusts()
            nextUrl = cached.1
            hasMoreData = cached.1 != nil
            isLoading = false
        } else {
            isLoading = true
        }
    }

    /// 从预计算的 shouldBlurMap 中查找对应 illust 的模糊标志（O(1) 查询）
    private func shouldBlur(for illust: Illusts) -> Bool {
        shouldBlurMap[illust.id] ?? false
    }

    /// 卡片出现时预取后续图片，保持始终领先视口约 6 张
    private func prefetchIfNeeded(from currentIllust: Illusts) {
        prefetchIllustsIfNeeded(
            from: currentIllust,
            in: filteredIllusts,
            quality: settingStore.userSetting.feedPreviewQuality,
            tracker: prefetchTracker
        )
    }

    private func loadCachedUsers() {
        if let cached: [UserPreviews] = cache.get(forKey: usersCacheKey) {
            recommendedUsers = cached
            hasCachedUsers = true
        }
    }

    private func loadMoreData() {
        guard !isLoading, hasMoreData else { return }

        isLoading = true
        error = nil

        Task {
            do {
                let result: (illusts: [Illusts], nextUrl: String?)
                if let next = nextUrl {
                    if isLoggedIn {
                        result = try await PixivAPI.shared.getIllustsByURL(next)
                    } else {
                        result = try await WalkthroughAPI().getWalkthroughIllustsByURL(next)
                    }
                } else {
                    if contentType == .manga {
                        if isLoggedIn {
                            result = try await PixivAPI.shared.getRecommendedManga()
                        } else {
                            result = try await PixivAPI.shared.getRecommendedMangaNoLogin()
                        }
                    } else {
                        if isLoggedIn {
                            result = try await PixivAPI.shared.getRecommendedIllusts()
                        } else {
                            result = try await WalkthroughAPI().getWalkthroughIllusts()
                        }
                    }
                }

                await MainActor.run {
                    let newIllusts = result.illusts.filter { new in
                        !self.illusts.contains(where: { $0.id == new.id })
                    }

                    if newIllusts.isEmpty && result.nextUrl != nil {
                        self.nextUrl = result.nextUrl
                        self.isLoading = false
                        loadMoreData()
                    } else {
                        self.illusts.append(contentsOf: newIllusts)
                        recalculateFilteredIllusts()
                        self.nextUrl = result.nextUrl
                        self.hasMoreData = result.nextUrl != nil
                        self.isLoading = false
                        cache.set((illusts, result.nextUrl), forKey: cacheKey, expiration: expiration)

                        // 重置预取跟踪（新数据已追加，后续 onAppear 会接上）
                        prefetchTracker.prefetchedUpToIndex = 0
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func loadMoreDataAsync() async {
        guard !isLoading, hasMoreData else { return }

        isLoading = true
        error = nil

        do {
            let result: (illusts: [Illusts], nextUrl: String?)
            if let next = nextUrl {
                if isLoggedIn {
                    result = try await PixivAPI.shared.getIllustsByURL(next)
                } else {
                    result = try await WalkthroughAPI().getWalkthroughIllustsByURL(next)
                }
            } else {
                if contentType == .manga {
                    if isLoggedIn {
                        result = try await PixivAPI.shared.getRecommendedManga()
                    } else {
                        result = try await PixivAPI.shared.getRecommendedMangaNoLogin()
                    }
                } else {
                    if isLoggedIn {
                        result = try await PixivAPI.shared.getRecommendedIllusts()
                    } else {
                        result = try await WalkthroughAPI().getWalkthroughIllusts()
                    }
                }
            }

            let newIllusts = result.illusts.filter { new in
                !self.illusts.contains(where: { $0.id == new.id })
            }

            if newIllusts.isEmpty && result.nextUrl != nil {
                self.nextUrl = result.nextUrl
                self.isLoading = false
                await loadMoreDataAsync()
            } else {
                self.illusts.append(contentsOf: newIllusts)
                recalculateFilteredIllusts()
                self.nextUrl = result.nextUrl
                self.hasMoreData = result.nextUrl != nil
                self.isLoading = false
                cache.set((illusts, result.nextUrl), forKey: cacheKey, expiration: expiration)
            }
        } catch {
            self.error = "加载失败: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func refreshIllusts(forceRefresh: Bool = true) async {
        isLoading = true
        error = nil

        do {
            let result: (illusts: [Illusts], nextUrl: String?)

            if !forceRefresh {
                if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                    await MainActor.run {
                        illusts = cached.0
                        recalculateFilteredIllusts()
                        nextUrl = cached.1
                        hasMoreData = cached.1 != nil
                        isLoading = false
                    }
                    return
                }
            }

            if contentType == .manga {
                if isLoggedIn {
                    result = try await PixivAPI.shared.getRecommendedManga()
                } else {
                    result = try await PixivAPI.shared.getRecommendedMangaNoLogin()
                }
            } else {
                if isLoggedIn {
                    result = try await PixivAPI.shared.getRecommendedIllusts()
                } else {
                    result = try await WalkthroughAPI().getWalkthroughIllusts()
                }
            }

            await MainActor.run {
                illusts = result.illusts
                recalculateFilteredIllusts()
                nextUrl = result.nextUrl
                hasMoreData = result.nextUrl != nil
                isLoading = false
                prefetchTracker.prefetchedUpToIndex = 0

                cache.set((illusts, result.nextUrl), forKey: cacheKey, expiration: expiration)

                // 预取下一页的图片（跳过当前可见区域）
                ImageURLHelper.prefetchImages(from: illusts, quality: settingStore.userSetting.feedPreviewQuality, offset: 6)
            }
        } catch {
            await MainActor.run {
                self.error = "刷新失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func loadRecommendedUsers() {
        guard !isLoadingRecommended, !hasCachedUsers else { return }

        isLoadingRecommended = true

        Task {
            do {
                let (users, _) = try await PixivAPI.shared.getRecommendedUsers()

                await MainActor.run {
                    recommendedUsers = users
                    isLoadingRecommended = false
                    hasCachedUsers = true

                    cache.set(users, forKey: usersCacheKey, expiration: expiration)
                }
            } catch {
                await MainActor.run {
                    isLoadingRecommended = false
                }
            }
        }
    }

    private func loadRecommendedUsersAsync() async {
        guard !isLoadingRecommended, !hasCachedUsers else { return }

        isLoadingRecommended = true

        do {
            let (users, _) = try await PixivAPI.shared.getRecommendedUsers()
            recommendedUsers = users
            isLoadingRecommended = false
            hasCachedUsers = true
            cache.set(users, forKey: usersCacheKey, expiration: expiration)
        } catch {
            isLoadingRecommended = false
        }
    }

    private func refreshRecommendedUsers() async {
        isLoadingRecommended = true

        do {
            let (users, _) = try await PixivAPI.shared.getRecommendedUsers()

            await MainActor.run {
                recommendedUsers = users
                isLoadingRecommended = false

                cache.set(users, forKey: usersCacheKey, expiration: expiration)
            }
} catch {
                await MainActor.run {
                    isLoadingRecommended = false
                }
            }
    }

    private func refreshAll() async {
        if isLoggedIn {
            _ = await (refreshIllusts(), refreshRecommendedUsers())
            if accountStore.isWebLoggedIn {
                await searchStore.fetchRecommendedTags(forceRefresh: true)
            }
        } else {
            _ = await refreshIllusts()
        }
    }
}

/// 登录引导横幅（嵌入在推荐页顶部）
struct LoginBannerView: View {
    let onLogin: () -> Void
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.clock")
                .font(.title2)
                .foregroundStyle(themeManager.currentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "游客模式"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(localized: "登录以保存收藏、关注画师"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "登录")) {
                onLogin()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    RecommendView()
}
