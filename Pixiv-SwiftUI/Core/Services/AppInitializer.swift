import SwiftUI
import SwiftData
import Observation

/// 应用启动初始化器，负责协调启动过程中的各种任务
@MainActor
@Observable
final class AppInitializer {
    static let shared = AppInitializer()

    var isLaunching = true
    var accountStore: AccountStore?
    var illustStore: IllustStore?
    var userSettingStore: UserSettingStore?
    var modelContainer: ModelContainer?

    private init() {}

    /// 执行应用初始化序列
    func performInitialization() async {
        // 1. 初始化 SwiftData 容器（此时 LaunchScreenView 已显示，不会阻塞首帧）
        let container = DataContainer.shared.modelContainer
        self.modelContainer = container

        // 2. 初始化核心 Store
        let aStore = AccountStore.shared
        let iStore = IllustStore.shared
        let uStore = UserSettingStore.shared

        // 3. 异步加载持久化数据
        // 并行加载账户和设置
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await aStore.loadAccountsAsync() }
            group.addTask { await uStore.loadUserSettingAsync() }
        }

        // 4. 设置加载完成后刷新主题色（此时 UserSetting 已就绪）
        ThemeManager.shared.updateThemeColor()

        // 5. 更新初始化状态
        self.accountStore = aStore
        self.illustStore = iStore
        self.userSettingStore = uStore

        // 6. 结束启动状态
        withAnimation(.easeInOut(duration: 0.4)) {
            self.isLaunching = false
        }

        // 7. 后续任务（不阻塞 UI 展示）
        AccountStore.shared.markLoginAttempted()

        // 8. 后台配置基础服务（不阻塞启动）
        Task {
            CacheConfig.configureKingfisher()
            UgoiraStore.cleanupLegacyCache()
        }

        // 9. 检查更新（后台执行）
        checkForUpdateOnLaunch()
    }

    private func checkForUpdateOnLaunch() {
        guard userSettingStore?.userSetting.checkUpdateOnLaunch == true else { return }

        Task {
            if let updateInfo = await UpdateChecker.shared.checkForUpdate() {
                await MainActor.run {
                    if updateInfo.isNewerThanCurrent {
                        NotificationCenter.default.post(
                            name: .init("ShowUpdateNotification"),
                            object: updateInfo
                        )
                    }
                }
            }
        }
    }
}
