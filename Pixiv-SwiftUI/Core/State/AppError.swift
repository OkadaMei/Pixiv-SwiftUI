import Foundation

/// 应用级别的错误类型
enum AppError: LocalizedError {
    case networkError(String)
    case databaseError(String)
    case decodingError(String)
    case authenticationError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .decodingError(let message):
            return "数据解析错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}
