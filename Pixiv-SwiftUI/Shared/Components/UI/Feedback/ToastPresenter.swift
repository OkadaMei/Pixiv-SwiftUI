import SwiftUI

/// 全局 Toast 通知管理器。
///
/// 通过 Environment 注入，Store 和 View 均可调用 `show()` 弹出统一风格的 Toast。
///
/// ```swift
/// @Environment(ToastPresenter.self) var toast
/// toast.show("保存成功")
/// ```
@Observable
final class ToastPresenter {
    private(set) var message: String?
    private(set) var isPresented = false

    func show(_ message: String, duration: TimeInterval = 2.0) {
        self.message = message
        withAnimation { isPresented = true }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                withAnimation { self?.isPresented = false }
            }
        }
    }

    func dismiss() {
        withAnimation { isPresented = false }
    }
}

// MARK: - 全局 Toast Overlay

/// 在任意 View 顶层叠加全局 Toast。
private struct GlobalToastOverlayModifier: ViewModifier {
    @State private var presenter = ToastPresenter()

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .overlay(alignment: .bottom) {
                if presenter.isPresented, let message = presenter.message {
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(100)
                        .padding(.bottom, 50)
                }
            }
    }
}

extension View {
    /// 启用全局 Toast 能力。在 App 根视图上调用一次即可。
    func withGlobalToast() -> some View {
        modifier(GlobalToastOverlayModifier())
    }
}

#Preview {
    VStack {
        Button("显示 Toast") {
            // 预览中不能直接访问 presenter，这里仅演示组件结构
        }
    }
    .withGlobalToast()
}
