import SwiftData
import SwiftUI
import Kingfisher
#if os(macOS)
import AppKit
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return UserDefaults.standard.bool(forKey: "quit_after_window_closed")
    }
}
#endif

@main
struct PixivApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var initializer = AppInitializer.shared
    @State private var pendingUpdateInfo: AppUpdateInfo?

    var body: some Scene {
        WindowGroup(id: "main") {
            ZStack {
                if initializer.isLaunching || initializer.accountStore == nil {
                    LaunchScreenView()
                } else {
                    ContentView()
                        .environment(initializer.accountStore ?? AccountStore.shared)
                        .environment(initializer.illustStore ?? IllustStore.shared)
                        .environment(initializer.userSettingStore ?? UserSettingStore.shared)
                        .environment(ThemeManager.shared)
                        .modelContainer(initializer.modelContainer ?? DataContainer.shared.modelContainer)
                }
            }
            .sheet(item: $pendingUpdateInfo) { info in
                    UpdateAvailableSheet(updateInfo: info, isPresented: Binding(
                        get: { pendingUpdateInfo != nil },
                        set: { if !$0 { pendingUpdateInfo = nil } }
                    ))
                }
            .onReceive(NotificationCenter.default.publisher(for: .init("ShowUpdateNotification"))) { notification in
                if let info = notification.object as? AppUpdateInfo {
                    pendingUpdateInfo = info
                }
            }
            .task {
                await initializer.performInitialization()
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                handleMemoryWarning()
            }
            #endif
            #if os(macOS)
            .frame(minWidth: 1000, minHeight: 700)
            #endif
        }
        .commands {
            if let accountStore = initializer.accountStore {
                AppCommands(accountStore: accountStore)
            }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif

        #if os(macOS)
        WindowGroup(id: "illust-detail", for: Int.self) { $id in
            if let id = id {
                IllustWindowRootView(illustID: id)
                    .environment(AccountStore.shared)
                    .environment(IllustStore.shared)
                    .environment(UserSettingStore.shared)
                    .environment(ThemeManager.shared)
                    .modelContainer(DataContainer.shared.modelContainer)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        WindowGroup(id: "novel-detail", for: Int.self) { $id in
            if let id = id {
                NovelWindowRootView(novelID: id)
                    .environment(AccountStore.shared)
                    .environment(IllustStore.shared)
                    .environment(UserSettingStore.shared)
                    .environment(ThemeManager.shared)
                    .modelContainer(DataContainer.shared.modelContainer)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        WindowGroup(id: "settings") {
            SettingsContainerView()
                .environment(AccountStore.shared)
                .environment(UserSettingStore.shared)
                .environment(ThemeManager.shared)
                .modelContainer(DataContainer.shared.modelContainer)
                .frame(minWidth: 600, minHeight: 500)
        }
        .defaultSize(width: 600, height: 500)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }

    /// 收到内存警告时清理 Kingfisher 等内存缓存
    private func handleMemoryWarning() {
        ImageCache.default.clearMemoryCache()
        BookmarkCacheService.shared.getCache().clearMemoryCache()
        IllustStore.shared.clearMemoryCache()
        NovelStore.shared.clearMemoryCache()
        SearchStore.shared.clearMemoryCache()
    }
}

struct ContentView: View {
    @Environment(AccountStore.self) var accountStore
    @Environment(UserSettingStore.self) var userSettingStore
    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif
    @State private var showTokenRefreshFailedToast: Bool = false

    var body: some View {
        Group {
            if !accountStore.hasAttemptedLogin {
                AuthView(accountStore: accountStore, onGuestMode: {
                    accountStore.markLoginAttempted()
                })
            } else {
                Group {
                    #if os(macOS)
                    MainSplitView(accountStore: accountStore)
                    #else
                    MainTabView(accountStore: accountStore)
                    #endif
                }
                .preferredColorScheme(
                    userSettingStore.userSetting.colorSchemeMode == 1 ? .light :
                    userSettingStore.userSetting.colorSchemeMode == 2 ? .dark : nil
                )
                .toast(
                    isPresented: $showTokenRefreshFailedToast,
                    message: "登录状态已过期，请重新登录",
                    duration: 3.0
                )
            }
        }
        .onChange(of: accountStore.showTokenRefreshFailedToast) { _, newValue in
            showTokenRefreshFailedToast = newValue
        }
        .animation(.easeInOut(duration: 0.3), value: accountStore.isLoggedIn)
        #if os(iOS)
        .onAppear {
            updateAppPreviewProtection()
        }
        .onChange(of: scenePhase) { _, _ in
            updateAppPreviewProtection()
        }
        .onChange(of: userSettingStore.userSetting.blurAppPreviewInBackground) { _, _ in
            updateAppPreviewProtection()
        }
        .onDisappear {
            AppPreviewPrivacyManager.shared.removeAllOverlays()
        }
        #endif
    }

    #if os(iOS)
    private func updateAppPreviewProtection() {
        AppPreviewPrivacyManager.shared.updateProtection(
            isEnabled: userSettingStore.userSetting.blurAppPreviewInBackground,
            scenePhase: scenePhase
        )
    }
    #endif
}

#Preview {
    ContentView()
        .environment(AccountStore.shared)
        .environment(IllustStore())
        .environment(UserSettingStore())
}
