import SwiftUI

extension View {
    /// 卡片标签样式：圆角矩形背景 + caption2 粗体字
    ///
    /// 使用 `.background(style:in:)` 形状材质背景 API，
    /// 直接绘制圆角矩形填充，避免 cornerRadius 产生的 offscreen mask pass。
    func badgeStyle() -> some View {
        self
            .font(.caption2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
