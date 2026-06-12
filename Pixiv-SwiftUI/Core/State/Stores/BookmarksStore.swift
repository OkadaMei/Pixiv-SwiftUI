import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class BookmarksStore {
    var bookmarks: [Illusts] = []
    var isLoadingBookmarks = false
    var error: AppError?
    var bookmarkRestrict: String = "public"

    var nextUrlBookmarks: String?
    private var loadingNextUrl: String?
    private var currentFetchTask: Task<Void, Never>?

    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol
    private let authSession: AuthSessionProtocol
    private let settings: AppSettingsProtocol

    private let expiration: CacheExpiration = .minutes(5)

    init(
        authSession: AuthSessionProtocol = AccountStore.shared,
        settings: AppSettingsProtocol = UserSettingStore.shared,
        cache: CacheStorageProtocol = CacheManager.shared
    ) {
        self.authSession = authSession
        self.settings = settings
        self.cache = cache
    }

    func cancelCurrentFetch() {
        Logger.bookmark.debug("取消当前请求")
        currentFetchTask?.cancel()
        currentFetchTask = nil
        isLoadingBookmarks = false
    }

    func fetchBookmarks(userId: String, forceRefresh: Bool = false) async {
        let capturedRestrict = self.bookmarkRestrict
        let cacheKey = CacheManager.bookmarksKey(userId: userId, restrict: capturedRestrict)

        Logger.bookmark.debug("fetchBookmarks: restrict=\(capturedRestrict, privacy: .public), userId=\(userId, privacy: .public), forceRefresh=\(forceRefresh)")

        if !forceRefresh {
            if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                Logger.bookmark.debug("从缓存加载: key=\(cacheKey, privacy: .public), count=\(cached.0.count)")
                self.bookmarks = cached.0
                self.nextUrlBookmarks = cached.1
                return
            }
        }

        guard !isLoadingBookmarks else {
            Logger.bookmark.debug("跳过: 已在加载中")
            return
        }

        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            Logger.bookmark.debug("开始网络请求: restrict=\(capturedRestrict, privacy: .public)")
            let (illusts, nextUrl) = try await api.userAPI.getUserBookmarksIllusts(userId: userId, restrict: capturedRestrict)

            guard capturedRestrict == self.bookmarkRestrict else {
                Logger.bookmark.debug("丢弃结果: restrict已改变, captured=\(capturedRestrict, privacy: .public), current=\(self.bookmarkRestrict, privacy: .public)")
                return
            }

            Logger.bookmark.info("请求完成: restrict=\(capturedRestrict, privacy: .public), count=\(illusts.count)")
            self.bookmarks = illusts
            self.nextUrlBookmarks = nextUrl
            cache.set((illusts, nextUrl), forKey: cacheKey, expiration: expiration)

            await syncToBookmarkCache(illusts: illusts, userId: userId, restrict: capturedRestrict)
        } catch {
            self.error = AppError.unknown(error)
            Logger.bookmark.error("Failed to fetch bookmarks: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshBookmarks(userId: String) async {
        await fetchBookmarks(userId: userId, forceRefresh: true)
    }

    func loadMoreBookmarks() async {
        guard let nextUrl = nextUrlBookmarks, !isLoadingBookmarks else { return }
        if nextUrl == loadingNextUrl { return }

        loadingNextUrl = nextUrl
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            let response: IllustsResponseDTO = try await api.fetchNext(urlString: nextUrl)
            self.bookmarks.append(contentsOf: response.illusts.map { $0.toDomain() })
            self.nextUrlBookmarks = response.nextUrl
            loadingNextUrl = nil

            await syncToBookmarkCache(illusts: response.illusts.map { $0.toDomain() }, userId: authSession.currentUserId, restrict: bookmarkRestrict)
        } catch {
            self.error = AppError.unknown(error)
            Logger.bookmark.error("Failed to load more bookmarks: \(error.localizedDescription, privacy: .public)")
            loadingNextUrl = nil
        }
    }

    private func syncToBookmarkCache(illusts: [Illusts], userId: String, restrict: String) async {
        guard settings.bookmarkCacheEnabled else { return }

        await MainActor.run {
            BookmarkCacheStore.shared.batchAddOrUpdateCache(
                illusts: illusts,
                ownerId: userId,
                bookmarkRestrict: restrict
            )
        }
    }
}
