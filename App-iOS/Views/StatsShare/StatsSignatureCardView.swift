import SwiftUI
import Shared

/// 1080×1080 시그니처 카드 — C안 (스코어카드 모티프).
/// ImageRenderer에 입력되는 view. 배경 흰색, cardKind 별 액센트 컬러 적용.
public struct StatsSignatureCardView: View {
    public let signature: StatsSignature
    public let cardKind: StatsSignatureCardKind
    public let dateISO: String

    public init(
        signature: StatsSignature,
        cardKind: StatsSignatureCardKind,
        dateISO: String
    ) {
        self.signature = signature
        self.cardKind = cardKind
        self.dateISO = dateISO
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
            playerRow
            scoreBlock
            miniStatsSection
            footerRow
        }
        .frame(width: 1080, height: 1080)
        .background(Color(red: 0.984, green: 0.992, blue: 0.984))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - 1. 헤더 행

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text("라운드온")
                .font(.system(size: 42, weight: .heavy))
                .foregroundStyle(Color.houseGreen)
            Spacer()
            tagChip
        }
        .padding(.horizontal, 56)
        .padding(.top, 56)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var tagChip: some View {
        let text = signature.tagText ?? defaultTagText
        Text(text)
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(accentColor)
            .tracking(1.5)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(accentColor.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(0.30), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 2. 골퍼 행

    private var playerRow: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.cardBorder)
                .frame(height: 1)
            HStack(alignment: .center) {
                Text(playerDisplayName)
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(playerMetaText)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 24)
            Rectangle()
                .fill(Color.inkPrimary)
                .frame(height: 2.5)
        }
    }

    // MARK: - 3. 점수 블록

    private var scoreBlock: some View {
        VStack(spacing: 0) {
            // 라벨 줄
            HStack(alignment: .center) {
                Text((signature.scoreBlockLabel ?? "Score").uppercased())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.inkSoft)
                    .tracking(2)
                Spacer()
                Text(scoreBlockSubLabel)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(.horizontal, 56)
            .padding(.top, 36)
            .padding(.bottom, 20)

            Rectangle()
                .fill(Color.cardBorder)
                .frame(height: 1)
                .padding(.horizontal, 56)

            // 큰 숫자 + 단위 + delta pill
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                Text(signature.bigNumber)
                    .font(.system(size: 220, weight: .heavy))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .layoutPriority(1)
                VStack(alignment: .leading, spacing: 8) {
                    if !signature.bigUnit.isEmpty {
                        Text(signature.bigUnit)
                            .font(.system(size: 60, weight: .heavy))
                            .foregroundStyle(Color.inkSoft)
                    }
                    if let delta = signature.deltaText {
                        deltaPill(delta)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 56)
            .padding(.vertical, 28)

            Rectangle()
                .fill(Color.cardBorder)
                .frame(height: 1)
                .padding(.horizontal, 56)
        }
    }

    private func deltaPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 4. 미니 통계 3분할

    @ViewBuilder
    private var miniStatsSection: some View {
        if let stats = signature.miniStats, !stats.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(stats.prefix(3).enumerated()), id: \.offset) { idx, stat in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.cardBorder)
                            .frame(width: 1)
                    }
                    miniStatCell(stat)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 36)
        }
    }

    private func miniStatCell(_ stat: StatsSignatureMiniStat) -> some View {
        VStack(spacing: 8) {
            Text(stat.value)
                .font(.system(size: 50, weight: .heavy))
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(stat.label)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 5. 푸터

    private var footerRow: some View {
        Spacer()
            .frame(minHeight: 0)
            .overlay(
                HStack(alignment: .bottom) {
                    Text(signature.footerLabel)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.inkFaint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "qrcode")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.inkFaint.opacity(0.45))
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 32),
                alignment: .bottom
            )
    }

    // MARK: - 헬퍼

    private var accentColor: Color {
        switch cardKind {
        case .pr:    return Color.scoreBirdie
        case .hcp:   return Color.houseGreen
        case .trend: return Color.accentGreen
        }
    }

    private var defaultTagText: String {
        switch cardKind {
        case .pr:    return "NEW PR"
        case .hcp:   return "HDCP DOWN"
        case .trend: return "IMPROVING"
        }
    }

    private var playerDisplayName: String {
        let name = signature.playerName ?? ""
        return name.isEmpty ? "골퍼" : "\(name)님"
    }

    private var playerMetaText: String {
        signature.metaPrimary ?? formattedDate
    }

    private var scoreBlockSubLabel: String {
        signature.metaSecondary ?? ""
    }

    private var formattedDate: String {
        let iso = ISO8601DateFormatter()
        guard let date = iso.date(from: dateISO) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private var accessibilityLabel: String {
        "\(signature.scoreBlockLabel ?? "Score") \(signature.bigNumber) \(signature.bigUnit)"
    }
}

// MARK: - Previews

#Preview("PR — C안") {
    StatsSignatureCardView(
        signature: StatsSignature(
            headline: "인생 최저타를 갱신했어요",
            bigNumber: "82",
            bigUnit: "타",
            deltaText: "PR -4",
            metaPrimary: "레이크사이드 동코스 · 2026.05.27",
            metaSecondary: "Par 72",
            footerLabel: "골프장 PR · 라운드온 기록",
            playerName: "홍길동",
            miniStats: [
                StatsSignatureMiniStat(value: "+10", label: "Even 대비"),
                StatsSignatureMiniStat(value: "86", label: "이전 PR"),
                StatsSignatureMiniStat(value: "17.1", label: "추정 HDCP"),
            ],
            tagText: "NEW PR",
            scoreBlockLabel: "Total Score"
        ),
        cardKind: .pr,
        dateISO: "2026-05-27T12:00:00Z"
    )
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}

#Preview("HCP — C안") {
    StatsSignatureCardView(
        signature: StatsSignature(
            headline: "핸디캡이 한 단계 내려갔어요",
            bigNumber: "17.1",
            bigUnit: "HDCP",
            deltaText: "▼ 1.2",
            metaPrimary: "USGA 약식 · 2026.05.27 기준",
            metaSecondary: "최근 8R",
            footerLabel: "최근 8R 中 베스트 3R 평균 − 72",
            playerName: "홍길동",
            miniStats: [
                StatsSignatureMiniStat(value: "18.3", label: "한 달 전"),
                StatsSignatureMiniStat(value: "82", label: "PR"),
                StatsSignatureMiniStat(value: "24", label: "총 라운드"),
            ],
            tagText: "HDCP DOWN",
            scoreBlockLabel: "Handicap Index"
        ),
        cardKind: .hcp,
        dateISO: "2026-05-27T12:00:00Z"
    )
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}

#Preview("TREND — C안") {
    StatsSignatureCardView(
        signature: StatsSignature(
            headline: "최근 5라운드 흐름",
            bigNumber: "86.0",
            bigUnit: "타",
            deltaText: "▼ 5",
            metaPrimary: "최근 5R · 2026.05.27 기준",
            metaSecondary: "vs 이전 5R",
            footerLabel: "최근 10R 기준 · 라운드온 추정",
            playerName: "홍길동",
            miniStats: [
                StatsSignatureMiniStat(value: "91.0", label: "이전 5R"),
                StatsSignatureMiniStat(value: "±4", label: "σ"),
                StatsSignatureMiniStat(value: "17.1", label: "추정 HDCP"),
            ],
            tagText: "IMPROVING",
            scoreBlockLabel: "Recent 5R Avg"
        ),
        cardKind: .trend,
        dateISO: "2026-05-27T12:00:00Z"
    )
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}
