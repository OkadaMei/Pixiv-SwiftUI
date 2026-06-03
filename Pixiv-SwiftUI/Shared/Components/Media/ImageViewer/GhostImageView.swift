import SwiftUI
import Kingfisher

// MARK: - Ghost Image Loader

/// Loads an image from the Kingfisher cache and renders it as a SwiftUI `Image`,
/// used as the ghost image during transitions.
struct KingfisherGhostImage: View {
    let urlString: String
    let aspectRatio: CGFloat

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

        // Try memory cache first (instant)
        let cacheKey = url.absoluteString
        if let cached = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: cacheKey) {
            uiImage = cached
            return
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
                uiImage = result.image
                return
            }
        }
    }
}
