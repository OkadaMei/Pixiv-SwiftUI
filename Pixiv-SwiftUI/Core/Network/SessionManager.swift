import Foundation
import CryptoKit
import os.log

/// 管理 App API 认证会话和 HTTP Headers
///
/// 职责：
/// - 持有当前 accessToken 对应的 auth headers
/// - 构建 X-Client-Time / X-Client-Hash 等固定头
/// - 提供 setAccessToken / clearAccessToken 接口
/// - Token 刷新（含自动重试防重入）
@MainActor
final class SessionManager {
    static let shared = SessionManager()

    private init() {}

    private let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

    // MARK: - Token & Headers

    /// 当前缓存的认证请求头。`nil` 表示未登录。
    private(set) var authHeaders: [String: String]?

    /// 当前 accessToken（从 authHeaders 中提取的便捷属性）
    var currentAccessToken: String? {
        authHeaders?["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
    }

    /// 设置访问令牌并生成对应的认证请求头
    func setAccessToken(_ token: String) {
        authHeaders = buildAuthHeaders(for: token)
    }

    /// 清除认证信息（登出时调用）
    func clearAccessToken() {
        authHeaders = nil
    }

    /// 根据当前 accessToken 构建请求头的便捷方法（用于 fetchNext 等场景）
    func buildHeaders(for token: String) -> [String: String] {
        buildAuthHeaders(for: token)
    }

    // MARK: - Token 刷新

    private var isRefreshing = false
    private var refreshTask: Task<Void, Error>?

    /// 刷新 token（如果需要）。
    /// 支持防重入：多个并发请求同时发现 token 过期时，只有第一个会触发刷新，其余等待结果。
    func refreshTokenIfNeeded() async throws {
        if isRefreshing {
            if let task = refreshTask {
                try await task.value
            }
            return
        }

        guard let refreshToken = AccountStore.shared.currentAccount?.refreshToken else {
            Logger.token.debug("无 refreshToken，无法刷新")
            notifyTokenRefreshFailed(message: "无登录凭证，请重新登录")
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        refreshTask = Task {
            let authAPI = AuthAPI()
            do {
                let (newAccessToken, newRefreshToken, _, expiresIn) = try await authAPI.refreshAccessToken(refreshToken)

                if let currentAccount = AccountStore.shared.currentAccount {
                    currentAccount.accessToken = newAccessToken
                    currentAccount.refreshToken = newRefreshToken
                    try AccountStore.shared.updateAccount(currentAccount, expiresIn: expiresIn)
                }

                self.setAccessToken(newAccessToken)
                PixivAPI.shared.setAccessToken(newAccessToken)

                Logger.token.debug("Token 刷新成功，已更新本地存储")
            } catch {
                Logger.token.error("Token 刷新失败: \(error.localizedDescription)")
                AccountStore.shared.tokenRefreshErrorMessage = error.localizedDescription
                AccountStore.shared.showTokenRefreshFailedToast = true
                throw error
            }
        }

        try await refreshTask?.value
    }

    private func notifyTokenRefreshFailed(message: String) {
        AccountStore.shared.tokenRefreshErrorMessage = message
        AccountStore.shared.showTokenRefreshFailedToast = true
    }

    // MARK: - Private

    private var baseHeaders: [String: String] {
        var headers = [String: String]()
        let time = getIsoDate()
        headers["X-Client-Time"] = time
        headers["X-Client-Hash"] = getHash(time + hashSalt)
        headers["App-OS"] = "ios"
        headers["App-OS-Version"] = "14.6"
        headers["App-Version"] = "7.13.3"
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let acceptLanguage = (langCode == "zh" || langCode.hasPrefix("zh-")) ? "zh-CN" : "en-US"
        headers["Accept-Language"] = acceptLanguage
        return headers
    }

    private func buildAuthHeaders(for token: String) -> [String: String] {
        var headers = baseHeaders
        headers["Authorization"] = "Bearer \(token)"
        headers["Accept"] = "application/json"
        headers["Content-Type"] = "application/json"
        return headers
    }

    private func getIsoDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    private func getHash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
