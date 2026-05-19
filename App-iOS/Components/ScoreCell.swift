import SwiftUI
import Shared

// MARK: - ScoreCell
// iOS F4 스코어카드 그리드 셀 (11-COMPONENTS §3, 12-SCREENS D-1)
// split9x2 단일 변형: 탭 +1 / 길게 누르기 -1 / par-diff 5단계 모양 마커
// 14-ACCESSIBILITY §7: par-diff 이중 부호화 (색상 + 모양)

public struct ScoreCell: View {

    // MARK: Props

    public let count: Int
    public let category: ScoreCategory
    public let isCurrentHole: Bool
    /// 접근성용 홀 번호
    public let holeNumber: Int
    /// 접근성용 플레이어 이름
    public let playerName: String
    /// 접근성용 par
    public let par: Int

    public let onTap: () -> Void
    public let onLongPress: () -> Void
    /// true이면 편집 hint(우하단 - 아이콘) + contextMenu 활성. false면 깔끔한 read-only.
    public let interactive: Bool

    // MARK: Init

    public init(
        count: Int,
        category: ScoreCategory,
        isCurrentHole: Bool,
        holeNumber: Int,
        playerName: String,
        par: Int,
        interactive: Bool = true,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.count = count
        self.category = category
        self.isCurrentHole = isCurrentHole
        self.holeNumber = holeNumber
        self.playerName = playerName
        self.par = par
        self.interactive = interactive
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    // MARK: Body

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // par 대비 색상 배경
            cellBackground

            // 타수 숫자
            Text(count > 0 ? "\(count)" : "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.springTextPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // par-diff 모양 마커 (14-ACCESSIBILITY §7 — 셀 높이 30% 이내 우상단)
            if let symbol = parDiff.shapeSymbol, count > 0 {
                Text(symbol)
                    .font(.system(size: 7))
                    .foregroundStyle(markerColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 2)
                    .padding(.trailing, 2)
            }

            // count > 0이면서 interactive일 때만 우하단 ⊖ 편집 hint (read-only 시 숨김)
            if count > 0 && interactive {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.springTextSecondary.opacity(0.45))
                    .padding(.bottom, 1)
                    .padding(.trailing, 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isCurrentHole ? Color.springGreenPrimary : Color.clear,
                        lineWidth: isCurrentHole ? 2 : 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { if interactive { onTap() } }
        .onLongPressGesture(minimumDuration: 0.4) { if interactive { onLongPress() } }
        .contextMenu {
            if interactive && count > 0 {
                Button {
                    onLongPress()
                } label: {
                    Label("타수 -1", systemImage: "minus.circle")
                }
            }
        }
        // 14-ACCESSIBILITY §2 VoiceOver 4-tuple: 역할, 레이블, 값, 힌트
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(holeNumber)번 홀, \(playerName)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("탭하여 타수 +1, 길게 눌러서 -1")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Background

    @ViewBuilder
    private var cellBackground: some View {
        switch category {
        case .empty:
            Color.clear
        case .eagle:
            // 진한 그린 이중 원 (D-4 ◎)
            Circle()
                .fill(Color.springGreenPrimary)
                .padding(2)
        case .birdie:
            // 연한 그린 원 (● )
            Circle()
                .fill(Color.springGreenSecondary.opacity(0.5))
                .padding(2)
        case .par:
            Color.clear
        case .bogey:
            // 연한 적색 사각형 (■)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.95, green: 0.87, blue: 0.87))
                .padding(2)
        case .doublePlus:
            // 진한 적색 이중 사각형 (▣)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.95, green: 0.78, blue: 0.78))
                .padding(2)
        }
    }

    // MARK: Helpers

    private var parDiff: ParDiff { ParDiff.from(count: count, par: par) }

    private var markerColor: Color {
        switch category {
        case .eagle, .birdie: return Color.springTextPrimary.opacity(0.6)
        case .bogey, .doublePlus: return Color(red: 0.6, green: 0.1, blue: 0.1).opacity(0.7)
        default: return Color.springTextSecondary
        }
    }

    private var accessibilityValue: String {
        guard count > 0 else { return "미입력" }
        return "\(count)타, \(parDiff.voiceOverTerm)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 4) {
        ScoreCell(count: 0, category: .empty, isCurrentHole: false, holeNumber: 1, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        ScoreCell(count: 2, category: .eagle, isCurrentHole: false, holeNumber: 2, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        ScoreCell(count: 3, category: .birdie, isCurrentHole: true, holeNumber: 3, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        ScoreCell(count: 4, category: .par, isCurrentHole: false, holeNumber: 4, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        ScoreCell(count: 5, category: .bogey, isCurrentHole: false, holeNumber: 5, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        ScoreCell(count: 7, category: .doublePlus, isCurrentHole: false, holeNumber: 6, playerName: "나", par: 4, onTap: {}, onLongPress: {})
    }
    .padding()
}
#endif
