import Foundation

/// RoundStatisticsResult + RegionStats + 닉네임 → StatsSharePayload 변환.
/// PII 가드: 화이트리스트 방식. 좌표는 RegionCentroidLUT만 사용.
public enum StatsSharePayloadBuilder {

    public static func build(
        cardKind: StatsSignatureCardKind,
        stats: RoundStatisticsResult,
        regionStats: [RegionStats],
        rawDisplayName: String,
        bestRoundCourseName: String? = nil,
        bestRoundDate: Date? = nil,
        bestRoundTotalScore: Int? = nil,
        bestRoundIsPR: Bool = false,
        roundLocations: [RoundLocation] = [],
        nowISO: String = ISO8601DateFormatter().string(from: Date())
    ) -> StatsSharePayload {
        // 닉네임 마스킹
        let displayName = maskedDisplayName(rawDisplayName)

        // signature
        let signature = buildSignature(
            kind: cardKind,
            stats: stats,
            bestRoundCourseName: bestRoundCourseName,
            bestRoundDate: bestRoundDate,
            bestRoundTotalScore: bestRoundTotalScore,
            bestRoundIsPR: bestRoundIsPR,
            displayName: displayName
        )

        // summary
        let summary = StatsSummary(
            totalRounds: stats.totalRounds,
            recentAverageScore: stats.recentAverageScore,
            averageVsPar: stats.averageVsPar
        )

        // distribution
        let distribution = StatsDistribution(
            eagleOrBetter: stats.scoreDistribution.eagleOrBetter,
            birdie: stats.scoreDistribution.birdie,
            par: stats.scoreDistribution.par,
            bogey: stats.scoreDistribution.bogey,
            doubleOrWorse: stats.scoreDistribution.doubleOrWorse,
            totalHoles: stats.scoreDistribution.totalHoles,
            comment: distributionComment(stats.scoreDistribution)
        )

        // par averages
        let parAverages: [StatsParAverage] = stats.parTypeAverages.map { pta in
            StatsParAverage(
                par: pta.par,
                averageScore: pta.averageScore,
                vsPar: pta.vsPar,
                holeCount: pta.holeCount
            )
        }

        // trend
        let trend: StatsTrend? = stats.recentTrend.map { rt in
            let dirLabel: String
            switch rt.direction {
            case .improving: dirLabel = "↘ 좋아지는 중"
            case .worsening: dirLabel = "↗ 어려워지는 중"
            case .stable:    dirLabel = "→ 비슷한 흐름"
            }
            let sigmaText: String? = stats.consistencySigma.map { sigma in
                "평균 ±\(Int(sigma.rounded()))타"
            }
            return StatsTrend(
                direction: rt.direction.rawValue,
                directionLabel: dirLabel,
                previousAverage: rt.previousAverage,
                currentAverage: rt.currentAverage,
                delta: rt.delta,
                scoreTrend: stats.scoreTrend,
                sigmaText: sigmaText
            )
        }

        // best round
        let isoFormatter = ISO8601DateFormatter()
        let bestRound: StatsBestRound? = {
            // 파라미터 우선, 없으면 stats.bestRound에서
            let name = bestRoundCourseName ?? stats.bestRound?.courseName
            let date = bestRoundDate ?? stats.bestRound?.date
            let score = bestRoundTotalScore ?? stats.bestRound?.totalScore
            guard let courseName = name, let roundDate = date, let totalScore = score else { return nil }
            return StatsBestRound(
                courseName: courseName,
                dateISO: isoFormatter.string(from: roundDate),
                totalScore: totalScore,
                isPersonalRecord: bestRoundIsPR || stats.isPersonalRecord
            )
        }()

        // regions — centroid LUT 매핑, 매칭 실패 시 제외
        let regions: [StatsRegionShare] = regionStats.compactMap { rs in
            guard let c = RegionCentroidLUT.centroid(for: rs.regionKey) else { return nil }
            return StatsRegionShare(
                displayName: rs.displayName,
                roundCount: rs.roundCount,
                centroidLat: c.lat,
                centroidLng: c.lng
            )
        }

        // recent rounds — courseName만 (라운드ID/coords/owner 제외)
        let recentRounds: [StatsRecentEntryShare] = stats.recentEntries.map { entry in
            StatsRecentEntryShare(
                courseName: entry.courseName,
                dateISO: isoFormatter.string(from: entry.date),
                totalScore: entry.totalScore,
                vsPar: entry.vsPar,
                holeCount: entry.holeCount
            )
        }

        let periodLabel = "최근 \(stats.totalRounds)R"

        // roundLocations — 골프장별 정확한 위치 (명시 공유 동의, 33-SECURITY §7.7)
        // 빈 배열이면 nil로 저장 (기존 region centroid 폴백)
        let mappedRoundLocations: [StatsRoundLocationShare]? = roundLocations.isEmpty ? nil :
            roundLocations.map { loc in
                StatsRoundLocationShare(
                    courseName: loc.courseName,
                    lat: loc.lat,
                    lng: loc.lng,
                    roundCount: loc.roundCount
                )
            }

        return StatsSharePayload(
            cardKind: cardKind,
            signature: signature,
            summary: summary,
            scoreDistribution: distribution,
            parAverages: parAverages,
            trend: trend,
            bestRound: bestRound,
            regions: regions,
            recentRounds: recentRounds,
            displayName: displayName,
            createdAtISO: nowISO,
            periodLabel: periodLabel,
            roundLocations: mappedRoundLocations
        )
    }

    // MARK: - 닉네임 PII 마스킹
    /// 33-SECURITY §7 정규식 + 단순 규칙. 빈 입력 → "익명".
    static func maskedDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "익명" }

        // 전화/이메일/주민번호/카드번호 등 PII 패턴 발견 시 첫글자 + ***
        let patterns: [String] = [
            #"\d{2,3}-?\d{3,4}-?\d{4}"#,           // 010-1234-5678
            #"[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}"#,   // email
            #"\d{6}-?\d{7}"#,                       // 주민번호
            #"\d{4}-?\d{4}-?\d{4}-?\d{4}"#          // 카드
        ]
        for p in patterns {
            if trimmed.range(of: p, options: .regularExpression) != nil {
                let first = trimmed.prefix(1)
                return "\(first)***"
            }
        }

        // 길이 제한 24자
        return String(trimmed.prefix(24))
    }

    // MARK: - 카드별 signature 생성

    private static func buildSignature(
        kind: StatsSignatureCardKind,
        stats: RoundStatisticsResult,
        bestRoundCourseName: String?,
        bestRoundDate: Date?,
        bestRoundTotalScore: Int?,
        bestRoundIsPR: Bool,
        displayName: String = ""
    ) -> StatsSignature {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ko_KR")
        displayFormatter.dateFormat = "yyyy.MM.dd"
        let todayStr = displayFormatter.string(from: Date())

        switch kind {
        case .pr:
            let score = bestRoundTotalScore ?? stats.bestRound?.totalScore ?? 0
            let courseName = bestRoundCourseName ?? stats.bestRound?.courseName ?? ""
            let dateStr: String = {
                if let d = bestRoundDate ?? stats.bestRound?.date {
                    return displayFormatter.string(from: d)
                }
                return todayStr
            }()
            let hcpText: String = stats.handicapEstimate.map { h in
                String(format: "%.1f", h.index)
            } ?? ""
            let footerLabel = hcpText.isEmpty
                ? "개인 PR · 라운드온"
                : "골프장 PR · 라운드온 기록"

            // 이전 PR (bestRound 이전의 최고 기록이 없으면 현재 스코어+4 추정)
            let previousPR: Int = {
                let sorted = stats.recentEntries
                    .filter { $0.totalScore > score }
                    .map(\.totalScore)
                    .sorted()
                return sorted.first ?? (score + 4)
            }()
            let delta = score - previousPR  // 음수 = 개선

            // vs par (par 72 기준)
            let vsParInt = score - 72
            let vsParText: String = vsParInt >= 0 ? "+\(vsParInt)" : "\(vsParInt)"

            // delta pill 텍스트
            let deltaText: String = "PR \(delta >= 0 ? "+" : "")\(delta)"

            // mini stats
            var mini: [StatsSignatureMiniStat] = [
                StatsSignatureMiniStat(value: vsParText, label: "Even 대비"),
                StatsSignatureMiniStat(value: "\(previousPR)", label: "이전 PR"),
            ]
            if let hcp = stats.handicapEstimate {
                mini.append(StatsSignatureMiniStat(
                    value: String(format: "%.1f", hcp.index),
                    label: "추정 HDCP"
                ))
            }

            return StatsSignature(
                headline: "인생 최저타를 갱신했어요",
                bigNumber: "\(score)",
                bigUnit: "타",
                deltaText: deltaText,
                metaPrimary: courseName.isEmpty ? nil : "\(courseName) · \(dateStr)",
                metaSecondary: "Par 72",
                footerLabel: footerLabel,
                playerName: displayName.isEmpty ? nil : displayName,
                miniStats: mini,
                tagText: "NEW PR",
                scoreBlockLabel: "Total Score"
            )

        case .hcp:
            let hcp = stats.handicapEstimate
            let indexStr: String = hcp.map { String(format: "%.1f", $0.index) } ?? "—"
            let deltaText: String? = hcp?.delta.map { d in
                d < 0 ? String(format: "▼ %.1f", abs(d)) : String(format: "▲ %.1f", d)
            } ?? nil

            // 한 달 전 index (delta 역산)
            let prevIndexStr: String = hcp.map { h -> String in
                let prev = h.index - (h.delta ?? 0)
                return String(format: "%.1f", prev)
            } ?? "—"

            // PR (베스트 라운드 점수)
            let prScore: Int = stats.bestRound?.totalScore ?? 0
            let prStr = prScore > 0 ? "\(prScore)" : "—"

            // 총 라운드
            let totalR = stats.totalRounds

            var mini: [StatsSignatureMiniStat] = [
                StatsSignatureMiniStat(value: prevIndexStr, label: "한 달 전"),
                StatsSignatureMiniStat(value: prStr, label: "PR"),
                StatsSignatureMiniStat(value: "\(totalR)", label: "총 라운드"),
            ]

            return StatsSignature(
                headline: "핸디캡이 한 단계 내려갔어요",
                bigNumber: indexStr,
                bigUnit: "HDCP",
                deltaText: deltaText,
                metaPrimary: "USGA 약식 · \(todayStr) 기준",
                metaSecondary: "최근 8R",
                footerLabel: "최근 8R 中 베스트 3R 평균 − 72",
                playerName: displayName.isEmpty ? nil : displayName,
                miniStats: mini,
                tagText: "HDCP DOWN",
                scoreBlockLabel: "Handicap Index"
            )

        case .trend:
            let trend = stats.recentTrend
            let prev = trend.map { Int($0.previousAverage.rounded()) } ?? 0
            let curr = trend.map { Int($0.currentAverage.rounded()) } ?? 0
            let delta = trend?.delta ?? 0

            let deltaText: String = delta != 0
                ? (delta < 0 ? "▼ \(abs(delta))" : "▲ \(delta)")
                : "±0"

            // 이전 5R 평균
            let prevAvgStr = prev > 0 ? "\(prev).0" : "—"

            // sigma
            let sigmaStr: String = stats.consistencySigma.map { sigma in
                "±\(Int(sigma.rounded()))"
            } ?? "—"

            var mini: [StatsSignatureMiniStat] = [
                StatsSignatureMiniStat(value: prevAvgStr, label: "이전 5R"),
                StatsSignatureMiniStat(value: sigmaStr, label: "기복"),
            ]
            if let hcp = stats.handicapEstimate {
                mini.append(StatsSignatureMiniStat(
                    value: String(format: "%.1f", hcp.index),
                    label: "추정 HDCP"
                ))
            }

            // C안: bigNumber는 최근 5R 평균 단일 숫자
            let currAvgStr = curr > 0 ? "\(curr).0" : "—"

            return StatsSignature(
                headline: "최근 5라운드 흐름",
                bigNumber: currAvgStr,
                bigUnit: "타",
                deltaText: deltaText,
                metaPrimary: "최근 5R · \(todayStr) 기준",
                metaSecondary: "vs 이전 5R",
                footerLabel: "최근 10R 기준 · 라운드온 추정",
                playerName: displayName.isEmpty ? nil : displayName,
                miniStats: mini,
                tagText: "IMPROVING",
                scoreBlockLabel: "Recent 5R Avg"
            )
        }
    }

    // MARK: - 분포 코멘트

    static func distributionComment(_ d: ScoreDistribution) -> String {
        guard d.totalHoles > 0 else { return "데이터를 모으는 중이에요" }
        let parPct = d.parPct * 100
        let bogeyPct = d.bogeyPct * 100
        let doublePct = d.doublePct * 100
        let doubleN = d.doubleOrWorse

        if parPct >= 40 {
            return "파 골퍼 — 안정적이에요. 버디 사냥 가즈아 👀"
        } else if bogeyPct >= 35 {
            return "보기 골퍼 — 더블+ \(Int(doublePct.rounded()))% 만 줄이면 평균 -3타 가능"
        } else if doublePct >= 30 {
            return "더블이 잦아요 — 한 홀 -1타만 줄여도 큰 변화 (더블 \(doubleN)홀)"
        } else {
            return "이번 분기 분포 확인 — 약점 파악 먼저"
        }
    }
}
