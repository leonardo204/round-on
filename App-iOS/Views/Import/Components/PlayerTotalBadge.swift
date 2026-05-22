import SwiftUI

// MARK: - PlayerTotalBadge
// "+18 · 54타" 형태의 합계 배지.
// relativeSum: PAR 대비 합계 (예: +18)
// absoluteSum: 절대 타수 합 (예: 54)

struct PlayerTotalBadge: View {
    let relativeSum: Int
    let absoluteSum: Int

    private var relativeText: String {
        relativeSum >= 0 ? "+\(relativeSum)" : "\(relativeSum)"
    }

    var body: some View {
        Text("\(relativeText) · \(absoluteSum)타")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
