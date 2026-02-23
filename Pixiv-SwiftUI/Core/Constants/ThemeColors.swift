import Foundation

struct ThemeColor: Identifiable {
    let id: String
    let nameKey: String
    let hex: Int
    let isCustom: Bool

    init(id: String? = nil, nameKey: String, hex: Int, isCustom: Bool = false) {
        self.id = id ?? (isCustom ? "custom" : String(hex))
        self.nameKey = nameKey
        self.hex = hex
        self.isCustom = isCustom
    }
}

struct ThemeColors {
    static let all: [ThemeColor] = [
        ThemeColor(nameKey: "theme.pixivBlue", hex: 0x0096FA),
        ThemeColor(nameKey: "theme.sakuraPink", hex: 0xFFB7C5),
        ThemeColor(nameKey: "theme.grassGreen", hex: 0x40BF77),
        ThemeColor(nameKey: "theme.sunnyYellow", hex: 0xFFD700),
        ThemeColor(nameKey: "theme.violet", hex: 0x8B5CF6),
        ThemeColor(nameKey: "theme.coralRed", hex: 0xFF7F50),
        ThemeColor(nameKey: "theme.cyan", hex: 0x00CED1),
        ThemeColor(nameKey: "theme.custom", hex: 0x0096FA, isCustom: true)
    ]

    static var defaultColor: ThemeColor {
        all.first { $0.hex == 0x0096FA } ?? all[0]
    }
}
