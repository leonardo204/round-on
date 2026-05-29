import SwiftUI

// MARK: - ScoreCellView
// ScoreDiff 정의는 ScoreDiff.swift 참조
// viewer.ts CSS 4단계 시각화 이식 (2026-05-24)
// birdie: terracotta #c0573a 원형 strokeBorder 1.6pt
// par:    도형 없음, 숫자 houseGreen #1c6b43
// bogey:  mustard #d6a93b — radius9 사각, strokeBorder 1.6pt(opacity 0.55), fill opacity 0.08
// double: blueDouble #1e40af — 동심 이중 사각 (inner 1pt + outer 1pt, gap 3pt)

public struct ScoreCellView: View {

    // MARK: Props

    public let strokes: Int
    public let par: Int
    /// 셀 표시 크기 (기본 32×32)
    public let cellSize: CGFloat
    /// 접근성용 홀 번호
    public let holeNumber: Int
    /// 접근성용 플레이어 이름
    public let playerName: String
    /// true이면 상대값(over-par) 표시: E / +N / -N
    /// false(기본)이면 절대 타수 표시: N
    /// ※ 도형(birdie/bogey/double 시각화)은 항상 strokes-par 기준으로 유지
    public let showRelative: Bool

    // MARK: Init

    public init(
        strokes: Int,
        par: Int,
        cellSize: CGFloat = 32,
        holeNumber: Int = 0,
        playerName: String = "",
        showRelative: Bool = false
    ) {
        self.strokes = strokes
        self.par = par
        self.cellSize = cellSize
        self.holeNumber = holeNumber
        self.playerName = playerName
        self.showRelative = showRelative
    }

    // MARK: Computed

    private var diff: ScoreDiff { ScoreDiff.classify(strokes: strokes, par: par) }

    @Environment(\.colorScheme) private var colorScheme

    // MARK: Body

    public var body: some View {
        ZStack {
            shapeLayer
            numberLabel
        }
        .frame(width: cellSize, height: cellSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Number Label

    /// 표시 텍스트: showRelative=true이면 over-par(E/+N/-N), 아니면 절대 타수
    private var displayText: String {
        guard strokes > 0 else { return "" }
        if showRelative {
            let d = strokes - par
            if d == 0 { return "E" }
            return d > 0 ? "+\(d)" : "\(d)"
        }
        return "\(strokes)"
    }

    @ViewBuilder
    private var numberLabel: some View {
        if strokes > 0 {
            Text(displayText)
                .font(.system(size: fontSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(numberForeground)
        }
    }

    private var fontSize: CGFloat { cellSize * 0.40 }

    private var numberForeground: Color {
        switch diff {
        case .birdie: return Color.scoreBirdie
        case .par:    return Color.scoreParGreen
        case .bogey:  return Color.scoreBogey
        case .double: return Color.scoreDouble
        }
    }

    // MARK: Shape Layer

    @ViewBuilder
    private var shapeLayer: some View {
        switch diff {
        case .birdie:
            birdieShape
        case .par:
            EmptyView()
        case .bogey:
            bogeyShape
        case .double:
            doubleShape
        }
    }

    // MARK: Birdie — terracotta 단일 원 strokeBorder 1.6pt

    private var birdieShape: some View {
        Circle()
            .strokeBorder(Color.scoreBirdie, lineWidth: 1.6)
            .frame(width: cellSize - 4, height: cellSize - 4)
    }

    // MARK: Bogey — mustard 사각(radius 9) strokeBorder 1.6pt + 옅은 fill

    private var bogeyShape: some View {
        RoundedRectangle(cornerRadius: min(9, cellSize * 0.28))
            .fill(Color.scoreBogey.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: min(9, cellSize * 0.28))
                    .strokeBorder(Color.scoreBogey.opacity(0.55), lineWidth: 1.6)
            )
            .frame(width: cellSize - 4, height: cellSize - 4)
    }

    // MARK: Double — blueDouble 동심 이중 사각 (inner + outer, gap 3pt)

    private var doubleShape: some View {
        let outerRadius = min(6.0, cellSize * 0.19)
        let innerRadius = max(2.0, outerRadius - 2.0)
        let gap: CGFloat = 3
        return ZStack {
            // outer
            RoundedRectangle(cornerRadius: outerRadius)
                .strokeBorder(Color.scoreDouble, lineWidth: 1)
                .frame(width: cellSize - 2, height: cellSize - 2)
            // inner (gap 3pt 안쪽)
            RoundedRectangle(cornerRadius: innerRadius)
                .strokeBorder(Color.scoreDouble, lineWidth: 1)
                .frame(width: cellSize - 2 - gap * 2, height: cellSize - 2 - gap * 2)
        }
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        let holePart = holeNumber > 0 ? "\(holeNumber)번 홀" : "홀"
        let playerPart = playerName.isEmpty ? "" : " \(playerName)"
        guard strokes > 0 else { return "\(holePart)\(playerPart) 미입력" }
        return "\(holePart)\(playerPart) \(diff.voiceOverTerm) \(strokes)타"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ScoreCellView — 4단계") {
    VStack(spacing: 16) {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                ScoreCellView(strokes: 3, par: 4, cellSize: 36, holeNumber: 1, playerName: "나")
                Text("Birdie").font(.caption2)
            }
            VStack(spacing: 4) {
                ScoreCellView(strokes: 4, par: 4, cellSize: 36, holeNumber: 2, playerName: "나")
                Text("Par").font(.caption2)
            }
            VStack(spacing: 4) {
                ScoreCellView(strokes: 5, par: 4, cellSize: 36, holeNumber: 3, playerName: "나")
                Text("Bogey").font(.caption2)
            }
            VStack(spacing: 4) {
                ScoreCellView(strokes: 6, par: 4, cellSize: 36, holeNumber: 4, playerName: "나")
                Text("Double+").font(.caption2)
            }
        }
        .padding()
        Text("HIO/Eagle → Birdie, Triple → Double")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
#endif
