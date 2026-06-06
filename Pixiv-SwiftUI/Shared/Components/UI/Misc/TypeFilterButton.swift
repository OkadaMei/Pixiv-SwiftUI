import SwiftUI

struct TypeFilterButton: View {
    enum ContentType: String, CaseIterable {
        case all = "全部"
        case illust = "插画"
        case manga = "漫画"

        var localizedName: String {
            switch self {
            case .all: return String(localized: "全部")
            case .illust: return String(localized: "插画")
            case .manga: return String(localized: "漫画")
            }
        }
    }

    @Binding var selectedType: ContentType
    var restrict: RestrictType?
    @Binding var selectedRestrict: RestrictType?
    var showAll: Bool = true
    var showContentTypes: Bool = true
    @Binding var cacheFilter: BookmarkCacheFilter?
    var showRestrict: Bool = true

    enum RestrictType: String, CaseIterable {
        case publicAccess = "公开"
        case privateAccess = "非公开"

        var localizedName: String {
            switch self {
            case .publicAccess: return String(localized: "公开")
            case .privateAccess: return String(localized: "非公开")
            }
        }
    }

    private var visibleTypes: [ContentType] {
        if !showContentTypes {
            return []
        }
        if showAll {
            return ContentType.allCases
        }
        return [.illust, .manga]
    }

    var body: some View {
        Menu {
            if !visibleTypes.isEmpty {
                Section(String(localized: "内容类型")) {
                    ForEach(visibleTypes, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Text(type.localizedName)
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if restrict != nil && showRestrict {
                Section(String(localized: "可见性")) {
                    ForEach(RestrictType.allCases, id: \.self) { restrictType in
                        Button {
                            selectedRestrict = restrictType
                        } label: {
                            HStack {
                                Text(restrictType.localizedName)
                                if selectedRestrict == restrictType {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if cacheFilter != nil {
                Section(String(localized: "缓存状态")) {
                    ForEach(BookmarkCacheFilter.allCases, id: \.self) { filter in
                        Button {
                            cacheFilter = filter
                        } label: {
                            HStack {
                                Text(filter.localizedName)
                                if cacheFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
    }
}

#Preview {
    TypeFilterButton(
        selectedType: .constant(.all),
        restrict: nil,
        selectedRestrict: .constant(nil as TypeFilterButton.RestrictType?),
        cacheFilter: .constant(nil as BookmarkCacheFilter?)
    )
}
