import SwiftUI

struct RecommendedUsersListView: View {
    var store: RecommendedUsersStore
    @State private var isRefreshing: Bool = false
    @Environment(ThemeManager.self) var themeManager

    @State private var columnCount: Int = 1

    init(store: RecommendedUsersStore = RecommendedUsersStore()) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                ForEach(store.users) { preview in
                    NavigationLink(value: preview.user) {
                        UserPreviewCard(userPreview: preview, accentColor: themeManager.currentColor)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if preview.id == store.users.last?.id && store.nextUrl != nil {
                            Task {
                                await store.loadMoreUsers()
                            }
                        }
                    }
                }
            }
            .padding()

            if store.nextUrl != nil {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
            } else if !store.users.isEmpty {
                HStack {
                    Spacer()
                    Text(String(localized: "已经到底了"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
        }
        .refreshable {
            isRefreshing = true
            await store.refreshUsers()
            isRefreshing = false
        }
        .responsiveUserGridColumnCount(columnCount: $columnCount)
        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
            isRefreshing = true
            Task {
                await store.refreshUsers()
                isRefreshing = false
            }
        }
        .navigationTitle(String(localized: "推荐画师"))
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        #if os(macOS)
        .toolbar {
            ToolbarItem {
                RefreshButton(refreshAction: {
                    isRefreshing = true
                    await store.refreshUsers()
                    isRefreshing = false
                })
            }
        }
        #endif
        .onAppear {
            if store.users.isEmpty {
                Task {
                    await store.fetchUsers()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecommendedUsersListView()
    }
}
