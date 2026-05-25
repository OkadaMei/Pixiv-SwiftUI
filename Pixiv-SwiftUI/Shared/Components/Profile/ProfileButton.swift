import SwiftUI

struct ProfileButton: View {
    let accountStore: AccountStore
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: { isPresented = true }) {
            if let account = accountStore.currentAccount, accountStore.isLoggedIn {
                AnimatedAvatarImage(
                    urlString: account.userImage, size: 42,
                    expiration: DefaultCacheExpiration.myAvatar)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("我的")
        .accessibilityShowsLargeContentViewer()
    }
}

// MARK: - 向后兼容 sharedBackgroundVisibility (iOS 26+ 液态玻璃)
extension ToolbarContent {
    /// 隐藏 ToolbarItem 的液态玻璃共享背景，让头像按钮完整显示。
    /// iOS 26+ 上自动应用 `.sharedBackgroundVisibility(.hidden)`，
    /// 低版本系统无效果。
    @ToolbarContentBuilder
    func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
