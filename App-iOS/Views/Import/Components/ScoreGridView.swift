import SwiftUI
import Shared

// MARK: - ScoreGridView
// 9홀 + TOTAL = 10셀 고정 그리드 (가로 스크롤 없음).
// section: 이 섹션의 홀 offset 및 par 정보
// parRow: nil = 미인식 → "?" 표시
// playerRow: PAR 대비 상대값 배열 (nil = 미인식)
// isParRow: PAR 행 여부 (편집 가능하지만 연한 회색 배경 유지)
// activeCellIndex: 현재 선택된 홀 인덱스 (0-based within section)
// onCellTap: 셀 탭 콜백 (holeIndexInSection)

struct ScoreGridView: View {
    let section: ImportSectionDisplay
    let isParRow: Bool
    let activeCellIndex: Int?
    let onCellTap: ((Int) -> Void)?

    var body: some View {
        // GeometryReader로 가용 폭 측정 후 10분할
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / 10
            HStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { holeIdx in
                    ImportScoreCell(
                        holeLabel: "\(section.holeOffset + holeIdx + 1)",
                        value: cellValue(at: holeIdx),
                        scoreDiff: scoreDiff(at: holeIdx),
                        isReadonly: isParRow,
                        isActive: activeCellIndex == holeIdx,
                        isSuspect: !isParRow && isSuspect(at: holeIdx)
                    )
                    .frame(width: cellWidth)
                    .onTapGesture {
                        onCellTap?(holeIdx)
                    }
                }

                // TOTAL 셀 — diff 도형 미적용 (합계)
                ImportScoreCell(
                    holeLabel: "TOT",
                    value: totalDisplayValue,
                    scoreDiff: nil,
                    isReadonly: isParRow,
                    isActive: false,
                    isSuspect: false,
                    isTotal: true,
                    isPartial: !isParRow && hasNilCell
                )
                .frame(width: cellWidth * 1)
            }
        }
        .frame(height: 52)
    }

    // MARK: Helpers

    private func cellValue(at holeIdx: Int) -> String? {
        if isParRow {
            return section.parRow[safe: holeIdx].flatMap { $0 }.map { "\($0)" }
        } else {
            guard let relArr = section.playerScores else { return nil }
            guard let rel = relArr[safe: holeIdx] else { return nil }
            guard let value = rel else { return nil }
            // 상대값 그대로 표시 — 사용자가 카드 표기와 직접 대조 가능
            return value >= 0 ? "+\(value)" : "\(value)"
        }
    }

    /// player 행 셀의 ScoreDiff 분류. PAR 행 / TOT / nil 값이면 nil 반환.
    private func scoreDiff(at holeIdx: Int) -> ScoreDiff? {
        guard !isParRow else { return nil }
        guard let relArr = section.playerScores else { return nil }
        guard let maybeRel = relArr[safe: holeIdx], let rel = maybeRel else { return nil }
        return ScoreDiff.classify(diff: rel)
    }

    private func isSuspect(at holeIdx: Int) -> Bool {
        guard let relArr = section.playerScores else { return false }
        // nil 값이면 suspect
        if let maybeRel = relArr[safe: holeIdx] {
            return maybeRel == nil
        }
        return true
    }

    /// player 행에서 nil 셀이 있는지 여부 (PAR 행은 적용 안 함)
    private var hasNilCell: Bool {
        guard let relArr = section.playerScores else { return false }
        return relArr.contains(nil)
    }

    private var totalDisplayValue: String? {
        if isParRow {
            let sum = section.parRow.compactMap { $0 }.reduce(0, +)
            return sum > 0 ? "\(sum)" : nil
        } else {
            // player 행 TOT: 절대 타수 표시.
            // PlayerTotalBadge에서 "+18 · 54타" 형태로 상대값이 이미 표시되므로
            // 그리드 TOT 셀은 절대값만 보여 혼선을 줄임.
            guard let relArr = section.playerScores else { return nil }
            let absSum = relArr.enumerated().reduce(0) { acc, item in
                let (holeIdx, rel) = item
                let par: Int = section.parRow.indices.contains(holeIdx) ? (section.parRow[holeIdx] ?? 4) : 4
                let absVal: Int = rel.map { par + $0 } ?? par
                return acc + absVal
            }
            // nil 셀이 있으면 "*" 부착해 불완전 합계임을 표시
            return hasNilCell ? "\(absSum)*" : "\(absSum)"
        }
    }
}

// MARK: - ScoreCell

private struct ImportScoreCell: View {
    let holeLabel: String
    let value: String?
    /// nil = PAR행 / TOT 셀 / 미인식 셀 — 도형 미적용
    let scoreDiff: ScoreDiff?
    let isReadonly: Bool
    let isActive: Bool
    let isSuspect: Bool
    var isTotal: Bool = false
    /// TOT 셀에서 nil 셀이 포함된 불완전 합계임을 표시
    var isPartial: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // 1) 배경
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)

            // 2) 도형 레이어 (player 행 + 값 있을 때만)
            if let diff = scoreDiff, value != nil {
                diffShapeLayer(diff)
            }

            // 3) 숫자 텍스트
            VStack(spacing: 2) {
                Text(holeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(isTotal ? Color.accentColor : .secondary)
                    .lineLimit(1)

                Text(displayValue)
                    .font(.system(size: isTotal ? 13 : 14, weight: .bold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            // 4) active / suspect 외곽선
            RoundedRectangle(cornerRadius: 6)
                .stroke(outlineColor, lineWidth: outlineWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(1.5)
    }

    // MARK: Diff Shape Layer

    @ViewBuilder
    private func diffShapeLayer(_ diff: ScoreDiff) -> some View {
        let size: CGFloat = 36 // 셀 내부 도형 기준 크기 (padding 고려)
        switch diff {
        case .birdie:
            // 버디 이하: terracotta 단일 원
            Circle()
                .strokeBorder(scoreRed, lineWidth: 1.2)
                .frame(width: size - 4, height: size - 4)
        case .par:
            EmptyView()
        case .bogey:
            // 보기: mustard 사각형 (import 뷰는 단일 사각 유지)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(scoreBlue, lineWidth: 1.2)
                .frame(width: size - 4, height: size - 4)
        case .double:
            // 더블+: 이중 사각형 (import 뷰는 구 스타일 유지)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(scoreBlue, lineWidth: 1.2)
                    .frame(width: size - 2, height: size - 2)
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(scoreBlue, lineWidth: 1.2)
                    .frame(width: size - 10, height: size - 10)
            }
        }
    }

    // MARK: Colors

    private var scoreRed: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.271, blue: 0.227)
            : Color(red: 0.773, green: 0.157, blue: 0.157)
    }

    private var scoreBlue: Color {
        colorScheme == .dark
            ? Color(red: 0.4, green: 0.6, blue: 1.0)
            : Color(red: 0.082, green: 0.396, blue: 0.753)
    }

    private var displayValue: String {
        value ?? "?"
    }

    private var textColor: Color {
        if value == nil { return .red }
        if isPartial { return .secondary }
        if isReadonly { return Color(.systemGray) }
        return .primary
    }

    private var backgroundColor: Color {
        if isActive { return Color.accentColor.opacity(0.12) }
        if isTotal && !isPartial { return Color.accentColor.opacity(0.08) }
        if isPartial { return Color(.systemGray5) }
        // suspect: 외곽선으로 표시 (배경 오버라이드 없음 — 도형 색과 구분)
        if isReadonly { return Color(.systemGray6) }
        return Color(.systemGray6).opacity(0.5)
    }

    // MARK: Outline

    private var outlineColor: Color {
        if isActive { return Color.accentColor }
        if isSuspect && !isReadonly { return Color.red.opacity(0.6) }
        return Color.clear
    }

    private var outlineWidth: CGFloat {
        if isActive { return 1.5 }
        if isSuspect && !isReadonly { return 1.2 }
        return 0
    }
}

// MARK: - ImportSectionDisplay

/// ScoreGridView에 전달되는 데이터 뷰 모델 (PAR 행 / 선수 행 공용)
struct ImportSectionDisplay {
    let holeOffset: Int
    let parRow: [Int?]           // 절대 par 값 9개
    var playerScores: [Int?]?    // PAR 대비 상대값 9개 (PAR 행이면 nil)
}

// MARK: - Array safe subscript (re-used from Mapper, local alias)
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
