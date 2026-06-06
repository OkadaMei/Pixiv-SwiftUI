import SwiftUI

#if os(iOS)
    import UIKit
    import CoreImage

    @MainActor
    final class AppPreviewPrivacyManager {
        static let shared = AppPreviewPrivacyManager()

        /// 高斯模糊半径。数值越大模糊越强
        private static let blurRadius: CGFloat = 40

        private let overlayTag = 0x507658

        /// 复用的 CIContext — 创建成本高，应缓存使用。
        private let ciContext = CIContext(options: [
            .workingColorSpace: NSNull(),
            .outputPremultiplied: true,
        ])

        private init() {}

        func updateProtection(isEnabled: Bool, scenePhase: ScenePhase) {
            let shouldProtect = isEnabled && scenePhase != .active

            for window in appWindows {
                if shouldProtect {
                    if !window.isHidden && window.windowLevel == .normal {
                        installOverlay(on: window)
                    }
                } else {
                    removeOverlay(from: window)
                }
            }
        }

        func removeAllOverlays() {
            for window in appWindows {
                removeOverlay(from: window)
            }
        }

        private var appWindows: [UIWindow] {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
        }

        private func installOverlay(on window: UIWindow) {
            if let overlay = window.viewWithTag(overlayTag) {
                window.bringSubviewToFront(overlay)
                return
            }

            let bounds = window.bounds

            // 1. 捕获当前窗口内容
            let format = UIGraphicsImageRendererFormat(for: window.traitCollection)
            let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
            let screenshot = renderer.image { _ in
                window.drawHierarchy(in: bounds, afterScreenUpdates: false)
            }

            guard let ciImage = CIImage(image: screenshot) else {
                // 回退：兜底使用纯色覆盖
                fallbackOverlay(on: window, bounds: bounds)
                return
            }

            // 2. 正确的高斯模糊流水线：
            //    clampedToExtent() 将图像边缘无限扩展 →
            //    CIGaussianBlur 采样时能获取正确的边缘像素 →
            //    cropped(to: original extent) 裁剪回原始尺寸
            guard let filter = CIFilter(name: "CIGaussianBlur") else {
                fallbackOverlay(on: window, bounds: bounds)
                return
            }
            filter.setValue(ciImage.clampedToExtent(), forKey: kCIInputImageKey)
            filter.setValue(Self.blurRadius, forKey: kCIInputRadiusKey)

            guard
                let blurredImage = filter.outputImage?
                    .cropped(to: ciImage.extent)
            else {
                fallbackOverlay(on: window, bounds: bounds)
                return
            }

            guard let cgImage = ciContext.createCGImage(blurredImage, from: blurredImage.extent)
            else {
                fallbackOverlay(on: window, bounds: bounds)
                return
            }

            // 3. 显示模糊覆盖层（保留原截图的 scale，确保像素对齐）
            let resultImage = UIImage(cgImage: cgImage, scale: screenshot.scale, orientation: .up)
            let imageView = UIImageView(image: resultImage)
            imageView.tag = overlayTag
            imageView.frame = bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.isUserInteractionEnabled = false
            imageView.contentMode = .scaleToFill

            window.addSubview(imageView)
            window.bringSubviewToFront(imageView)
        }

        /// 当快照或模糊失败时的兜底方案 — 使用半透明灰色覆盖。
        private func fallbackOverlay(on window: UIWindow, bounds: CGRect) {
            let view = UIView(frame: bounds)
            view.tag = overlayTag
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.backgroundColor = UIColor.systemFill
            view.isUserInteractionEnabled = false
            window.addSubview(view)
            window.bringSubviewToFront(view)
        }

        private func removeOverlay(from window: UIWindow) {
            window.viewWithTag(overlayTag)?.removeFromSuperview()
        }
    }
#else
    @MainActor
    final class AppPreviewPrivacyManager {
        static let shared = AppPreviewPrivacyManager()

        private init() {}

        func updateProtection(isEnabled: Bool, scenePhase: ScenePhase) {}

        func removeAllOverlays() {}
    }
#endif
