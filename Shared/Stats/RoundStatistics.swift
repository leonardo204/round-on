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

    /// 최근 5라운드 엔트리 (코스명·날짜·점수 묶음). 가장 최근이 인덱스 0. 없으면 빈 배열.
    public let recentEntries: [RecentRoundEntry]

    /// 최근 5라운드 평균 타수. 데이터 없으면 nil.
    public let recentAverageScore: Double?

    /// 평균 총 타수 - 평균 par (par 데이터 있는 라운드만). 없으면 nil.
    public let averageVsPar: Double?

    // MARK: - 신규 필드 (stats v2)

    /// 스코어 분포 (이글/버디/파/보기/더블+)
    public let scoreDistribution: ScoreDistribution

    /// USGA 약식 핸디캡 추정. 완료 라운드 3개 미만이면 nil.
    public let handicapEstimate: HandicapEstimate?

    /// Par 3/4/5 별 평균 타수. Par 홀이 없으면 빈 배열.
    public let parTypeAverages: [ParTypeAverage]

    /// 최근 10R 총타수의 모표준편차. 라운드 3개 미만이면 nil.
    public let consistencySigma: Double?

    /// 최근 10R 총타수 (오래된→최근 순)
    public let scoreTrend: [Int]

    /// 베스트 라운드가 해당 코스에서 본인 PR인지 (courseId 기준 최저타수 == best.totalScore)
    public let isPersonalRecord: Bool

    /// 최근 추세 (최근 10R 기준, 6R 미만이면 nil)
    public let recentTrend: RecentTrend?

    public init(
        totalRounds: Int,
        averageScore: Double?,
        bestRound: BestRoundInfo?,
        recentScores: [Int],
        averageVsPar: Double?,
        recentEntries: [RecentRoundEntry] = [],
        recentAverageScore: Double? = nil,
        scoreDistribution: ScoreDistribution = ScoreDistribution(eagleOrBetter: 0, birdie: 0, par: 0, bogey: 0, doubleOrWorse: 0, totalHoles: 0),
        handicapEstimate: HandicapEstimate? = nil,
        parTypeAverages: [ParTypeAverage] = [],
        consistencySigma: Double? = nil,
        scoreTrend: [Int] = [],
        isPersonalRecord: Bool = false,
        recentTrend: RecentTrend? = nil
    ) {
        self.totalRounds = totalRounds
        self.averageScore = averageScore
        self.bestRound = bestRound
        self.recentScores = recentScores
        self.recentEntries = recentEntries
        self.recentAverageScore = recentAverageScore
        self.averageVsPar = averageVsPar
        self.scoreDistribution = scoreDistribution
        self.handicapEstimate = handicapEstimate
        self.parTypeAverages = parTypeAverages
        self.consistencySigma = consistencySigma
        self.scoreTrend = scoreTrend
        self.isPersonalRecord = isPersonalRecord
        self.recentTrend = recentTrend
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
    /// 코스 ID (PR 판정에 사용)
    public let courseId: String

    public init(roundId: UUID, courseName: String, date: Date, totalScore: Int, courseId: String = "") {
        self.roundId = roundId
        self.courseName = courseName
        self.date = date
        self.totalScore = totalScore
        self.courseId = courseId
    }
}

/// 최근 라운드 엔트리 — 코스명·날짜·점수를 한 묶음으로 제공하여 UI에서 인덱스 매핑 오류를 방지
public struct RecentRoundEntry: Sendable {
    public let roundId: UUID
    public let courseName: String
    public let date: Date
    public let totalScore: Int
    /// 코스 총 par. 0이면 par 정보 없음.
    public let parTotal: Int
    /// 9 또는 18 등 홀 수.
    public let holeCount: Int

    public init(roundId: UUID, courseName: String, date: Date, totalScore: Int, parTotal: Int, holeCount: Int) {
        self.roundId = roundId
        self.courseName = courseName
        self.date = date
        self.totalScore = totalScore
        self.parTotal = parTotal
        self.holeCount = holeCount
    }

    /// vs par. parTotal == 0이면 nil.
    public var vsPar: Int? { parTotal > 0 ? totalScore - parTotal : nil }
}

// MARK: - 신규 구조체들

/// 스코어 분포 (홀 단위 집계)
public struct ScoreDistribution: Sendable {
    /// 이글 이하 (hole.count - hole.par ≤ -2)
    public let eagleOrBetter: Int
    /// 버디 (== -1)
    public let birdie: Int
    /// 파 (== 0)
    public let par: Int
    /// 보기 (== +1)
    public let bogey: Int
    /// 더블 이상 (≥ +2)
    public let doubleOrWorse: Int
    /// 총 홀 수 (분모)
    public let totalHoles: Int

    public var eaglePct: Double { totalHoles == 0 ? 0 : Double(eagleOrBetter) / Double(totalHoles) }
    public var birdiePct: Double { totalHoles == 0 ? 0 : Double(birdie) / Double(totalHoles) }
    public var parPct: Double { totalHoles == 0 ? 0 : Double(par) / Double(totalHoles) }
    public var bogeyPct: Double { totalHoles == 0 ? 0 : Double(bogey) / Double(totalHoles) }
    public var doublePct: Double { totalHoles == 0 ? 0 : Double(doubleOrWorse) / Double(totalHoles) }

    public init(eagleOrBetter: Int, birdie: Int, par: Int, bogey: Int, doubleOrWorse: Int, totalHoles: Int) {
        self.eagleOrBetter = eagleOrBetter
        self.birdie = birdie
        self.par = par
        self.bogey = bogey
        self.doubleOrWorse = doubleOrWorse
        self.totalHoles = totalHoles
    }
}

/// USGA 약식 핸디캡 추정
public struct HandicapEstimate: Sendable {
    /// USGA 약식: 최근 8R 中 베스트 3R 평균 - 72
    public let index: Double
    /// 지난달 대비 변화 (음수 = 좋아짐). 데이터 부족 시 nil.
    public let delta: Double?
    /// 산식에 사용된 라운드 수 (보통 8, 부족하면 그보다 작음)
    public let basedOnRounds: Int

    public init(index: Double, delta: Double?, basedOnRounds: Int) {
        self.index = index
        self.delta = delta
        self.basedOnRounds = basedOnRounds
    }
}

/// Par별 평균 타수
public struct ParTypeAverage: Sendable {
    /// 3/4/5
    public let par: Int
    /// 해당 par 홀들의 평균 타수
    public let averageScore: Double
    /// averageScore - Double(par)
    public let vsPar: Double
    /// 해당 par 홀 수
    public let holeCount: Int

    public init(par: Int, averageScore: Double, vsPar: Double, holeCount: Int) {
        self.par = par
        self.averageScore = averageScore
        self.vsPar = vsPar
        self.holeCount = holeCount
    }
}

// MARK: - 추세 모델

/// 최근 라운드 점수 추세 방향
public enum TrendDirection: String, Sendable {
    /// 좋아지는 중 (점수 줄어드는 추세)
    case improving
    /// 비슷한 흐름 유지 중
    case stable
    /// 어려워지는 중 (점수 늘어나는 추세)
    case worsening
}

/// 최근 추세 집계 결과
public struct RecentTrend: Sendable {
    /// 추세 방향
    public let direction: TrendDirection
    /// 앞 절반 평균 (반올림 전)
    public let previousAverage: Double
    /// 뒤 절반 평균 (반올림 전)
    public let currentAverage: Double
    /// round(currentAverage - previousAverage). 음수=좋아짐
    public let delta: Int

    public init(direction: TrendDirection, previousAverage: Double, currentAverage: Double, delta: Int) {
        self.direction = direction
        self.previousAverage = previousAverage
        self.currentAverage = currentAverage
        self.delta = delta
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
            totalScore: $0.score,
            courseId: $0.round.courseId
        )
    }

    // 최근 5라운드 (날짜 오름차순)
    let sorted = scoredRounds.sorted { a, b in
        let dateA = a.round.finishedAt ?? a.round.date
        let dateB = b.round.finishedAt ?? b.round.date
        return dateA < dateB
    }
    let recentFive = Array(sorted.suffix(5))
    let recentScores = recentFive.map { $0.score }

    // recentEntries: (round메타 + score + parTotal + holeCount) 묶음, 최신이 인덱스 0
    let recentEntries: [RecentRoundEntry] = recentFive.reversed().map { item in
        let parTotal = item.round.holeList.reduce(0) { $0 + $1.par }
        return RecentRoundEntry(
            roundId: item.round.id,
            courseName: item.round.courseName,
            date: item.round.finishedAt ?? item.round.date,
            totalScore: item.score,
            parTotal: parTotal,
            holeCount: item.round.holeList.count
        )
    }

    // recentAverageScore: 최근 5라운드 평균
    let recentAverageScore: Double? = recentFive.isEmpty ? nil :
        Double(recentFive.reduce(0) { $0 + $1.score }) / Double(recentFive.count)

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

    // MARK: - 신규 집계

    // 스코어 분포
    let scoreDistribution = computeScoreDistribution(scoredRounds: scoredRounds)

    // 핸디캡 추정
    let handicapEstimate = computeHandicapEstimate(scoredRounds: scoredRounds)

    // Par별 평균
    let parTypeAverages = computeParTypeAverages(scoredRounds: scoredRounds)

    // 일관성 (최근 10R 표준편차)
    let recentTen = Array(sorted.suffix(10).map { $0.score })
    let consistencySigma = computeStdDev(values: recentTen)

    // 스코어 트렌드 (최근 10R, 오래된→최근)
    let scoreTrend = recentTen

    // PR 판정: 베스트 라운드의 코스에서 본인 최저가 맞는지
    let isPersonalRecord = computeIsPersonalRecord(scoredRounds: scoredRounds, bestRound: bestRoundInfo)

    // 최근 추세
    let recentTrend = computeRecentTrend(sorted: sorted)

    return RoundStatisticsResult(
        totalRounds: finished.count,
        averageScore: averageScore,
        bestRound: bestRoundInfo,
        recentScores: recentScores,
        averageVsPar: averageVsPar,
        recentEntries: recentEntries,
        recentAverageScore: recentAverageScore,
        scoreDistribution: scoreDistribution,
        handicapEstimate: handicapEstimate,
        parTypeAverages: parTypeAverages,
        consistencySigma: consistencySigma,
        scoreTrend: scoreTrend,
        isPersonalRecord: isPersonalRecord,
        recentTrend: recentTrend
    )
}

// MARK: - Private 헬퍼 함수

private func computeScoreDistribution(scoredRounds: [(round: Round, score: Int)]) -> ScoreDistribution {
    var eagleOrBetter = 0
    var birdie = 0
    var par = 0
    var bogey = 0
    var doubleOrWorse = 0
    var totalHoles = 0

    for item in scoredRounds {
        guard let owner = item.round.playerList.first(where: { $0.isOwner }) else { continue }
        for hole in item.round.holeList {
            let count = hole.count(for: owner.id)
            guard count > 0 else { continue }
            let diff = count - hole.par
            totalHoles += 1
            if diff <= -2 {
                eagleOrBetter += 1
            } else if diff == -1 {
                birdie += 1
            } else if diff == 0 {
                par += 1
            } else if diff == 1 {
                bogey += 1
            } else {
                doubleOrWorse += 1
            }
        }
    }

    return ScoreDistribution(
        eagleOrBetter: eagleOrBetter,
        birdie: birdie,
        par: par,
        bogey: bogey,
        doubleOrWorse: doubleOrWorse,
        totalHoles: totalHoles
    )
}

/// USGA 약식 핸디캡 계산
/// - 최근 8R 중 베스트 3R 평균 - 72
/// - 최소 3R 필요, 미만이면 nil
private func computeHandicapEstimate(scoredRounds: [(round: Round, score: Int)]) -> HandicapEstimate? {
    let now = Date()

    func handicapIndex(from rounds: [(round: Round, score: Int)], at referenceDate: Date) -> Double? {
        // 기준 날짜 이전 라운드만 (referenceDate 이하)
        let eligible = rounds
            .filter { ($0.round.finishedAt ?? $0.round.date) <= referenceDate }
            .sorted { ($0.round.finishedAt ?? $0.round.date) > ($1.round.finishedAt ?? $1.round.date) }
        let recent = Array(eligible.prefix(8))
        guard recent.count >= 3 else { return nil }
        let best3 = recent.sorted { $0.score < $1.score }.prefix(3)
        let avg = Double(best3.reduce(0) { $0 + $1.score }) / 3.0
        return avg - 72.0
    }

    guard let currentIndex = handicapIndex(from: scoredRounds, at: now) else {
        return nil
    }

    // basedOnRounds: 최근 8R 중 실제 사용 수
    let eligible = scoredRounds
        .sorted { ($0.round.finishedAt ?? $0.round.date) > ($1.round.finishedAt ?? $1.round.date) }
    let basedOn = min(eligible.count, 8)

    // delta: now - 30일 기준 index vs currentIndex
    let previousDate = now.addingTimeInterval(-30 * 86400)
    let delta: Double?
    if let previousIndex = handicapIndex(from: scoredRounds, at: previousDate) {
        delta = currentIndex - previousIndex
    } else {
        delta = nil
    }

    return HandicapEstimate(index: currentIndex, delta: delta, basedOnRounds: basedOn)
}

private func computeParTypeAverages(scoredRounds: [(round: Round, score: Int)]) -> [ParTypeAverage] {
    // par 3/4/5 각각 (scoreSum, count)
    var parData: [Int: (scoreSum: Int, count: Int)] = [:]

    for item in scoredRounds {
        guard let owner = item.round.playerList.first(where: { $0.isOwner }) else { continue }
        for hole in item.round.holeList {
            let parVal = hole.par
            guard parVal >= 3 && parVal <= 5 else { continue }
            let count = hole.count(for: owner.id)
            guard count > 0 else { continue }
            let existing = parData[parVal] ?? (0, 0)
            parData[parVal] = (existing.scoreSum + count, existing.count + 1)
        }
    }

    return [3, 4, 5].compactMap { p -> ParTypeAverage? in
        guard let data = parData[p], data.count > 0 else { return nil }
        let avg = Double(data.scoreSum) / Double(data.count)
        return ParTypeAverage(par: p, averageScore: avg, vsPar: avg - Double(p), holeCount: data.count)
    }
}

/// 모표준편차 (population std dev)
private func computeStdDev(values: [Int]) -> Double? {
    guard values.count >= 3 else { return nil }
    let mean = Double(values.reduce(0, +)) / Double(values.count)
    let variance = values.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(values.count)
    return sqrt(variance)
}

/// 최근 추세 산출
/// - Parameter sorted: finishedAt 오름차순으로 정렬된 scoredRounds (오래된→최근)
/// - Returns: 최근 10R 중 6R 미만이면 nil
private func computeRecentTrend(sorted: [(round: Round, score: Int)]) -> RecentTrend? {
    let recent = Array(sorted.suffix(10))
    guard recent.count >= 6 else { return nil }

    let n = recent.count
    let half = n / 2
    let prevSlice = Array(recent.prefix(half))
    let currSlice = Array(recent.suffix(n - half))

    let prevAvg = Double(prevSlice.reduce(0) { $0 + $1.score }) / Double(prevSlice.count)
    let currAvg = Double(currSlice.reduce(0) { $0 + $1.score }) / Double(currSlice.count)

    let delta = Int((currAvg - prevAvg).rounded())

    let direction: TrendDirection
    if delta <= -2 {
        direction = .improving
    } else if delta >= 2 {
        direction = .worsening
    } else {
        direction = .stable
    }

    return RecentTrend(direction: direction, previousAverage: prevAvg, currentAverage: currAvg, delta: delta)
}

private func computeIsPersonalRecord(
    scoredRounds: [(round: Round, score: Int)],
    bestRound: BestRoundInfo?
) -> Bool {
    guard let best = bestRound else { return false }
    let sameCourseBest = scoredRounds
        .filter { $0.round.courseId == best.courseId }
        .min { $0.score < $1.score }
    guard let courseMin = sameCourseBest else { return false }
    return courseMin.score == best.totalScore
}

// MARK: - 라운드 위치 정보

/// 라운드한 골프장의 위치 정보. 지도 표시에 사용.
public struct RoundLocation: Sendable, Identifiable {
    /// courseId (= id)
    public let courseId: String
    /// 골프장 이름
    public let courseName: String
    /// 클럽하우스 위도
    public let lat: Double
    /// 클럽하우스 경도
    public let lng: Double
    /// 해당 골프장에서 친 라운드 수
    public let roundCount: Int

    public var id: String { courseId }

    public init(courseId: String, courseName: String, lat: Double, lng: Double, roundCount: Int) {
        self.courseId = courseId
        self.courseName = courseName
        self.lat = lat
        self.lng = lng
        self.roundCount = roundCount
    }
}

/// 라운드한 골프장의 위치 리스트.
/// - courseFor 으로 GolfCourse 조회 → clubhouse 좌표 있는 것만 포함
/// - 같은 courseId는 dedupe + roundCount 누적
/// - 완료 라운드(isFinished==true) 만 대상
public func roundLocations(
    rounds: [Round],
    courseFor: (Round) -> GolfCourse?
) -> [RoundLocation] {
    let finished = rounds.filter { $0.isFinished }
    guard !finished.isEmpty else { return [] }

    // courseId별 (courseName, lat, lng, count) 누적
    var accumulator: [String: (courseName: String, lat: Double, lng: Double, count: Int)] = [:]
    for round in finished {
        guard let course = courseFor(round),
              let clubhouse = course.clubhouse else { continue }
        // dedupe key: GolfCourse.id (매칭된 course의 id 사용 — 폴백 매칭 시 round.courseId와 다를 수 있음)
        let key = course.id
        if let existing = accumulator[key] {
            accumulator[key] = (existing.courseName, existing.lat, existing.lng, existing.count + 1)
        } else {
            accumulator[key] = (course.name, clubhouse.lat, clubhouse.lng, 1)
        }
    }

    return accumulator.map { key, value in
        RoundLocation(
            courseId: key,
            courseName: value.courseName,
            lat: value.lat,
            lng: value.lng,
            roundCount: value.count
        )
    }
    .sorted { $0.roundCount > $1.roundCount }
}

// MARK: - 지역별 라운드 통계

/// 지역별 라운드 집계 결과
public struct RegionStats: Sendable {
    /// 원본 region 값 (예: "경기", "서울"). 빈 문자열이면 "기타" 그룹.
    public let regionKey: String
    /// 표시명 (예: "경기도", "서울", "기타")
    public let displayName: String
    /// 해당 지역 라운드 수
    public let roundCount: Int

    public init(regionKey: String, displayName: String, roundCount: Int) {
        self.regionKey = regionKey
        self.displayName = displayName
        self.roundCount = roundCount
    }
}

/// 지역명 → 표시명 매핑 테이블
private let regionDisplayName: [String: String] = [
    "경기": "경기도", "강원": "강원도",
    "충북": "충청북도", "충남": "충청남도",
    "전북": "전라북도", "전남": "전라남도",
    "경북": "경상북도", "경남": "경상남도",
    "제주": "제주",
    "서울": "서울", "부산": "부산",
    "대구": "대구", "인천": "인천",
    "광주": "광주", "대전": "대전",
    "울산": "울산", "세종": "세종"
]

/// 완료된 라운드를 지역별로 집계한다.
/// - Parameters:
///   - rounds: 라운드 배열 (isFinished 여부 무관하게 전달, 내부에서 필터)
///   - courseFor: Round → GolfCourse lookup 클로저
/// - Returns: roundCount 내림차순, 동률은 regionKey 알파벳 오름차순으로 정렬된 배열
public func aggregateRegionStats(
    rounds: [Round],
    courseFor: (Round) -> GolfCourse?
) -> [RegionStats] {
    // 완료된 라운드만 대상
    let finished = rounds.filter { $0.isFinished }
    guard !finished.isEmpty else { return [] }

    // regionKey별 카운트 집계
    var countByKey: [String: Int] = [:]
    for round in finished {
        let course = courseFor(round)
        let region = course?.region ?? ""
        let key = region.isEmpty ? "" : region
        countByKey[key, default: 0] += 1
    }

    // RegionStats 배열로 변환
    let stats: [RegionStats] = countByKey.map { key, count in
        let display = key.isEmpty ? "기타" : (regionDisplayName[key] ?? key)
        return RegionStats(regionKey: key, displayName: display, roundCount: count)
    }

    // 내림차순 정렬, 동률은 regionKey 알파벳 오름차순
    return stats.sorted { a, b in
        if a.roundCount != b.roundCount {
            return a.roundCount > b.roundCount
        }
        return a.regionKey < b.regionKey
    }
}
