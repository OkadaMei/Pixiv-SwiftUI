import SwiftUI

struct SpotlightDetailView: View {
    let article: SpotlightArticle

    @State private var store = SpotlightDetailStore()
    @State private var navigateToIllustId: Int?
    @State private var navigateToRelatedArticle: SpotlightRelatedArticle?

    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore

    #if os(macOS)
    @State private var columnCount: Int = 4
    #elseif os(iOS)
    @State private var columnCount: Int = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                if store.isLoading {
                    loadingView
                } else if let detail = store.detail {
                    contentView(detail)
                } else if let error = store.error {
                    errorView(error)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        #if os(macOS)
        .navigationTitle(article.displayTitle)
        #else
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let articleUrl = URL(string: article.articleUrl) {
                    ShareLink(item: articleUrl) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            if store.detail == nil {
                await store.fetch(url: article.articleUrl)
            }
        }
        .navigationDestination(item: $navigateToIllustId) { illustId in
            IllustLoaderView(illustId: illustId)
        }
        .navigationDestination(item: $navigateToRelatedArticle) { relatedArticle in
            let spotlightArticle = SpotlightArticle(
                id: relatedArticle.id,
                title: relatedArticle.title,
                pureTitle: relatedArticle.title,
                thumbnail: relatedArticle.thumbnail,
                articleUrl: relatedArticle.articleUrl,
                publishDate: Date()
            )
            SpotlightDetailView(article: spotlightArticle)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            CachedAsyncImage(
                urlString: article.thumbnail,
                aspectRatio: 16 / 9
            )
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(article.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                HStack {
                    Image(systemName: "calendar")
                    Text(formattedDate(article.publishDate))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .padding(.top, 32)

            Text(String(localized: "加载中..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func contentView(_ detail: SpotlightArticleDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if !detail.description.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 18)
                        Text(String(localized: "简介"))
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(descriptionParagraphs(detail.description), id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }

            if !detail.works.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 18)
                        Text(String(localized: "收录作品"))
                            .font(.headline)

                        Spacer()

                        Text("\(detail.works.count) 项")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    WaterfallGrid(
                        data: detail.works,
                        columnCount: columnCount,
                        spacing: 8
                    ) { work, columnWidth in
                        SpotlightWorkCard(work: work, columnWidth: columnWidth) {
                            navigateToIllustId = work.id
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            if !detail.rankingArticles.isEmpty {
                SpotlightRelatedSection(
                    title: String(localized: "本月排行榜"),
                    articles: detail.rankingArticles,
                    onArticleTap: { article in
                        navigateToRelatedArticle = article
                    }
                )
            }

            if !detail.recommendedArticles.isEmpty {
                SpotlightRelatedSection(
                    title: String(localized: "推荐"),
                    articles: detail.recommendedArticles,
                    onArticleTap: { article in
                        navigateToRelatedArticle = article
                    }
                )
            }

            if detail.works.isEmpty && detail.description.isEmpty {
                Text(String(localized: "暂无内容"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            }
        }
        .padding(.bottom, 32)
    }

    private func errorView(_ error: AppError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(String(localized: "重试")) {
                Task {
                    await store.fetch(url: article.articleUrl)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private func descriptionParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

#Preview {
    NavigationStack {
        SpotlightDetailView(
            article: SpotlightArticle(
                id: 1,
                title: "#猫猫日特辑 那些可爱的猫猫",
                pureTitle: "那些可爱的猫猫",
                thumbnail: "https://example.com/image.jpg",
                articleUrl: "https://example.com/article",
                publishDate: Date()
            )
        )
    }
}
