import SwiftUI

struct BlockSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var newTag = ""
    @State private var newUserId = ""
    @State private var newIllustId = ""
    @State private var newNovelTitleKeyword = ""
    @State private var newNovelSeriesKeyword = ""
    @State private var newNovelCaptionKeyword = ""

    var body: some View {
        Form {
            tagsSection
            usersSection
            illustsSection
            novelTitleKeywordsSection
            novelSeriesKeywordsSection
            novelCaptionKeywordsSection
        }
        .formStyle(.grouped)
    }

    private var tagsSection: some View {
        Section(String(localized: "屏蔽标签")) {
            if userSettingStore.blockedTagInfos.isEmpty && userSettingStore.blockedTags.isEmpty {
                Text(String(localized: "暂无屏蔽的标签"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getTagInfos(), id: \.name) { info in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name)
                                .font(.body)
                            if let translated = TagTranslationService.shared.getDisplayTranslation(for: info.name, officialTranslation: info.translatedName), !translated.isEmpty {
                                Text(translated)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedTag(info.name)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加标签"), text: $newTag)
                Button(String(localized: "添加")) {
                    if !newTag.isEmpty {
                        try? userSettingStore.addBlockedTag(newTag)
                        newTag = ""
                    }
                }
                .disabled(newTag.isEmpty)
            }
        }
    }

    private func getTagInfos() -> [BlockedTagInfo] {
        if !userSettingStore.blockedTagInfos.isEmpty {
            return userSettingStore.blockedTagInfos
        }
        return userSettingStore.blockedTags.map { BlockedTagInfo(name: $0, translatedName: nil) }
    }

    private var usersSection: some View {
        Section(String(localized: "屏蔽作者")) {
            if userSettingStore.blockedUserInfos.isEmpty && userSettingStore.blockedUsers.isEmpty {
                Text(String(localized: "暂无屏蔽的作者"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getUserInfos(), id: \.userId) { info in
                    HStack(spacing: 12) {
                        if let avatarUrl = info.avatarUrl {
                            CachedAsyncImage(urlString: avatarUrl)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name ?? info.userId)
                                .font(.body)
                            if let account = info.account {
                                Text("@\(account)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(info.userId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedUser(info.userId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加用户ID"), text: $newUserId)
                Button(String(localized: "添加")) {
                    if !newUserId.isEmpty {
                        try? userSettingStore.addBlockedUser(newUserId)
                        newUserId = ""
                    }
                }
                .disabled(newUserId.isEmpty)
            }
        }
    }

    private func getUserInfos() -> [BlockedUserInfo] {
        if !userSettingStore.blockedUserInfos.isEmpty {
            return userSettingStore.blockedUserInfos
        }
        return userSettingStore.blockedUsers.map { BlockedUserInfo(userId: $0, name: nil, account: nil, avatarUrl: nil) }
    }

    private var illustsSection: some View {
        Section(String(localized: "屏蔽插画")) {
            if userSettingStore.blockedIllustInfos.isEmpty && userSettingStore.blockedIllusts.isEmpty {
                Text(String(localized: "暂无屏蔽的插画"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getIllustInfos(), id: \.illustId) { info in
                    HStack(spacing: 12) {
                        if let thumbnailUrl = info.thumbnailUrl {
                            CachedAsyncImage(urlString: thumbnailUrl)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title ?? "ID: \(info.illustId)")
                                .font(.body)
                                .lineLimit(2)
                            if let authorName = info.authorName {
                                Text(authorName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedIllust(info.illustId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加插画ID"), text: $newIllustId)
                Button(String(localized: "添加")) {
                    if let id = Int(newIllustId) {
                        try? userSettingStore.addBlockedIllust(id)
                        newIllustId = ""
                    }
                }
                .disabled(Int(newIllustId) == nil)
            }
        }
    }

    private func getIllustInfos() -> [BlockedIllustInfo] {
        if !userSettingStore.blockedIllustInfos.isEmpty {
            return userSettingStore.blockedIllustInfos
        }
        return userSettingStore.blockedIllusts.map { BlockedIllustInfo(illustId: $0, title: nil, authorId: nil, authorName: nil, thumbnailUrl: nil) }
    }

    private var novelTitleKeywordsSection: some View {
        keywordSection(
            title: "小说标题拉黑关键词",
            emptyText: "暂无小说标题拉黑关键词",
            placeholder: "添加小说标题关键词",
            keywords: userSettingStore.blockedNovelTitleKeywords,
            text: $newNovelTitleKeyword,
            addAction: { keyword in
                try? userSettingStore.addBlockedNovelTitleKeyword(keyword)
            },
            removeAction: { keyword in
                try? userSettingStore.removeBlockedNovelTitleKeyword(keyword)
            }
        )
    }

    private var novelSeriesKeywordsSection: some View {
        keywordSection(
            title: "小说系列拉黑关键词",
            emptyText: "暂无小说系列拉黑关键词",
            placeholder: "添加小说系列关键词",
            keywords: userSettingStore.blockedNovelSeriesKeywords,
            text: $newNovelSeriesKeyword,
            addAction: { keyword in
                try? userSettingStore.addBlockedNovelSeriesKeyword(keyword)
            },
            removeAction: { keyword in
                try? userSettingStore.removeBlockedNovelSeriesKeyword(keyword)
            }
        )
    }

    private var novelCaptionKeywordsSection: some View {
        keywordSection(
            title: "小说简介拉黑关键词",
            emptyText: "暂无小说简介拉黑关键词",
            placeholder: "添加小说简介关键词",
            keywords: userSettingStore.blockedNovelCaptionKeywords,
            text: $newNovelCaptionKeyword,
            addAction: { keyword in
                try? userSettingStore.addBlockedNovelCaptionKeyword(keyword)
            },
            removeAction: { keyword in
                try? userSettingStore.removeBlockedNovelCaptionKeyword(keyword)
            }
        )
    }

    private func keywordSection(
        title: String,
        emptyText: String,
        placeholder: String,
        keywords: [String],
        text: Binding<String>,
        addAction: @escaping (String) -> Void,
        removeAction: @escaping (String) -> Void
    ) -> some View {
        Section(title) {
            if keywords.isEmpty {
                Text(emptyText)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(keywords, id: \.self) { keyword in
                    HStack(spacing: 12) {
                        Text(keyword)
                            .font(.body)
                            .lineLimit(2)

                        Spacer()

                        Button(action: {
                            triggerHaptic()
                            removeAction(keyword)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(placeholder, text: text)
                Button("添加") {
                    let keyword = text.wrappedValue
                    if !keyword.isEmpty {
                        addAction(keyword)
                        text.wrappedValue = ""
                    }
                }
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview {
    NavigationStack {
        BlockSettingView()
    }
    .frame(maxWidth: 600)
}
