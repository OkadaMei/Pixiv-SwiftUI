import SwiftUI

struct FullscreenImageView: View {
    let imageURLs: [String]
    let fallbackImageURLs: [String]
    let aspectRatios: [CGFloat]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    @Binding var exitDragProgress: CGFloat
    var animation: Namespace.ID
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isZoomed: Bool = false
    @State private var screenHeight: CGFloat = 0
    @State private var currentScrollPosition: Int?

    private var dismissProgress: CGFloat {
        guard screenHeight > 0 else { return 0 }
        return min(dragOffset / screenHeight, 1.0)
    }

    private var scale: CGFloat {
        1.0 - dismissProgress * 0.3
    }

    private var backgroundOpacity: Double {
        1.0 - Double(dismissProgress)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<imageURLs.count, id: \.self) { index in
                            ZoomableAsyncImage(
                                urlString: imageURLs[index],
                                fallbackURL: index < fallbackImageURLs.count ? fallbackImageURLs[index] : nil,
                                aspectRatio: index < aspectRatios.count ? aspectRatios[index] : nil,
                                onDismiss: {
                                    isPresented = false
                                },
                                isZoomed: $isZoomed,
                                onDragProgress: { progress in
                                    dragOffset = progress * screenHeight
                                },
                                onDragEnded: { shouldDismiss in
                                    if shouldDismiss {
                                        exitDragProgress = dismissProgress
                                        isPresented = false
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                            )
                            .containerRelativeFrame(.horizontal)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentScrollPosition)
                .ignoresSafeArea()
                .scaleEffect(scale)
                .offset(y: dragOffset)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background {
                                    if #available(iOS 26.0, macOS 26.0, *) {
                                        Circle()
                                            .fill(.black)
                                            .glassEffect(.regular, in: Circle())
                                    } else {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                        }
                        .padding()
                    }
                    Spacer()

                    if imageURLs.count > 1 {
                        Text("\(currentPage + 1) / \(imageURLs.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                }
                .opacity(Double(1 - dismissProgress * 2))
            }
            .onAppear {
                screenHeight = geometry.size.height
                currentScrollPosition = initialPage
            }
            .onChange(of: geometry.size.height) { _, newValue in
                screenHeight = newValue
            }
            .onChange(of: currentScrollPosition) { _, newId in
                if let page = newId, page != currentPage {
                    currentPage = page
                    initialPage = page
                    isZoomed = false
                }
            }
        }
    }
}
