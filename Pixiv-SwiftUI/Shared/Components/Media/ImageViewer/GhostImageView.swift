import SwiftUI
import Kingfisher

// MARK: - Ghost Image Loader

/// Loads an image from the Kingfisher cache and renders it as a SwiftUI `Image`,
/// used as the ghost image during transitions.
struct KingfisherGhostImage: View {
    let urlString: String
    let fallbackURLString: String?
    let aspectRatio: CGFloat

    init(urlString: String, fallbackURLString: String? = nil, aspectRatio: CGFloat) {
        self.urlString = urlString
        self.fallbackURLString = fallbackURLString
        self.aspectRatio = aspectRatio
    }

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(aspectRatio > 0 && aspectRatio.isFinite ? aspectRatio : 1, contentMode: .fit)
            }
        }
        .task {
            await loadCachedImage()
        }
    }

    @MainActor
    private func loadCachedImage() async {
        guard let url = URL(string: urlString) else { return }

        // 1. 尝试主 URL（通常为 zoom-quality）
        if let image = await retrieveCachedImage(url: url) {
            uiImage = image
            return
        }

        // 2. 如果有 fallback URL（通常为 detail-quality），尝试它
        if let fallback = fallbackURLString, let fallbackURL = URL(string: fallback) {
            if let image = await retrieveCachedImage(url: fallbackURL) {
                uiImage = image
                return
            }
        }

        // 3. 最后手段：从网络加载主 URL（同时写入缓存）
        if let image = await loadFromNetwork(url: url) {
            uiImage = image
        }
    }

    @MainActor
    private func retrieveCachedImage(url: URL) async -> UIImage? {
        let cacheKey = url.absoluteString

        // Try memory cache first (instant)
        if let cached = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: cacheKey) {
            return cached
        }

        // Try disk cache — try both source types since the image could be cached under either
        let shouldDirect = NetworkModeStore.shared.useDirectConnection &&
            (url.host?.contains("i.pximg.net") == true || url.host?.contains("img-master.pixiv.net") == true)

        for useDirect in [shouldDirect, !shouldDirect] {
            let source: Source = useDirect ? .directNetwork(url) : .network(url)
            if let result = try? await KingfisherManager.shared.retrieveImage(
                with: source,
                options: [.onlyFromCache, .requestModifier(PixivImageLoader.shared)]
            ) {
                return result.image
            }
        }

        return nil
    }

    @MainActor
    private func loadFromNetwork(url: URL) async -> UIImage? {
        let shouldDirect = NetworkModeStore.shared.useDirectConnection &&
            (url.host?.contains("i.pximg.net") == true || url.host?.contains("img-master.pixiv.net") == true)
        let source: Source = shouldDirect ? .directNetwork(url) : .network(url)
        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared)
        ]
        if let result = try? await KingfisherManager.shared.retrieveImage(with: source, options: options) {
            return result.image
        }
        return nil
    }
}
