import SwiftUI

/// 统一错误状态展示组件，替代各 View 中散落的 errorView 实现。
///
/// 提供一致的图标、消息文本和可选的重试按钮。
struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView(
            "加载失败",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .symbolVariant(.fill)
        .overlay(alignment: .bottom) {
            if let retryAction {
                Button(String(localized: "重试"), action: retryAction)
                    .buttonStyle(.bordered)
                    .offset(y: -16)
            }
        }
    }
}

#Preview("带重试") {
    ErrorStateView(
        message: "网络连接失败，请检查网络设置",
        retryAction: { print("重试") }
    )
    .frame(height: 300)
}

#Preview("只读") {
    ErrorStateView(
        message: "该内容不存在或已被删除"
    )
    .frame(height: 300)
}
