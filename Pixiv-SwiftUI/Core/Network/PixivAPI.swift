import Foundation

/// Pixiv API 服务 - 轻量协调器
///
/// 职责限于：
/// - 持有子 API 实例（SearchAPI, IllustAPI 等）
/// - 认证流程（login / refresh）
/// - Ajax 会话辅助
/// - 通用工具（fetchNext）
///
/// 子 API 的业务方法请直接访问其属性，例如：
///   PixivAPI.shared.illustAPI.getIllustDetail(illustId:)
@MainActor
final class PixivAPI {
    static let shared = PixivAPI()

    private let authAPI = AuthAPI()
    private let sessionManager = SessionManager.shared
    private let ajaxSessionManager = AjaxSessionManager.shared

    // MARK: - 子 API

    let searchAPI = SearchAPI()
    let illustAPI = IllustAPI()
    let userAPI = UserAPI()
    let bookmarkAPI = BookmarkAPI()
    let mangaAPI = MangaAPI()
    let novelAPI = NovelAPI()

    // MARK: - 会话管理

    /// 设置访问令牌并更新认证状态
    func setAccessToken(_ token: String) {
        authAPI.setAccessToken(token)
        sessionManager.setAccessToken(token)
        ajaxSessionManager.initializeSession()
    }

    /// 设置 Ajax Web 会话（PHPSESSID）
    func setAjaxPHPSESSID(_ phpsessid: String?) {
        ajaxSessionManager.setPHPSESSID(phpsessid)
    }

    /// 设置 Ajax Web 会话（完整 Cookie 组）
    func setAjaxSessionCookies(
        phpSessId: String?,
        yuidB: String?,
        pAbDId: String?,
        pAbId: String?,
        pAbId2: String?
    ) {
        ajaxSessionManager.setSessionCookies(
            phpSessId: phpSessId,
            yuidB: yuidB,
            pAbDId: pAbDId,
            pAbId: pAbId,
            pAbId2: pAbId2
        )
    }

    // MARK: - 认证相关

    /// 使用 code 登录
    func loginWithCode(_ code: String, codeVerifier: String) async throws -> (
        accessToken: String, refreshToken: String, user: User, expiresIn: Int
    ) {
        try await authAPI.loginWithCode(code, codeVerifier: codeVerifier)
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async throws -> (
        accessToken: String, user: User, expiresIn: Int
    ) {
        try await authAPI.loginWithRefreshToken(refreshToken)
    }

    /// 刷新 accessToken
    func refreshAccessToken(_ refreshToken: String) async throws -> (
        accessToken: String, refreshToken: String, user: User, expiresIn: Int
    ) {
        try await authAPI.refreshAccessToken(refreshToken)
    }

    // MARK: - Ajax API 辅助

    /// 初始化 Ajax API 会话（获取 CSRF Token）
    func setupAjaxSession() async throws {
        try await ajaxSessionManager.setupSession()
    }

    /// 获取搜索建议（Ajax）
    func getSearchSuggestion(mode: String = "all") async throws -> SearchSuggestionResponse {
        try await setupAjaxSession()
        guard let ajax = ajaxSessionManager.ajaxAPI else { throw NetworkError.invalidResponse }
        return try await ajax.getSearchSuggestion(mode: mode)
    }

    /// 校验当前 Ajax 会话是否为登录态
    func validateAjaxSession() async -> Bool {
        await ajaxSessionManager.validateSession()
    }

    // MARK: - 通用工具

    /// 获取下一页数据
    func fetchNext<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        let token = AccountStore.shared.currentAccount?.accessToken ?? ""
        let headers = SessionManager.shared.buildHeaders(for: token)

        return try await NetworkClient.shared.get(
            from: url,
            headers: headers,
            responseType: T.self
        )
    }
}
