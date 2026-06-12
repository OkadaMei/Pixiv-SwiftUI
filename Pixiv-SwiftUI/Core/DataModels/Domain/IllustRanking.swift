import Foundation

/// 插画排行榜模式
enum IllustRankingMode: String, CaseIterable, Identifiable {
    case day = "day"
    case dayMale = "day_male"
    case dayFemale = "day_female"
    case week = "week"
    case month = "month"
    case weekOriginal = "week_original"
    case weekRookie = "week_rookie"
    case dayAI = "day_ai"
    case dayR18AI = "day_r18_ai"
    case dayR18 = "day_r18"
    case weekR18 = "week_r18"
    case weekR18G = "week_r18g"

    var id: String { rawValue }

    nonisolated static var allModes: [IllustRankingMode] {
        [.day, .dayMale, .dayFemale, .weekOriginal, .weekRookie, .week, .month, .dayAI, .dayR18AI, .dayR18, .weekR18, .weekR18G]
    }

    nonisolated static var defaultVisibleModes: [IllustRankingMode] {
        [.day, .dayMale, .dayFemale, .week, .month]
    }

    nonisolated static var hiddenModes: [IllustRankingMode] {
        allModes.filter { !defaultVisibleModes.contains($0) }
    }

    nonisolated static var xviiiModes: [IllustRankingMode] {
        [.dayR18AI, .dayR18, .weekR18, .weekR18G]
    }

    nonisolated static func orderedModes(from rawValues: [String]) -> [IllustRankingMode] {
        let storedModes = uniqueModes(from: rawValues)
        guard !storedModes.isEmpty else { return allModes }

        let storedModeSet = Set(storedModes)
        return storedModes + allModes.filter { !storedModeSet.contains($0) }
    }

    nonisolated static func enabledModes(
        from rawValues: [String],
        legacyHiddenRawValues: [String] = [],
        showXVIIIRankingGroups: Bool = false
    ) -> [IllustRankingMode] {
        let storedModes = uniqueModes(from: rawValues)
        if !storedModes.isEmpty {
            return storedModes
        }

        var legacyHiddenModes = uniqueModes(from: legacyHiddenRawValues)
        if legacyHiddenModes.isEmpty, showXVIIIRankingGroups {
            legacyHiddenModes = xviiiModes
        }

        let legacyHiddenModeSet = Set(legacyHiddenModes)
        return allModes.filter { defaultVisibleModes.contains($0) || legacyHiddenModeSet.contains($0) }
    }

    nonisolated static func enabledHiddenModes(from enabledModes: [IllustRankingMode]) -> [IllustRankingMode] {
        let enabledModeSet = Set(enabledModes)
        return hiddenModes.filter { enabledModeSet.contains($0) }
    }

    var isHiddenByDefault: Bool {
        Self.hiddenModes.contains(self)
    }

    var isXVIIIMode: Bool {
        Self.xviiiModes.contains(self)
    }

    var title: String {
        switch self {
        case .day:
            return String(localized: "每日")
        case .dayMale:
            return String(localized: "男性向")
        case .dayFemale:
            return String(localized: "女性向")
        case .week:
            return String(localized: "每周")
        case .month:
            return String(localized: "每月")
        case .weekOriginal:
            return String(localized: "原创")
        case .weekRookie:
            return String(localized: "新人")
        case .dayAI:
            return String(localized: "AI")
        case .dayR18AI:
            return "XVIII_AI"
        case .dayR18:
            return "XVIII"
        case .weekR18:
            return "XVIII_WEEK"
        case .weekR18G:
            return "XVIII_G"
        }
    }

    private nonisolated static func uniqueModes(from rawValues: [String]) -> [IllustRankingMode] {
        var seenModes = Set<IllustRankingMode>()

        return rawValues.compactMap(IllustRankingMode.init(rawValue:)).filter { seenModes.insert($0).inserted }
    }
}

/// 插画排行榜响应
struct IllustRankingResponse {
    let illusts: [Illusts]
    let nextUrl: String?
}

/// 排行榜中的插画（包含排名信息）
struct RankingIllust {
    let illust: Illusts
    let rank: Int
    let previousRank: Int?
    let change: Int?
}
