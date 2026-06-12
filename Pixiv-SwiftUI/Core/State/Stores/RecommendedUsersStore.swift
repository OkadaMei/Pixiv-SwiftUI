import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class RecommendedUsersStore {
    var users: [UserPreviews] = []
    var isLoading = false
    var nextUrl: String?
    var error: AppError?

    private var loadingNextUrl: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)
    private let cacheKey = "recommended_users_list"

    var hasCachedUsers: Bool {
        !users.isEmpty
    }

    func fetchUsers(forceRefresh: Bool = false) async {
        if !forceRefresh {
            if hasCachedUsers && cache.isValid(forKey: cacheKey) {
                return
            }

            if let cached: ([UserPreviews], String?) = cache.get(forKey: cacheKey) {
                self.users = cached.0
                self.nextUrl = cached.1
                return
            }
        }

        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let (users, nextUrl) = try await api.userAPI.getRecommendedUsers()
            self.users = users
            self.nextUrl = nextUrl
            cache.set((users, nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to fetch recommended users: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshUsers() async {
        await fetchUsers(forceRefresh: true)
    }

    func loadMoreUsers() async {
        guard let nextUrl = nextUrl, !isLoading else { return }
        if nextUrl == loadingNextUrl { return }

        loadingNextUrl = nextUrl
        isLoading = true
        defer { isLoading = false }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            self.users.append(contentsOf: response.userPreviews)
            self.nextUrl = response.nextUrl
            loadingNextUrl = nil
        } catch {
            Logger.user.error("Failed to load more recommended users: \(error.localizedDescription, privacy: .public)")
            loadingNextUrl = nil
        }
    }
}
