import SwiftUI
import Shared

// MARK: - ScoreCell
// iOS F4 스코어카드 그리드 셀 (11-COMPONENTS §3, 12-SCREENS D-1)
// split9x2 단일 변형: 탭 +1 / 길게 누르기 -1
// 14-ACCESSIBILITY §7: par-diff 표준 골프 도형 시각화 (ScoreDiffShape.swift)
// 시각화: Albatross/HIO=이중원, Eagle=이중원, Birdie=단일원 (빨강)
//         Par=도형 없음, Bogey=단일사각, DoubleBogey=이중사각 (남색)
//         Triple+=이중사각+채워진 빨강 배경

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
            // 표준 골프 시각화: ScoreDiffShape 도형 + 숫자
            ScoreCellView(
                strokes: count,
                par: par,
                cellSize: 32,
                holeNumber: holeNumber,
                playerName: playerName
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true) // 외부 accessibilityElement가 처리

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

    // MARK: Helpers

    private var parDiff: ParDiff { ParDiff.from(count: count, par: par) }

    private var accessibilityValue: String {
        guard count > 0 else { return "미입력" }
        return "\(count)타, \(parDiff.voiceOverTerm)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ScoreCell — 표준 골프 시각화") {
    VStack(spacing: 8) {
        HStack(spacing: 4) {
            // HIO/Albatross (par4에서 1타 = diff -3)
            ScoreCell(count: 1, category: .eagle, isCurrentHole: false, holeNumber: 1, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Eagle (diff -2)
            ScoreCell(count: 2, category: .eagle, isCurrentHole: false, holeNumber: 2, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Birdie (diff -1)
            ScoreCell(count: 3, category: .birdie, isCurrentHole: true, holeNumber: 3, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Par (diff 0)
            ScoreCell(count: 4, category: .par, isCurrentHole: false, holeNumber: 4, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Bogey (diff +1)
            ScoreCell(count: 5, category: .bogey, isCurrentHole: false, holeNumber: 5, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Double Bogey (diff +2)
            ScoreCell(count: 6, category: .doublePlus, isCurrentHole: false, holeNumber: 6, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            // Triple+ (diff +3)
            ScoreCell(count: 7, category: .doublePlus, isCurrentHole: false, holeNumber: 7, playerName: "나", par: 4, onTap: {}, onLongPress: {})
        }
        .padding()
        .background(Color.gray.opacity(0.1))

        // 미입력
        HStack {
            ScoreCell(count: 0, category: .empty, isCurrentHole: false, holeNumber: 8, playerName: "나", par: 4, onTap: {}, onLongPress: {})
            Spacer()
        }
        .padding(.horizontal)
    }
}
#endif
