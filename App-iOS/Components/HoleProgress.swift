import SwiftUI
import Shared

// MARK: - HoleProgress
// iOS F4 홀 진행 도트 표시 (11-COMPONENTS §4, 12-SCREENS D-2)
// 18홀 도트 + 현재 홀 하이라이트 + OUT/IN 구분선

public struct HoleProgress: View {

    // MARK: Props

    public let currentHole: Int  // 1-indexed
    public let totalHoles: Int

    // MARK: Init

    public init(currentHole: Int, totalHoles: Int) {
        self.currentHole = currentHole
        self.totalHoles = totalHoles
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 4) {
            // 도트 행
            GeometryReader { geo in
                dotsRow(width: geo.size.width)
            }
            .frame(height: 12)

            // 홀 번호 (현재 위치 표시)
            HStack {
                Text("1")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.springTextSecondary)
                Spacer()
                if totalHoles > 9 {
                    Text("IN")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.springTextSecondary)
                }
                Spacer()
                Text("\(totalHoles)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.springTextSecondary)
            }
        }
        // 14-ACCESSIBILITY §2
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("홀 진행")
        .accessibilityValue("\(currentHole)번 홀, 총 \(totalHoles)홀 중")
    }

    // MARK: Dots

    private func dotsRow(width: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(1...totalHoles, id: \.self) { hole in
                // OUT/IN 구분 — 9번 홀 뒤에 간격
                if hole == 10 {
                    Spacer().frame(width: 4)
                }
                dotView(for: hole)
            }
        }
    }

    private func dotView(for hole: Int) -> some View {
        let isCurrent = hole == currentHole
        let isPassed = hole < currentHole

        return Circle()
            .fill(dotColor(isCurrent: isCurrent, isPassed: isPassed))
            .frame(width: isCurrent ? 10 : 6, height: isCurrent ? 10 : 6)
            .animation(.spring(response: 0.2), value: currentHole)
    }

    private func dotColor(isCurrent: Bool, isPassed: Bool) -> Color {
        if isCurrent { return Color.springGreenPrimary }
        if isPassed { return Color.springGreenSecondary.opacity(0.7) }
        return Color.springBorder
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        HoleProgress(currentHole: 5, totalHoles: 18)
        HoleProgress(currentHole: 12, totalHoles: 18)
        HoleProgress(currentHole: 1, totalHoles: 9)
    }
    .padding()
}
#endif
