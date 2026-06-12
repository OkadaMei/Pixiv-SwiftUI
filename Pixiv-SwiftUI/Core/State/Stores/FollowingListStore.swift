import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class FollowingListStore {
    var following: [UserPreviews] = []
    var isLoadingFollowing = false
    var error: AppError?

    var currentRestrict: String = "public"

    var nextUrlFollowing: String?

    private var loadingNextUrlFollowing: String?

    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)

    func fetchFollowing(userId: String, restrict: String? = nil, forceRefresh: Bool = false) async {
        let effectiveRestrict = restrict ?? currentRestrict

        let cacheKey = "user_following_\(userId)_\(effectiveRestrict)"

        if !forceRefresh, let cached: ([UserPreviews], String?) = cache.get(forKey: cacheKey) {
            self.following = cached.0
            self.nextUrlFollowing = cached.1
            return
        }

        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let (users, nextUrl) = try await api.userAPI.getUserFollowing(userId: userId, restrict: effectiveRestrict)
            self.following = users
            self.nextUrlFollowing = nextUrl
            cache.set((users, nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to fetch following: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshFollowing(userId: String, restrict: String? = nil) async {
        let effectiveRestrict = restrict ?? currentRestrict
        currentRestrict = effectiveRestrict
        await fetchFollowing(userId: userId, restrict: effectiveRestrict, forceRefresh: true)
    }

    func loadMoreFollowing() async {
        guard let nextUrl = nextUrlFollowing, !isLoadingFollowing else { return }
        if nextUrl == loadingNextUrlFollowing { return }

        loadingNextUrlFollowing = nextUrl
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            self.following.append(contentsOf: response.userPreviews)
            self.nextUrlFollowing = response.nextUrl
            loadingNextUrlFollowing = nil
        } catch {
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to load more following: \(error.localizedDescription, privacy: .public)")
            loadingNextUrlFollowing = nil
        }
    }
}
