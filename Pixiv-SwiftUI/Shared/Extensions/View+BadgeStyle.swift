import SwiftUI

extension View {
    /// 卡片标签样式：圆角矩形背景 + caption2 粗体字
    ///
    /// 使用 `.glassEffect` 直接应用在内容视图上（而非 `.background` 内部），
    /// 确保玻璃效果能正确采样背后内容，避免深色模式下渲染异常。
    @ViewBuilder
    func badgeStyle() -> some View {
        let styled = self
            .font(.caption2.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)

        if #available(iOS 26.0, macOS 26.0, *) {
            styled.glassEffect(.regular, in: .rect(cornerRadius: 8))
        } else {
            styled.background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    /// 在 iOS 26+ 上将内容包裹在 GlassEffectContainer 中，
    /// 使相邻玻璃元素共享采样区域，保证一致渲染。
    @ViewBuilder
    func glassEffectContainerIfAvailable(spacing: CGFloat = 8) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }
}
