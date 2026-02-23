import SwiftUI

struct SpotlightListTarget: Hashable, Identifiable {
    let id = UUID()
}

struct SpotlightListView: View {
    @State private var store = SpotlightStore()
    @State private var navigateToDetail: SpotlightArticle?

    #if os(macOS)
    @State private var columnCount: Int = 4
    #else
    @State private var columnCount: Int = 2
    #endif

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.articles) { article in
                    Button {
                        navigateToDetail = article
                    } label: {
                        SpotlightListCard(article: article)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if article.id == store.articles.last?.id {
                            Task {
                                await store.loadMore()
                            }
                        }
                    }
                }

                if store.isLoadingMore {
                    ForEach(0..<columnCount, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1.5, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .skeleton()

                            VStack(alignment: .leading, spacing: 2) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 14)
                                    .skeleton()
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 10)
                                    .skeleton()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle(String(localized: "亮点"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if store.articles.isEmpty {
                await store.fetch()
            }
        }
        .refreshable {
            await store.fetch(forceRefresh: true)
        }
        .navigationDestination(item: $navigateToDetail) { article in
            SpotlightDetailView(article: article)
        }
    }
}

#Preview {
    NavigationStack {
        SpotlightListView()
    }
}
