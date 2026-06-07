import SwiftUI

extension View {
    /// 卡片标签样式：圆角矩形背景 + caption2 粗体字
    ///
    /// 使用 `.background(style:in:)` 替代 `.background() + .cornerRadius()` 组合，
    /// 直接绘制圆角矩形填充，避免 cornerRadius 产生的 offscreen mask pass。
    @ViewBuilder
    func badgeStyle() -> some View {
        font(.caption2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                }
            }
    }
}
