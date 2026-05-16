import Foundation

// MARK: - RoundStatistics
// F9 라운드 통계 헬퍼 (01-SPEC §F9)
// 순수 함수 모음 — SwiftData 없이 [Round] 배열을 받아 통계 집계

// MARK: - RoundStatisticsResult 값 객체

/// 통계 집계 결과. 완료된 라운드만 대상으로 한다 (isFinished == true).
public struct RoundStatisticsResult: Sendable {
    /// 집계 대상 완료 라운드 수
    public let totalRounds: Int

    /// 라운드별 "주인" 플레이어의 총 타수 평균. 완료 라운드가 없으면 nil.
    public let averageScore: Double?

    /// 가장 낮은 총 타수를 기록한 라운드. 없으면 nil.
    public let bestRound: BestRoundInfo?

    /// 최근 5라운드 총 타수 목록 (가장 오래된 순). 없으면 빈 배열.
    public let recentScores: [Int]

    /// 평균 총 타수 - 평균 par (par 데이터 있는 라운드만). 없으면 nil.
    public let averageVsPar: Double?

    public init(
        totalRounds: Int,
        averageScore: Double?,
        bestRound: BestRoundInfo?,
        recentScores: [Int],
        averageVsPar: Double?
    ) {
        self.totalRounds = totalRounds
        self.averageScore = averageScore
        self.bestRound = bestRound
        self.recentScores = recentScores
        self.averageVsPar = averageVsPar
    }
}

/// 베스트 라운드 정보
public struct BestRoundInfo: Sendable {
    /// 라운드 ID (탐색용)
    public let roundId: UUID
    /// 골프장 이름
    public let courseName: String
    /// 라운드 날짜
    public let date: Date
    /// 주인 플레이어의 총 타수
    public let totalScore: Int

    public init(roundId: UUID, courseName: String, date: Date, totalScore: Int) {
        self.roundId = roundId
        self.courseName = courseName
        self.date = date
        self.totalScore = totalScore
    }
}

// MARK: - RoundStatistics 집계 함수

/// 완료된 라운드 배열에서 통계를 집계한다.
/// - Parameter rounds: 전체 라운드 배열 (isFinished 여부 무관하게 전달 가능, 내부에서 필터)
/// - Returns: `RoundStatisticsResult` 값 객체
public func aggregateStatistics(rounds: [Round]) -> RoundStatisticsResult {
    // 완료된 라운드만 대상
    let finished = rounds.filter { $0.isFinished }

    guard !finished.isEmpty else {
        return RoundStatisticsResult(
            totalRounds: 0,
            averageScore: nil,
            bestRound: nil,
            recentScores: [],
            averageVsPar: nil
        )
    }

    // 라운드별 주인 플레이어의 총 타수 계산
    // 주인 플레이어(isOwner == true)의 counts 합산
    let scoredRounds: [(round: Round, score: Int)] = finished.compactMap { round in
        guard let owner = round.playerList.first(where: { $0.isOwner }) else { return nil }
        let total = round.holeList.reduce(0) { sum, hole in
            sum + hole.count(for: owner.id)
        }
        guard total > 0 else { return nil }  // 타수 미입력 라운드는 제외
        return (round, total)
    }

    guard !scoredRounds.isEmpty else {
        return RoundStatisticsResult(
            totalRounds: finished.count,
            averageScore: nil,
            bestRound: nil,
            recentScores: [],
            averageVsPar: nil
        )
    }

    // 평균 타수
    let totalScore = scoredRounds.reduce(0) { $0 + $1.score }
    let averageScore = Double(totalScore) / Double(scoredRounds.count)

    // 베스트 라운드 (최소 타수)
    let best = scoredRounds.min { $0.score < $1.score }
    let bestRoundInfo: BestRoundInfo? = best.map {
        BestRoundInfo(
            roundId: $0.round.id,
            courseName: $0.round.courseName,
            date: $0.round.finishedAt ?? $0.round.date,
            totalScore: $0.score
        )
    }

    // 최근 5라운드 (날짜 오름차순)
    let sorted = scoredRounds.sorted { a, b in
        let dateA = a.round.finishedAt ?? a.round.date
        let dateB = b.round.finishedAt ?? b.round.date
        return dateA < dateB
    }
    let recentScores = Array(sorted.suffix(5).map { $0.score })

    // par 대비 평균 계산
    // 각 라운드의 총 par vs 총 score 차이 평균
    let vsParValues: [Int] = scoredRounds.compactMap { item in
        guard let owner = item.round.playerList.first(where: { $0.isOwner }) else { return nil }
        let totalPar = item.round.holeList.reduce(0) { $0 + $1.par }
        guard totalPar > 0 else { return nil }
        let totalCount = item.round.holeList.reduce(0) { $0 + $1.count(for: owner.id) }
        return totalCount - totalPar
    }
    let averageVsPar: Double? = vsParValues.isEmpty ? nil :
        Double(vsParValues.reduce(0, +)) / Double(vsParValues.count)

    return RoundStatisticsResult(
        totalRounds: finished.count,
        averageScore: averageScore,
        bestRound: bestRoundInfo,
        recentScores: recentScores,
        averageVsPar: averageVsPar
    )
}
