import Foundation
import Observation

@Observable
@MainActor
final class NovelSeriesStore {
    let seriesId: Int

    var seriesDetail: NovelSeriesDetail?
    var novels: [Novel] = []
    var isLoading = false
    var isLoadingMore = false
    var error: AppError?
    var nextUrl: String?

    init(seriesId: Int) {
        self.seriesId = seriesId
    }

    func fetch() async {
        isLoading = true
        error = nil

        do {
            let response = try await PixivAPI.shared.novelAPI.getNovelSeries(seriesId: seriesId)
            seriesDetail = response.novelSeriesDetail
            novels = response.novels
            nextUrl = response.nextUrl
            isLoading = false
        } catch {
            self.error = AppError.unknown(error)
            isLoading = false
        }
    }

    func loadMore() async {
        guard !isLoadingMore, let nextUrl = nextUrl else { return }

        isLoadingMore = true

        do {
            let response = try await PixivAPI.shared.novelAPI.getNovelSeriesByURL(nextUrl)
            novels.append(contentsOf: response.novels)
            self.nextUrl = response.nextUrl
            isLoadingMore = false
        } catch {
            self.error = AppError.unknown(error)
            isLoadingMore = false
        }
    }
}
