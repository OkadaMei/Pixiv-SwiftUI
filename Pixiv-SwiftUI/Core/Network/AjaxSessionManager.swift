import Foundation

/// 管理 Ajax API 的 Cookie 和 CSRF Token 会话
///
/// 职责：
/// - 持有 PHPSESSID / yuidB 等 Cookie 状态
/// - 管理 AjaxAPI 实例生命周期
/// - 提供 CSRF Token 的获取 / 校验
@MainActor
final class AjaxSessionManager {
    static let shared = AjaxSessionManager()

    private init() {}

    // MARK: - 内部状态

    private struct SessionCookies {
        var phpSessId: String?
        var yuidB: String?
        var pAbDId: String?
        var pAbId: String?
        var pAbId2: String?
    }

    private var currentCookies = SessionCookies()
    private var isSessionReady = false

    // MARK: - Public

    /// 当前 Ajax API 实例。在设置 Cookie 时创建。
    private(set) var ajaxAPI: AjaxAPI?

    /// 初始化 Ajax 会话（附带当前 Cookies）
    /// 每次调用都会创建全新的 AjaxAPI 实例（清除旧 CSRF Token）
    func initializeSession() {
        ajaxAPI = AjaxAPI()
        applyCookies()
        isSessionReady = false
    }

    /// 设置 Ajax Web 会话（PHPSESSID）
    func setPHPSESSID(_ phpsessid: String?) {
        setSessionCookies(
            phpSessId: phpsessid,
            yuidB: currentCookies.yuidB,
            pAbDId: currentCookies.pAbDId,
            pAbId: currentCookies.pAbId,
            pAbId2: currentCookies.pAbId2
        )
    }

    /// 设置 Ajax 会话完整的 Cookie 组
    func setSessionCookies(
        phpSessId: String?,
        yuidB: String?,
        pAbDId: String?,
        pAbId: String?,
        pAbId2: String?
    ) {
        currentCookies.phpSessId = normalizeCookieValue(phpSessId)
        currentCookies.yuidB = normalizeCookieValue(yuidB)
        currentCookies.pAbDId = normalizeCookieValue(pAbDId)
        currentCookies.pAbId = normalizeCookieValue(pAbId)
        currentCookies.pAbId2 = normalizeCookieValue(pAbId2)

        // 仅当 ajaxAPI 尚未创建时才创建，保留已有 CSRF Token
        // （需要完全重建的场景由 initializeSession 处理）
        if ajaxAPI == nil {
            ajaxAPI = AjaxAPI()
        }

        applyCookies()
        isSessionReady = false
    }

    /// 确保 Ajax 会话就绪（获取 CSRF Token）
    func setupSession() async throws {
        if isSessionReady { return }
        guard let ajax = ajaxAPI else { throw NetworkError.invalidResponse }
        try await ajax.refreshCSRFToken()
        isSessionReady = true
    }

    /// 校验当前 Ajax 会话是否为登录态
    func validateSession() async -> Bool {
        guard let ajax = ajaxAPI else { return false }
        do {
            try await ajax.refreshCSRFToken()
        } catch {
            return false
        }
        return await ajax.validateSession()
    }

    /// 清除所有会话状态（登出时调用）
    func clearSession() {
        currentCookies = SessionCookies()
        ajaxAPI = nil
        isSessionReady = false
    }

    // MARK: - Private

    private func applyCookies() {
        ajaxAPI?.setSessionCookies(
            phpSessId: currentCookies.phpSessId,
            yuidB: currentCookies.yuidB,
            pAbDId: currentCookies.pAbDId,
            pAbId: currentCookies.pAbId,
            pAbId2: currentCookies.pAbId2
        )
    }

    private func normalizeCookieValue(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            return normalized
        }
        return nil
    }
}
