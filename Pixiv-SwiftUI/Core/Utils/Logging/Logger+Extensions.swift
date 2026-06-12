import Foundation
import os.log

// MARK: - Logger Categories

extension Logger {
    // Core infrastructure
    nonisolated static var network: Logger { Logger(subsystem: "com.pixiv.app", category: "Network") }
    nonisolated static var auth: Logger { Logger(subsystem: "com.pixiv.app", category: "Auth") }
    nonisolated static var token: Logger { Logger(subsystem: "com.pixiv.app", category: "Token") }
    nonisolated static var cache: Logger { Logger(subsystem: "com.pixiv.app", category: "Cache") }
    nonisolated static var database: Logger { Logger(subsystem: "com.pixiv.app", category: "Database") }
    nonisolated static var storage: Logger { Logger(subsystem: "com.pixiv.app", category: "Storage") }

    // swiftlint:disable identifier_name

    // UI / Navigation
    nonisolated static var ui: Logger { Logger(subsystem: "com.pixiv.app", category: "UI") }

    // swiftlint:enable identifier_name

    // Feature domains
    nonisolated static var download: Logger { Logger(subsystem: "com.pixiv.app", category: "Download") }
    nonisolated static var ugoira: Logger { Logger(subsystem: "com.pixiv.app", category: "Ugoira") }
    nonisolated static var novel: Logger { Logger(subsystem: "com.pixiv.app", category: "Novel") }
    nonisolated static var bookmark: Logger { Logger(subsystem: "com.pixiv.app", category: "Bookmark") }
    nonisolated static var search: Logger { Logger(subsystem: "com.pixiv.app", category: "Search") }
    nonisolated static var illust: Logger { Logger(subsystem: "com.pixiv.app", category: "Illust") }
    nonisolated static var user: Logger { Logger(subsystem: "com.pixiv.app", category: "User") }
    nonisolated static var manga: Logger { Logger(subsystem: "com.pixiv.app", category: "Manga") }
    nonisolated static var updates: Logger { Logger(subsystem: "com.pixiv.app", category: "Updates") }
    nonisolated static var settings: Logger { Logger(subsystem: "com.pixiv.app", category: "Settings") }
    nonisolated static var menu: Logger { Logger(subsystem: "com.pixiv.app", category: "Menu") }
    nonisolated static var spotlight: Logger { Logger(subsystem: "com.pixiv.app", category: "Spotlight") }
    nonisolated static var tagTranslation: Logger { Logger(subsystem: "com.pixiv.app", category: "TagTranslation") }

    // Utility
    nonisolated static var updater: Logger { Logger(subsystem: "com.pixiv.app", category: "Updater") }
    nonisolated static var `general`: Logger { Logger(subsystem: "com.pixiv.app", category: "General") }
}
