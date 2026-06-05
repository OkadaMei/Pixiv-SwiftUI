import SwiftUI
import Kingfisher
import TranslationKit
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(\.colorScheme) private var colorScheme
    let illust: Illusts
    @State private var illustStore = IllustStore()
    @State private var currentPage = 0
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @State private var showCopyToast = false
    @State private var showBlockTagToast = false
    @State private var showBlockIllustToast = false
    @State private var showBlockUserToast = false
    @State private var isFollowLoading = false
    @State private var relatedIllusts: [Illusts] = []
    @State private var isLoadingRelated = false
    @State private var isFetchingMoreRelated = false
    @State private var relatedNextUrl: String?
    @State private var hasMoreRelated = true
    @State private var relatedIllustError: String?
    @State private var navigateToIllust: Illusts?
    @State private var showRelatedIllustDetail = false
    #if os(macOS)
    @State private var currentImageAspectRatio: CGFloat = 0
    @AppStorage("macos_illust_detail_left_width") private var leftColumnWidth: Double = 0
    #endif
    @State private var isFollowed: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var isBlockTriggered: Bool = false
    @State private var totalComments: Int?
    @State private var navigateToUserId: String?
    @State private var navigateToIllustId: Int?
    @State private var navigateToNovelId: Int?
    @State private var shouldLoadRelated: Bool = false
    @State private var showSaveToast = false
    @State private var showAuthView = false
    @State private var showNotLoggedInToast = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showDeleteSuccessToast = false
    @State private var showDeleteErrorToast = false
    @State private var detailFetched = false

    private var screenWidth: CGFloat {
        #if os(iOS)
        return UIScreen.main.bounds.width
        #elseif os(macOS)
        return NSScreen.main?.frame.width ?? 0
        #else
        return 0
        #endif
    }
    @State private var isSaving = false
    @State private var pendingSaveURL: URL?
    @State private var navigateToDownloadTasks = false
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    // MARK: - Fullscreen Transition State
    @State private var capturedImageFrame: CGRect = .zero
    @State private var transitionPhase: TransitionPhase = .idle
    @State private var transitionProgress: CGFloat = 0
    @State private var transitionScreenSize: CGSize = .zero
    /// Frame saved at entering start — preserved for correct exit animation
    @State private var savedSourceFrame: CGRect = .zero
    @State private var exitDragProgress: CGFloat = 0

    /// Opacity of the detail page content during transitions.
    private var detailContentOpacity: Double {
        guard transitionPhase.isFullscreen || transitionPhase.isTransitioning else { return 1.0 }
        if transitionPhase.isTransitioning {
            switch transitionPhase {
            case .entering:
                return 0.1
            case .exiting:
                return 0.1 + Double(transitionProgress) * 0.9
            default:
                return 0.1
            }
        }
        return 0.1
    }

    private let cache = CacheManager.shared
    private let commentsExpiration: CacheExpiration = .minutes(10)

    init(illust: Illusts) {
        self.illust = illust
        _isFollowed = State(initialValue: illust.user.isFollowed ?? false)
        _isBookmarked = State(initialValue: illust.isBookmarked)
        _totalComments = State(initialValue: illust.totalComments)
    }

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var isUgoira: Bool {
        illust.type == "ugoira"
    }

    private var isManga: Bool {
        illust.type == "manga"
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var isOwnIllust: Bool {
        illust.user.id.stringValue == accountStore.currentUserId
    }

    private var detailImageQuality: Int {
        isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
    }

    private var zoomImageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    private var zoomImageAspectRatios: [CGFloat] {
        // 由于 MetaPages 中通常不包含单独的宽高信息（通常所有页宽高一致或需单独获取）
        // 这里暂时使用原图的比例作为所有页的初始比例
        if !illust.metaPages.isEmpty {
            return Array(repeating: illust.safeAspectRatio, count: illust.metaPages.count)
        }
        return [illust.safeAspectRatio]
    }

    /// Detail-quality image URLs for each page (used as fallback in fullscreen viewer)
    private var detailImageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                #if os(macOS)
                let totalWidth = proxy.size.width
                let dividerWidth: CGFloat = 8
                let minLeftWidth: CGFloat = 250
                let minRightWidth: CGFloat = 250
                let availableWidth = max(0, totalWidth - dividerWidth)
                let defaultLeftWidth = availableWidth * 0.6

                let storedLeftWidth: CGFloat? = leftColumnWidth > 0 ? CGFloat(leftColumnWidth) : nil
                let rawLeftWidth = storedLeftWidth ?? defaultLeftWidth
                let currentLeftWidth = max(minLeftWidth, min(rawLeftWidth, availableWidth - minRightWidth))
                let currentRightWidth = max(minRightWidth, availableWidth - currentLeftWidth)

                HStack(spacing: 0) {
                    // Left Column: Image and Related
                    ScrollView {
                        VStack(spacing: 0) {
                            IllustDetailImageSection(
                                illust: illust,
                                userSettingStore: userSettingStore,
                                isFullscreen: $isFullscreen,
                                animation: animation,
                                currentPage: $currentPage,
                                containerWidth: currentLeftWidth,
                                minContainerHeight: proxy.size.height * 0.6,
                                currentAspectRatio: $currentImageAspectRatio,
                                disableAspectRatioAnimation: true
                            )

                            IllustDetailRelatedSection(
                                illustId: illust.id,
                                isLoggedIn: isLoggedIn,
                                relatedIllusts: $relatedIllusts,
                                isLoadingRelated: $isLoadingRelated,
                                isFetchingMoreRelated: $isFetchingMoreRelated,
                                relatedNextUrl: $relatedNextUrl,
                                hasMoreRelated: $hasMoreRelated,
                                relatedIllustError: $relatedIllustError,
                                width: currentLeftWidth
                            )
                            .padding(.trailing, 16)
                        }
                        .frame(width: currentLeftWidth)
                    }
                    .frame(width: currentLeftWidth)
                    .clipped()

                    // Draggable Divider
                    Color.clear
                        .frame(width: dividerWidth)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        )
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                #if os(macOS)
                                NSCursor.resizeLeftRight.push()
                                #endif
                            } else {
                                #if os(macOS)
                                NSCursor.pop()
                                #endif
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newWidth = currentLeftWidth + value.translation.width
                                    if newWidth > minLeftWidth && newWidth < availableWidth - minRightWidth {
                                        leftColumnWidth = Double(newWidth)
                                    }
                                }
                        )

                    // Right Column: Info and Comments
                    ScrollView {
                        VStack(spacing: 0) {
                            IllustDetailInfoSection(
                                illust: illust,
                                userSettingStore: userSettingStore,
                                accountStore: accountStore,
                                colorScheme: colorScheme,
                                isFollowed: $isFollowed,
                                isBookmarked: $isBookmarked,
                                totalComments: $totalComments,
                                showNotLoggedInToast: $showNotLoggedInToast,
                                showCopyToast: $showCopyToast,
                                showBlockTagToast: $showBlockTagToast,
                                isBlockTriggered: $isBlockTriggered,
                                isCommentsPanelPresented: $isCommentsPanelPresented,
                                navigateToUserId: $navigateToUserId
                            )
                            .padding()

                            Divider()
                                .padding(.horizontal)

                            CommentsPanelInlineView(
                                illust: illust,
                                onUserTapped: { userId in
                                    navigateToUserId = userId
                                },
                                hasInternalScroll: false
                            )
                            .padding()
                        }
                    }
                    .frame(width: currentRightWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        IllustDetailImageSection(
                            illust: illust,
                            userSettingStore: userSettingStore,
                            isFullscreen: $isFullscreen,
                            animation: animation,
                            currentPage: $currentPage
                        )
                        .frame(maxWidth: proxy.size.width)

                        IllustDetailInfoSection(
                            illust: illust,
                            userSettingStore: userSettingStore,
                            accountStore: accountStore,
                            colorScheme: colorScheme,
                            isFollowed: $isFollowed,
                            isBookmarked: $isBookmarked,
                            totalComments: $totalComments,
                            showNotLoggedInToast: $showNotLoggedInToast,
                            showCopyToast: $showCopyToast,
                            showBlockTagToast: $showBlockTagToast,
                            isBlockTriggered: $isBlockTriggered,
                            isCommentsPanelPresented: $isCommentsPanelPresented,
                            navigateToUserId: $navigateToUserId
                        )
                        .padding()
                        .frame(maxWidth: proxy.size.width)

                        IllustDetailRelatedSection(
                            illustId: illust.id,
                            isLoggedIn: isLoggedIn,
                            relatedIllusts: $relatedIllusts,
                            isLoadingRelated: $isLoadingRelated,
                            isFetchingMoreRelated: $isFetchingMoreRelated,
                            relatedNextUrl: $relatedNextUrl,
                            hasMoreRelated: $hasMoreRelated,
                            relatedIllustError: $relatedIllustError,
                            width: proxy.size.width
                        )
                        .padding(.trailing, 16)
                    }
                }
                .scrollDisabled(isFullscreen || transitionPhase.isTransitioning)
                .opacity(detailContentOpacity)
                #endif
            }
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .sheet(isPresented: $isCommentsPanelPresented) {
                IllustCommentsPanelView(
                    illust: illust,
                    isPresented: $isCommentsPanelPresented,
                    onUserTapped: { userId in
                        isCommentsPanelPresented = false
                        navigateToUserId = userId
                    }
                )
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { copyToClipboard(String(illust.id)) }) {
                            Label(String(localized: "复制 ID"), systemImage: "doc.on.doc")
                        }

                        if let shareURL = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") {
                            ShareLink(item: shareURL) {
                                Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                            }
                        }

                        if isLoggedIn {
                            Button(action: {
                                if isBookmarked {
                                    bookmarkIllust(forceUnbookmark: true)
                                } else {
                                    bookmarkIllust(isPrivate: userSettingStore.userSetting.defaultPrivateLike)
                                }
                            }) {
                                Label(
                                    isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"),
                                    systemImage: isBookmarked ? (illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill") : "heart"
                                )
                            }

                            Divider()

                            #if os(iOS)
                            Button(action: {
                                Task {
                                    await saveIllust()
                                }
                            }) {
                                Label(String(localized: "保存到相册"), systemImage: "photo.on.rectangle")
                            }
                            #else
                            Button(action: {
                                Task {
                                    await showSavePanel()
                                }
                            }) {
                                Label(String(localized: "保存…"), systemImage: "square.and.arrow.down")
                            }
                            #endif

                            if userSettingStore.userSetting.illustDetailSaveSkipLongPress {
                                Button(action: {
                                    Task {
                                        await saveIllust()
                                    }
                                }) {
                                    Label(String(localized: "快速保存"), systemImage: "bolt.fill")
                                }
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                isBlockTriggered = true
                                try? userSettingStore.addBlockedIllustWithInfo(
                                    illust.id,
                                    title: illust.title,
                                    authorId: illust.user.id.stringValue,
                                    authorName: illust.user.name,
                                    thumbnailUrl: illust.imageUrls.squareMedium
                                )
                                showBlockIllustToast = true
                                dismiss()
                            }) {
                                Label(String(localized: "屏蔽此作品"), systemImage: "eye.slash")
                            }
                            .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)

                            Button(role: .destructive, action: {
                                isBlockTriggered = true
                                try? userSettingStore.addBlockedUserWithInfo(
                                    illust.user.id.stringValue,
                                    name: illust.user.name,
                                    account: illust.user.account,
                                    avatarUrl: illust.user.profileImageUrls?.medium
                                )
                                showBlockUserToast = true
                                dismiss()
                            }) {
                                Label(String(localized: "屏蔽此作者"), systemImage: "person.slash")
                            }
                            .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)

                            if isOwnIllust {
                                Divider()

                                Button(role: .destructive, action: {
                                    showDeleteConfirmation = true
                                }) {
                                    Label(String(localized: "删除作品"), systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuIndicator(.hidden)
                }
            }
            .onAppear {
                fetchDetailIfNeeded()
                Task {
                    try? illustStore.recordGlance(illust.id, illust: illust)
                }
            }
            .onPreferenceChange(ImageFramePreferenceKey.self) { frame in
                if frame != .zero {
                    capturedImageFrame = frame
                }
            }
            .onChange(of: isFullscreen) { _, newValue in
                if newValue {
                    startEnteringTransition()
                } else {
                    startExitingTransition()
                }
            }
            .navigationTitle(illust.title)
            #if os(iOS)
            .toolbar(isFullscreen || transitionPhase.isTransitioning ? .hidden : .visible, for: .navigationBar)
            .toolbar(isFullscreen || transitionPhase.isTransitioning ? .hidden : .visible, for: .tabBar)
            #endif

            #if os(iOS)
            transitionOverlay()
            #endif
        }
        .navigationDestination(item: $navigateToUserId) { userId in
            UserDetailView(userId: userId)
        }
        .navigationDestination(item: $navigateToIllustId) { illustId in
            IllustLoaderView(illustId: illustId)
        }
        .navigationDestination(item: $navigateToNovelId) { novelId in
            NovelLoaderView(novelId: novelId)
        }
        .environment(\.openURL, OpenURLAction { url in
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if url.scheme == "pixiv" {
                     let pathId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                     if components.host == "illusts", let id = Int(pathId) {
                         navigateToIllustId = id
                         return .handled
                     } else if components.host == "users" {
                         navigateToUserId = pathId
                         return .handled
                       } else if components.host == "novel" || components.host == "novels", let id = Int(pathId) {
                          navigateToNovelId = id
                          return .handled
                      }
                } else if url.host?.contains("pixiv.net") == true {
                     // Simple handling for common pixiv web links
                     let pathComponents = components.path.split(separator: "/")
                     if pathComponents.count >= 2 {
                         if pathComponents[0] == "artworks", let id = Int(pathComponents[1]) {
                             navigateToIllustId = id
                             return .handled
                         } else if pathComponents[0] == "users" {
                             navigateToUserId = String(pathComponents[1])
                             return .handled
                         }
                     }
                     if components.path.contains("novel/show.php"),
                        let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
                        let id = Int(idStr) {
                         navigateToNovelId = id
                         return .handled
                     }
                }
            }
            return .systemAction
        })
        .toast(isPresented: $showCopyToast, message: String(localized: "已复制"))
        .toast(isPresented: $showBlockTagToast, message: String(localized: "已屏蔽 Tag"))
        .toast(isPresented: $showBlockIllustToast, message: String(localized: "已屏蔽作品"))
        .toast(isPresented: $showBlockUserToast, message: String(localized: "已屏蔽作者"))
        .toast(isPresented: $showSaveToast, message: String(localized: "已添加到下载队列"))
        .toast(isPresented: $showDeleteSuccessToast, message: String(localized: "作品已删除"))
        .toast(isPresented: $showDeleteErrorToast, message: String(localized: "删除失败"))
        .alert(String(localized: "确认删除"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "取消"), role: .cancel) { }
            Button(String(localized: "删除"), role: .destructive) {
                Task {
                    await deleteIllust()
                }
            }
            .disabled(isDeleting)
        } message: {
            Text(String(localized: "删除后将无法恢复，确定要删除这个作品吗？"))
        }
        .navigationDestination(isPresented: $navigateToDownloadTasks) {
            DownloadTasksView()
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore)
        }
        .toast(isPresented: $showNotLoggedInToast, message: String(localized: "请先登录"), duration: 2.0)
    }

    private func preloadAllImages() {
        guard isMultiPage else { return }

        Task {
            await withTaskGroup(of: Void.self) { group in
                let urls: [String]
                if !illust.metaPages.isEmpty {
                    urls = illust.metaPages.indices.compactMap { index in
                        ImageURLHelper.getPageImageURL(from: illust, page: index, quality: detailImageQuality)
                    }
                } else {
                    urls = [ImageURLHelper.getImageURL(from: illust, quality: detailImageQuality)]
                }

                for urlString in urls {
                    group.addTask {
                        await self.preloadImage(urlString: urlString)
                    }
                }
            }
        }
    }

    private func preloadImage(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let source: Source
        if shouldUseDirectConnection(url: url) {
            source = .directNetwork(url)
        } else {
            source = .network(url)
        }

        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage
        ]

        _ = try? await KingfisherManager.shared.retrieveImage(with: source, options: options)
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showNotLoggedInToast = true
            return
        }

        let wasBookmarked = isBookmarked
        let illustId = illust.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            isBookmarked = true
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    await syncBookmarkCacheRemoval(illustId: illustId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    await syncBookmarkCacheUpdate(restrict: isPrivate ? "private" : "public")
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    await syncBookmarkCacheAdd(restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        illust.isBookmarked = true
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = isPrivate ? "private" : "public"
                    } else if wasBookmarked {
                        illust.bookmarkRestrict = isPrivate ? "public" : "private"
                    } else {
                        isBookmarked = false
                        illust.isBookmarked = false
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
                    }
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        showCopyToast = true
    }

    private func saveIllust() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await saveUgoira()
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality)
        }
        showSaveToast = true
    }

    private func saveUgoira() async {
        print("[IllustDetailView] 开始保存动图: \(illust.id)")
        await DownloadStore.shared.addUgoiraTask(illust)
    }

    #if os(macOS)
    private func showSavePanel() async {
        if !isUgoira && illust.pageCount > 1 {
            // 多图插画：由于沙盒限制，需要选择文件夹而不是具体文件
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.title = "选择保存目录"
            panel.prompt = "保存到此目录"

            let result = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }

            guard result == .OK, let url = panel.url else { return }
            await performSave(to: url)
        } else {
            // 单图或动图：使用 NSSavePanel 选择具体文件名
            let panel = NSSavePanel()
            let safeTitle = ImageSaver.sanitizeFilename(illust.title)
            let safeAuthor = ImageSaver.sanitizeFilename(illust.user.name)

            if isUgoira {
                panel.allowedContentTypes = [.gif]
                panel.nameFieldStringValue = "\(safeAuthor)_\(safeTitle).gif"
                panel.title = "保存动图"
            } else {
                let quality = userSettingStore.userSetting.downloadQuality
                let firstUrl = ImageURLHelper.getImageURL(from: illust, quality: quality)
                let ext = (firstUrl as NSString).pathExtension.lowercased()

                if ext == "png" {
                    panel.allowedContentTypes = [.png, .jpeg]
                    panel.nameFieldStringValue = "\(safeAuthor)_\(safeTitle).png"
                } else {
                    panel.allowedContentTypes = [.jpeg, .png]
                    panel.nameFieldStringValue = "\(safeAuthor)_\(safeTitle).jpg"
                }
                panel.title = "保存插画"
            }

            let result = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }

            guard result == .OK, let url = panel.url else { return }
            await performSave(to: url)
        }
    }

    private func performSave(to url: URL) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await DownloadStore.shared.addUgoiraTask(illust, customSaveURL: url)
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality, customSaveURL: url)
        }
        showSaveToast = true
    }
    #endif

    /// 从 API 获取完整详情，更新 illust 的 metaPages/metaSinglePage 等数据
    /// Pixiv 列表接口返回的数据可能不完整（如 caption 为空、metaPages 缺少 original URL），
    /// 需要像 Pixez 一样始终调用 /v1/illust/detail 获取完整数据
    private func fetchDetailIfNeeded() {
        guard !detailFetched else { return }
        detailFetched = true

        // 先从缓存取 totalComments
        let cacheKey = CacheManager.illustDetailKey(illustId: illust.id)
        if let cached: Illusts = cache.get(forKey: cacheKey), let comments = cached.totalComments, comments > 0 {
            totalComments = comments
        }

        // 先用当前数据预加载
        preloadAllImages()

        Task {
            do {
                let detail = try await PixivAPI.shared.getIllustDetail(illustId: illust.id)
                await MainActor.run {
                    if let comments = detail.totalComments {
                        self.totalComments = comments
                    }
                    // 用详情接口的完整数据更新 illust
                    if !detail.metaPages.isEmpty {
                        illust.metaPages = detail.metaPages
                    }
                    if let singlePage = detail.metaSinglePage {
                        illust.metaSinglePage = singlePage
                    }
                    if !detail.imageUrls.large.isEmpty {
                        illust.imageUrls = detail.imageUrls
                    }
                    if illust.caption.isEmpty, !detail.caption.isEmpty {
                        illust.caption = detail.caption
                    }

                    // 数据更新后重新预加载正确质量的图片
                    preloadAllImages()
                }
            } catch {
                print("[fetchDetail] FAILED: \(error)")
            }
        }
    }

    private func deleteIllust() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let type = isManga ? "manga" : "illust"
            try await PixivAPI.shared.deleteIllust(illustId: illust.id, type: type)

            await MainActor.run {
                showDeleteSuccessToast = true
                dismiss()
            }
        } catch {
            await MainActor.run {
                showDeleteErrorToast = true
            }
        }
    }

    // MARK: - Bookmark Cache Sync

    private func syncBookmarkCacheAdd(restrict: String) async {
        guard UserSettingStore.shared.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.addOrUpdateCache(
                illust: illust,
                ownerId: AccountStore.shared.currentUserId,
                bookmarkRestrict: restrict
            )
        }

        if UserSettingStore.shared.userSetting.bookmarkAutoPreload {
            let settings = UserSettingStore.shared.userSetting
            let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
            let allPages = settings.bookmarkCacheAllPages
            let urls = illust.getImageURLs(quality: quality, allPages: allPages)
            try? await BookmarkCacheService.shared.preloadImages(urls: urls)
            await MainActor.run {
                BookmarkCacheStore.shared.updatePreloadStatus(
                    illustId: illust.id,
                    ownerId: AccountStore.shared.currentUserId,
                    preloaded: true,
                    quality: quality,
                    allPages: allPages
                )
            }
        }
    }

    // MARK: - Fullscreen Transition Helpers

    /// Detail-quality image URL for the current illust/page (used for entering ghost image).
    private var enteringTransitionImageURL: String {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty, currentPage < illust.metaPages.count {
            return ImageURLHelper.getPageImageURL(from: illust, page: currentPage, quality: quality) ?? ""
        }
        return ImageURLHelper.getImageURL(from: illust, quality: quality)
    }

    /// Zoom-quality image URL for the current illust/page (used for exiting ghost image,
    /// since FullscreenImageView has already cached it).
    private var exitingTransitionImageURL: String {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty, currentPage < illust.metaPages.count {
            return ImageURLHelper.getPageImageURL(from: illust, page: currentPage, quality: quality) ?? ""
        }
        return ImageURLHelper.getImageURL(from: illust, quality: quality)
    }

    /// The aspect ratio of the current illust/page to use during transition.
    private var transitionAspectRatio: CGFloat {
        illust.safeAspectRatio
    }

    /// Begin the entering (detail → fullscreen) transition.
    private func startEnteringTransition() {
        let frame = capturedImageFrame

        // Save immediately for correct exit animation (toolbar re-appearance shifts layout)
        savedSourceFrame = frame

        // If frame hasn't been captured yet, retry on next runloop
        guard frame != .zero, frame.width > 0, frame.height > 0 else {
            DispatchQueue.main.async {
                let retryFrame = capturedImageFrame
                guard retryFrame != .zero, retryFrame.width > 0, retryFrame.height > 0 else {
                    transitionPhase = .fullscreen
                    return
                }
                startEnteringTransitionWithFrame(retryFrame)
            }
            return
        }

        startEnteringTransitionWithFrame(frame)
    }

    private func startEnteringTransitionWithFrame(_ frame: CGRect) {
        let url = enteringTransitionImageURL
        guard !url.isEmpty else {
            transitionPhase = .fullscreen
            return
        }

        // Reset exit drag state from any previous dismissal
        exitDragProgress = 0

        let aspectRatio = transitionAspectRatio
        transitionProgress = 0
        transitionPhase = .entering(sourceFrame: frame, imageURL: url, aspectRatio: aspectRatio)

        // Capture screen size for stable target frame calculation
        #if os(iOS)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let windowSize = windowScene?.windows.first?.bounds.size ?? .zero
        transitionScreenSize = windowSize
        #endif

        // Preload the zoom-quality images for FullscreenImageView and the exit transition.
        // 注意：这是进入全屏后的后台预加载，不需要优先任何页面。
        for zoomURL in zoomImageURLs {
            Task { await preloadImage(urlString: zoomURL) }
        }

        // Animate the ghost image and switch to .fullscreen when the spring settles.
        // 必须在下一个 runloop 执行动画，让 SwiftUI 先渲染 .entering 的初始状态。
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                transitionProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [isFullscreen] in
            guard isFullscreen else { return }
            transitionPhase = .fullscreen
        }
    }

    /// Begin the exiting (fullscreen → detail) transition.
    private func startExitingTransition() {
        // 使用进入时保存的 frame（toolbar 可见时的布局），而不是全屏期间的 capturedImageFrame
        //（toolbar 隐藏时的布局），确保退场幽灵图片直接飞向详情页图片的最终位置。
        let exitFrame = savedSourceFrame

        guard exitFrame != .zero else {
            transitionPhase = .idle
            return
        }

        let url = exitingTransitionImageURL
        let aspectRatio = transitionAspectRatio

        transitionProgress = 0
        transitionPhase = .exiting(sourceFrame: exitFrame, imageURL: url, aspectRatio: aspectRatio)

        // Capture screen size for stable target frame calculation
        #if os(iOS)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let windowSize = windowScene?.windows.first?.bounds.size ?? .zero
        transitionScreenSize = windowSize
        #endif

        // Animate the ghost back and switch to .idle when the spring settles.
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                transitionProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            transitionPhase = .idle
        }
    }

    /// Compute the target fullscreen frame for a given aspect ratio and screen size.
    private func targetFrame(in screenSize: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard aspectRatio > 0, aspectRatio.isFinite else {
            return CGRect(origin: .zero, size: screenSize)
        }

        let screenW = screenSize.width
        let screenH = screenSize.height

        let imageH = screenW / aspectRatio
        if imageH <= screenH {
            let yOffset = (screenH - imageH) / 2
            return CGRect(x: 0, y: yOffset, width: screenW, height: imageH)
        } else {
            let imageW = screenH * aspectRatio
            let xOffset = (screenW - imageW) / 2
            return CGRect(x: xOffset, y: 0, width: imageW, height: screenH)
        }
    }

    // MARK: - Interpolation Helpers

    private func interpolatedX(from source: CGRect, to target: CGRect) -> CGFloat {
        source.midX + (target.midX - source.midX) * transitionProgress
    }

    private func interpolatedY(from source: CGRect, to target: CGRect) -> CGFloat {
        source.midY + (target.midY - source.midY) * transitionProgress
    }

    private func interpolatedWidth(from source: CGRect, to target: CGRect) -> CGFloat {
        source.width + (target.width - source.width) * transitionProgress
    }

    private func interpolatedHeight(from source: CGRect, to target: CGRect) -> CGFloat {
        source.height + (target.height - source.height) * transitionProgress
    }

    // MARK: - Transition Overlay

    /// The iOS-only fullscreen transition overlay (ghost + pre-warmed FullscreenImageView).
    /// Extracted as a function to help the Swift compiler type-check the body.
    @ViewBuilder
    private func transitionOverlay() -> some View {
        ZStack {
            // Persistent black background to prevent white flash during phase switches
            if transitionPhase != .idle {
                Color.black
                    .ignoresSafeArea()
            }

            // Ghost image for entering/exiting phases
            switch transitionPhase {
            case .entering(let sourceFrame, let imageURL, let aspectRatio):
                enteringGhostView(sourceFrame: sourceFrame, imageURL: imageURL, aspectRatio: aspectRatio)
                    .zIndex(2)

            case .exiting(let sourceFrame, let imageURL, let aspectRatio):
                exitingGhostView(sourceFrame: sourceFrame, imageURL: imageURL, aspectRatio: aspectRatio)
                    .zIndex(2)

            case .fullscreen, .idle:
                EmptyView()
            }

            // Pre-warmed FullscreenImageView — mounted during .entering to give
            // glassEffect and image loading a head start.
            // 始终保持 opacity 1，使玻璃效果从挂载起就正常捕获背景。
            // 幽灵图（zIndex 2）的纯黑背景会完全遮盖它，用户不会看到。
            if transitionPhase.isEnteringOrFullscreen {
                FullscreenImageView(
                    imageURLs: zoomImageURLs,
                    fallbackImageURLs: detailImageURLs,
                    aspectRatios: zoomImageAspectRatios,
                    initialPage: $currentPage,
                    isPresented: $isFullscreen,
                    exitDragProgress: $exitDragProgress,
                    animation: animation
                )
                .zIndex(1)
            }        }
    }

    // MARK: - Ghost View Builders

    @ViewBuilder
    private func enteringGhostView(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat) -> some View {
        GeometryReader { overlayGeo in
            let origin = overlayGeo.frame(in: .global).origin
            let localSource = CGRect(
                origin: CGPoint(x: sourceFrame.origin.x - origin.x,
                               y: sourceFrame.origin.y - origin.y),
                size: sourceFrame.size
            )
            let localTarget = targetFrame(in: overlayGeo.size, aspectRatio: aspectRatio)
            ZStack {
                // 始终不透明，遮盖下方的 FullscreenImageView（含玻璃按钮）
                // 使玻璃效果有充足时间捕获背景并完成初始化。
                Color.black
                    .ignoresSafeArea()

                KingfisherGhostImage(
                    urlString: imageURL,
                    aspectRatio: aspectRatio
                )
                .frame(
                    width: interpolatedWidth(from: localSource, to: localTarget),
                    height: interpolatedHeight(from: localSource, to: localTarget)
                )
                .position(
                    x: interpolatedX(from: localSource, to: localTarget),
                    y: interpolatedY(from: localSource, to: localTarget)
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func exitingGhostView(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat) -> some View {
        GeometryReader { overlayGeo in
            let origin = overlayGeo.frame(in: .global).origin
            let localSource = CGRect(
                origin: CGPoint(x: sourceFrame.origin.x - origin.x,
                               y: sourceFrame.origin.y - origin.y),
                size: sourceFrame.size
            )
            let localTarget = targetFrame(in: overlayGeo.size, aspectRatio: aspectRatio)
            // 调整起始 frame 以匹配用户拖拽关闭时的位置和缩放
            let adjustedStart = CGRect(
                x: localTarget.origin.x,
                y: localTarget.origin.y + exitDragProgress * overlayGeo.size.height,
                width: localTarget.width * (1.0 - exitDragProgress * 0.3),
                height: localTarget.height * (1.0 - exitDragProgress * 0.3)
            )
            ZStack {
                // 始终不透明，遮盖 FullscreenImageView
                Color.black
                    .ignoresSafeArea()

                KingfisherGhostImage(
                    urlString: imageURL,
                    fallbackURLString: enteringTransitionImageURL,
                    aspectRatio: aspectRatio
                )
                .frame(
                    width: interpolatedWidth(from: adjustedStart, to: localSource),
                    height: interpolatedHeight(from: adjustedStart, to: localSource)
                )
                .position(
                    x: interpolatedX(from: adjustedStart, to: localSource),
                    y: interpolatedY(from: adjustedStart, to: localSource)
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private func syncBookmarkCacheUpdate(restrict: String) async {
        guard UserSettingStore.shared.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.addOrUpdateCache(
                illust: illust,
                ownerId: AccountStore.shared.currentUserId,
                bookmarkRestrict: restrict
            )
        }
    }

    private func syncBookmarkCacheRemoval(illustId: Int) async {
        guard UserSettingStore.shared.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.removeCache(
                illustId: illustId,
                ownerId: AccountStore.shared.currentUserId
            )
        }
    }
}
