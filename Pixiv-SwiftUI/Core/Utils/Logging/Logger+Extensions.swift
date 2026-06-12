import Foundation
import os.log

extension Logger {
    // Core infrastructure
    nonisolated static let network = Logger(subsystem: "com.pixiv.app", category: "Network")
    nonisolated static let auth = Logger(subsystem: "com.pixiv.app", category: "Auth")
    nonisolated static let token = Logger(subsystem: "com.pixiv.app", category: "Token")
    nonisolated static let cache = Logger(subsystem: "com.pixiv.app", category: "Cache")
    nonisolated static let database = Logger(subsystem: "com.pixiv.app", category: "Database")
    nonisolated static let storage = Logger(subsystem: "com.pixiv.app", category: "Storage")

    // UI / Navigation
    // swiftlint:disable identifier_name
    nonisolated static let ui = Logger(subsystem: "com.pixiv.app", category: "UI")
    // swiftlint:enable identifier_name

    // Feature domains
    nonisolated static let download = Logger(subsystem: "com.pixiv.app", category: "Download")
    nonisolated static let ugoira = Logger(subsystem: "com.pixiv.app", category: "Ugoira")
    nonisolated static let novel = Logger(subsystem: "com.pixiv.app", category: "Novel")
    nonisolated static let bookmark = Logger(subsystem: "com.pixiv.app", category: "Bookmark")
    nonisolated static let search = Logger(subsystem: "com.pixiv.app", category: "Search")
    nonisolated static let illust = Logger(subsystem: "com.pixiv.app", category: "Illust")
    nonisolated static let user = Logger(subsystem: "com.pixiv.app", category: "User")
    nonisolated static let manga = Logger(subsystem: "com.pixiv.app", category: "Manga")
    nonisolated static let updates = Logger(subsystem: "com.pixiv.app", category: "Updates")
    nonisolated static let settings = Logger(subsystem: "com.pixiv.app", category: "Settings")
    nonisolated static let menu = Logger(subsystem: "com.pixiv.app", category: "Menu")
    nonisolated static let spotlight = Logger(subsystem: "com.pixiv.app", category: "Spotlight")
    nonisolated static let tagTranslation = Logger(subsystem: "com.pixiv.app", category: "TagTranslation")

    // Utility
    nonisolated static let updater = Logger(subsystem: "com.pixiv.app", category: "Updater")
    nonisolated static let `general` = Logger(subsystem: "com.pixiv.app", category: "General")
}
