import SwiftUI

// MARK: - Transition Phase State Machine

enum TransitionPhase: Equatable {
    /// Normal detail view — no transition active
    case idle
    /// Entering fullscreen — ghost image animating from source frame to fullscreen
    case entering(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat)
    /// Fullscreen viewer fully visible — zoom/pan enabled
    case fullscreen
    /// Exiting fullscreen — ghost image animating back to source frame
    case exiting(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat)

    var isTransitioning: Bool {
        switch self {
        case .idle, .fullscreen: return false
        case .entering, .exiting: return true
        }
    }

    var isFullscreen: Bool {
        self == .fullscreen
    }
}

// MARK: - Preference Key for Image Frame Capture

/// Captures the detail image's frame in global coordinates when the user taps.
struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let new = nextValue()
        if new != .zero { value = new }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Adds a background `GeometryReader` that reports the view's frame via `ImageFramePreferenceKey`.
    func reportImageFrame() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ImageFramePreferenceKey.self,
                        value: geometry.frame(in: .global)
                    )
            }
        )
    }

    /// Conditionally reports the frame only when `condition` is true.
    /// Useful when multiple views in a `ForEach` could otherwise race to set the same key.
    func reportImageFrame(when condition: Bool) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: ImageFramePreferenceKey.self,
                        value: condition ? geometry.frame(in: .global) : .zero
                    )
            }
        )
    }
}
