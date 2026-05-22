import SwiftUI

// MARK: - ScorecardImageViewer
// 줌/패닝 지원 이미지 뷰어.
// - 핀치 줌: 0.5x ~ 4x
// - 더블탭: 1x ↔ 2x 토글
// - DragGesture: 줌 상태에서 패닝

struct ScorecardImageViewer: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            magnificationGesture,
                            dragGesture(in: proxy.size)
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1.05 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                            lastScale = scale
                        }
                    }
            }
        }
    }

    // MARK: Magnification

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(maxScale, max(minScale, newScale))
            }
            .onEnded { value in
                let newScale = lastScale * value
                scale = min(maxScale, max(minScale, newScale))
                lastScale = scale
                // 1x 이하가 되면 오프셋도 리셋
                if scale <= 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    // MARK: Drag

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                let maxOffsetX = (size.width * (scale - 1)) / 2
                let maxOffsetY = (size.height * (scale - 1)) / 2
                let newX = lastOffset.width + value.translation.width
                let newY = lastOffset.height + value.translation.height
                offset = CGSize(
                    width: min(maxOffsetX, max(-maxOffsetX, newX)),
                    height: min(maxOffsetY, max(-maxOffsetY, newY))
                )
            }
            .onEnded { value in
                guard scale > 1.0 else { return }
                let maxOffsetX = (size.width * (scale - 1)) / 2
                let maxOffsetY = (size.height * (scale - 1)) / 2
                let newX = lastOffset.width + value.translation.width
                let newY = lastOffset.height + value.translation.height
                offset = CGSize(
                    width: min(maxOffsetX, max(-maxOffsetX, newX)),
                    height: min(maxOffsetY, max(-maxOffsetY, newY))
                )
                lastOffset = offset
            }
    }
}
