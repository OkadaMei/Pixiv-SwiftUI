import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// 插画卡片组件
struct IllustCard: View, Equatable {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let illust: Illusts
    let columnCount: Int
    var columnWidth: CGFloat?
    var expiration: CacheExpiration?
    var showsBookmarkCount: Bool
    let feedPreviewQuality: Int
    let shouldBlur: Bool
    let accentColor: Color

    /// Equatable：Illusts 是类，按 id 比较；expiration 非 Equatable，跳过（极少变化）。
    static func == (lhs: IllustCard, rhs: IllustCard) -> Bool {
        lhs.illust.id == rhs.illust.id &&
        lhs.columnCount == rhs.columnCount &&
        lhs.columnWidth == rhs.columnWidth &&
        lhs.showsBookmarkCount == rhs.showsBookmarkCount &&
        lhs.feedPreviewQuality == rhs.feedPreviewQuality &&
        lhs.shouldBlur == rhs.shouldBlur &&
        lhs.accentColor == rhs.accentColor
    }

    init(
        illust: Illusts,
        columnCount: Int = 2,
        columnWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        showsBookmarkCount: Bool = false,
        feedPreviewQuality: Int = 0,
        shouldBlur: Bool = false,
        accentColor: Color = .accentColor
    ) {
        self.illust = illust
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.expiration = expiration
        self.showsBookmarkCount = showsBookmarkCount
        self.feedPreviewQuality = feedPreviewQuality
        self.shouldBlur = shouldBlur
        self.accentColor = accentColor
    }

    private var isR18: Bool {
        return illust.xRestrict == 1
    }

    private var isR18G: Bool {
        return illust.xRestrict == 2
    }

    private var isSpoiler: Bool {
        return illust.isSpoiler
    }

    /// 获取收藏图标，根据收藏状态和类型返回不同的图标
    private var bookmarkIconName: String {
        if !illust.isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    private var isUgoira: Bool {
        return illust.type == "ugoira"
    }

    private var isManga: Bool {
        return illust.type == "manga"
    }

    /// 条件化 blur：仅需要模糊时附加 blur 修饰符，避免 radius=0 时的无效渲染开销
    @ViewBuilder
    private var thumbnailImage: some View {
        let image = CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: feedPreviewQuality),
            aspectRatio: illust.safeAspectRatio,
            idealWidth: columnWidth,
            expiration: expiration
        )
        if shouldBlur {
            image.blur(radius: 20)
        } else {
            image
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .clipped()

                HStack(spacing: 4) {
                    if isManga {
                        Text("漫画")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    if isUgoira {
                        Text("动图")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    if isAI {
                        Text("AI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if illust.pageCount > 1 {
                    Text("\(illust.pageCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(6)
                }

                if showsBookmarkCount {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text(NumberFormatter.formatCount(illust.totalBookmarks))
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(illust.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)

                    Text(illust.user.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if illust.isBookmarked {
                        toggleBookmark(forceUnbookmark: true)
                    } else {
                        toggleBookmark(isPrivate: UserSettingStore.shared.userSetting.defaultPrivateLike)
                    }
                } label: {
                    Image(systemName: bookmarkIconName)
                        .foregroundColor(illust.isBookmarked ? accentColor : .secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: illust.isBookmarked)
            }
            .padding(8)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .frame(width: columnWidth)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        .contextMenu {
            #if os(macOS)
            Button {
                openWindow(id: "illust-detail", value: illust.id)
            } label: {
                Label("在新窗口中打开", systemImage: "arrow.up.right.square")
            }

            Divider()
            #endif

            if illust.isBookmarked {
                if illust.bookmarkRestrict == "private" {
                    Button {
                        toggleBookmark(isPrivate: false)
                    } label: {
                        Label("切换为公开收藏", systemImage: "heart")
                    }
                } else {
                    Button {
                        toggleBookmark(isPrivate: true)
                    } label: {
                        Label("切换为非公开收藏", systemImage: "heart.slash")
                    }
                }
                Button(role: .destructive) {
                    toggleBookmark(forceUnbookmark: true)
                } label: {
                    Label("取消收藏", systemImage: "heart.slash")
                }
            } else {
                Button {
                    toggleBookmark(isPrivate: false)
                } label: {
                    Label("公开收藏", systemImage: "heart")
                }
                Button {
                    toggleBookmark(isPrivate: true)
                } label: {
                    Label("非公开收藏", systemImage: "heart.slash")
                }
            }

            Divider()

            Section("屏蔽") {
                Button(role: .destructive) {
                    try? UserSettingStore.shared.addBlockedIllustWithInfo(
                        illust.id,
                        title: illust.title,
                        authorId: illust.user.id.stringValue,
                        authorName: illust.user.name,
                        thumbnailUrl: illust.imageUrls.squareMedium
                    )
                } label: {
                    Label("屏蔽此作品", systemImage: "eye.slash")
                }

                Button(role: .destructive) {
                    try? UserSettingStore.shared.addBlockedUserWithInfo(
                        illust.user.id.stringValue,
                        name: illust.user.name,
                        account: illust.user.account,
                        avatarUrl: illust.user.profileImageUrls?.medium
                    )
                } label: {
                    Label("屏蔽此作者", systemImage: "person.slash")
                }

                Menu {
                    ForEach(illust.tags, id: \.name) { tag in
                        Button {
                            try? UserSettingStore.shared.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                        } label: {
                            Text(tag.translatedName ?? tag.name)
                        }
                    }
                } label: {
                    Label("屏蔽此标签", systemImage: "tag.slash")
                }
            }
        }
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        let wasBookmarked = illust.isBookmarked
        let illustId = illust.id
        let originalTotalBookmarks = illust.totalBookmarks
        let originalBookmarkRestrict = illust.bookmarkRestrict

        if forceUnbookmark && wasBookmarked {
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        await MainActor.run {
                            BookmarkCacheStore.shared.removeCache(
                                illustId: illustId,
                                ownerId: AccountStore.shared.currentUserId
                            )
                        }
                    }
                } else if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        await MainActor.run {
                            BookmarkCacheStore.shared.addOrUpdateCache(
                                illust: illust,
                                ownerId: AccountStore.shared.currentUserId,
                                bookmarkRestrict: isPrivate ? "private" : "public"
                            )
                        }
                    }
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        await MainActor.run {
                            BookmarkCacheStore.shared.addOrUpdateCache(
                                illust: illust,
                                ownerId: AccountStore.shared.currentUserId,
                                bookmarkRestrict: isPrivate ? "private" : "public"
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
                                    illustId: illustId,
                                    ownerId: AccountStore.shared.currentUserId,
                                    preloaded: true,
                                    quality: quality,
                                    allPages: allPages
                                )
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    illust.isBookmarked = wasBookmarked
                    illust.totalBookmarks = originalTotalBookmarks
                    illust.bookmarkRestrict = originalBookmarkRestrict
                }
            }
        }
    }
}

#Preview {
    let illust = Illusts(
        id: 123,
        title: "示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium:
                "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium:
                "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large:
                "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "示例作品",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16:
                    "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50:
                    "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170:
                    "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 1,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 1000,
        totalBookmarks: 500,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2, showsBookmarkCount: true)
        .padding()
        .frame(width: 390)
}

#Preview("多页插画") {
    let illust = Illusts(
        id: 124,
        title: "多页示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium:
                "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium:
                "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large:
                "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "多页示例",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16:
                    "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50:
                    "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170:
                    "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 5,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 2000,
        totalBookmarks: 800,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2, showsBookmarkCount: true)
        .padding()
        .frame(width: 390)
}
