import XCTest
import SwiftData
@testable import Shared

// MARK: - RoundStatisticsTests
// Shared/Stats/RoundStatistics.swift aggregateStatistics() 검증

final class RoundStatisticsTests: XCTestCase {

    // MARK: 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// 픽스처 라운드 생성: 1명(주인), N홀, 홀별 타수 일정하게 설정
    @MainActor
    private func makeFinishedRound(
        ctx: ModelContext,
        courseId: String,
        courseName: String,
        holesCount: Int = 9,
        scorePerHole: Int = 4,
        par: Int = 4,
        finishedAt: Date = .now
    ) -> Round {
        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: courseId, courseName: courseName)
        round.isFinished = true
        round.finishedAt = finishedAt
        ctx.insert(round)
        round.players = [player]

        var holeList: [HoleScore] = []
        for h in 1...holesCount {
            let hole = HoleScore(holeNumber: h, par: par)
            hole.counts.append(ScoreEntry(playerId: player.id, value: scorePerHole))
            ctx.insert(hole)
            holeList.append(hole)
        }
        round.holes = holeList
        return round
    }

    // MARK: - 빈 배열 → 기본값 반환

    func test_aggregate_emptyRounds_returnsDefaults() {
        let result = aggregateStatistics(rounds: [])
        XCTAssertEqual(result.totalRounds, 0)
        XCTAssertNil(result.averageScore)
        XCTAssertNil(result.bestRound)
        XCTAssertTrue(result.recentScores.isEmpty)
        XCTAssertNil(result.averageVsPar)
    }

    // MARK: - 완료 라운드 1개 → 정확한 통계

    @MainActor
    func test_aggregate_singleRound_correctStats() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 9홀, 홀당 5타, par=4 → 총 45타, vs par = +9
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "r1",
            courseName: "A장",
            holesCount: 9,
            scorePerHole: 5,
            par: 4
        )
        try ctx.save()

        let result = aggregateStatistics(rounds: [round])

        XCTAssertEqual(result.totalRounds, 1)
        XCTAssertEqual(result.averageScore ?? 0, 45.0, accuracy: 0.01)
        XCTAssertEqual(result.bestRound?.totalScore, 45)
        XCTAssertEqual(result.bestRound?.courseName, "A장")
        XCTAssertEqual(result.recentScores, [45])
        XCTAssertEqual(result.averageVsPar ?? 0, 9.0, accuracy: 0.01)
    }

    // MARK: - 완료 3개 라운드 → 평균 + 베스트 정확성

    @MainActor
    func test_aggregate_threeRounds_averageAndBest() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 라운드별 9홀 총점: 36, 45, 54
        let r1 = makeFinishedRound(ctx: ctx, courseId: "r1", courseName: "A장", holesCount: 9, scorePerHole: 4, par: 4)
        let r2 = makeFinishedRound(ctx: ctx, courseId: "r2", courseName: "B장", holesCount: 9, scorePerHole: 5, par: 4)
        let r3 = makeFinishedRound(ctx: ctx, courseId: "r3", courseName: "C장", holesCount: 9, scorePerHole: 6, par: 4)
        try ctx.save()

        let result = aggregateStatistics(rounds: [r1, r2, r3])

        XCTAssertEqual(result.totalRounds, 3)
        // 평균: (36+45+54)/3 = 45
        XCTAssertEqual(result.averageScore ?? 0, 45.0, accuracy: 0.01)
        // 베스트: r1 (36타)
        XCTAssertEqual(result.bestRound?.totalScore, 36)
        XCTAssertEqual(result.bestRound?.courseName, "A장")
    }

    // MARK: - 미완료 라운드는 집계 제외

    @MainActor
    func test_aggregate_unfinishedRound_excluded() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let finished = makeFinishedRound(
            ctx: ctx, courseId: "r1", courseName: "완료장",
            holesCount: 9, scorePerHole: 4
        )

        // 미완료 라운드
        let unfinished = Round(courseId: "r2", courseName: "진행장")
        ctx.insert(unfinished)
        let uPlayer = Player(name: "나", isOwner: true)
        ctx.insert(uPlayer)
        unfinished.players = [uPlayer]
        let uHole = HoleScore(holeNumber: 1, par: 4)
        uHole.counts.append(ScoreEntry(playerId: uPlayer.id, value: 3))
        ctx.insert(uHole)
        unfinished.holes = [uHole]
        // isFinished = false (기본값)
        try ctx.save()

        let result = aggregateStatistics(rounds: [finished, unfinished])

        // 완료 라운드만 집계
        XCTAssertEqual(result.totalRounds, 1, "미완료 라운드는 제외되어야 해요")
        XCTAssertEqual(result.averageScore ?? 0, 36.0, accuracy: 0.01)
    }

    // MARK: - 최근 5라운드 제한

    @MainActor
    func test_aggregate_recentScores_limitedToFive() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 7개 라운드 생성
        var rounds: [Round] = []
        for i in 0..<7 {
            let date = Date(timeIntervalSinceNow: Double(i) * 86400)
            let r = makeFinishedRound(
                ctx: ctx,
                courseId: "r\(i)",
                courseName: "장\(i)",
                holesCount: 9,
                scorePerHole: 4 + i,
                finishedAt: date
            )
            rounds.append(r)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)

        XCTAssertEqual(result.recentScores.count, 5, "최근 5라운드만 포함되어야 해요")
    }

    // MARK: - 신규 테스트 (stats v2)

    // MARK: 스코어 분포 카운트 검증

    @MainActor
    func test_scoreDistribution_correctCounts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: "dist1", courseName: "분포테스트")
        round.isFinished = true
        round.finishedAt = Date()
        ctx.insert(round)
        round.players = [player]

        // 홀별 par=4, 점수: 2(이글), 3(버디), 4(파), 5(보기), 6(더블), 7(더블+), 8(더블+)
        let holeData: [(Int, Int)] = [(4,2), (4,3), (4,4), (4,5), (4,6), (4,7), (4,8)]
        var holeList: [HoleScore] = []
        for (idx, (par, score)) in holeData.enumerated() {
            let hole = HoleScore(holeNumber: idx + 1, par: par)
            hole.counts.append(ScoreEntry(playerId: player.id, value: score))
            ctx.insert(hole)
            holeList.append(hole)
        }
        round.holes = holeList
        try ctx.save()

        let result = aggregateStatistics(rounds: [round])
        let dist = result.scoreDistribution

        XCTAssertEqual(dist.eagleOrBetter, 1, "이글 이하 1홀")
        XCTAssertEqual(dist.birdie, 1, "버디 1홀")
        XCTAssertEqual(dist.par, 1, "파 1홀")
        XCTAssertEqual(dist.bogey, 1, "보기 1홀")
        XCTAssertEqual(dist.doubleOrWorse, 3, "더블+ 3홀")
        XCTAssertEqual(dist.totalHoles, 7)
    }

    // MARK: 라운드 2개 → 핸디캡 nil

    @MainActor
    func test_handicap_lessThan3Rounds_returnsNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let r1 = makeFinishedRound(ctx: ctx, courseId: "h1", courseName: "A", holesCount: 18, scorePerHole: 5, par: 4, finishedAt: Date())
        let r2 = makeFinishedRound(ctx: ctx, courseId: "h2", courseName: "B", holesCount: 18, scorePerHole: 5, par: 4, finishedAt: Date())
        try ctx.save()

        let result = aggregateStatistics(rounds: [r1, r2])
        XCTAssertNil(result.handicapEstimate, "라운드 2개면 핸디캡 추정 nil")
    }

    // MARK: 8R USGA 약식 공식 검증

    @MainActor
    func test_handicap_8rounds_USGAformula() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 18홀 라운드 8개: 총타수 76,78,80,82,84,86,88,90
        // 베스트 3R: 76, 78, 80 → 평균 = 234/3 = 78 → index = 78 - 72 = 6.0
        let scores = [76, 78, 80, 82, 84, 86, 88, 90]
        var rounds: [Round] = []
        let base = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        for (i, totalScore) in scores.enumerated() {
            let perHole = totalScore / 18
            let remainder = totalScore % 18
            // 18홀, 앞 remainder 홀은 +1
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "hcp\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 3600)
            ctx.insert(round)
            round.players = [player]
            var holeList: [HoleScore] = []
            for h in 1...18 {
                let score = (h <= remainder) ? (perHole + 1) : perHole
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: score))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)
        XCTAssertNotNil(result.handicapEstimate)
        // index = 78.0 - 72.0 = 6.0
        XCTAssertEqual(result.handicapEstimate?.index ?? 0, 6.0, accuracy: 0.1)
        XCTAssertEqual(result.handicapEstimate?.basedOnRounds, 8)
    }

    // MARK: Par별 평균 분리 검증

    @MainActor
    func test_parTypeAverages_par3and4and5_separated() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)
        let round = Round(courseId: "par1", courseName: "파별테스트")
        round.isFinished = true
        round.finishedAt = Date()
        ctx.insert(round)
        round.players = [player]

        // par3: 4타(+1), par4: 5타(+1), par5: 6타(+1)
        let holeData: [(Int, Int)] = [(3, 4), (4, 5), (5, 6)]
        var holeList: [HoleScore] = []
        for (idx, (par, score)) in holeData.enumerated() {
            let hole = HoleScore(holeNumber: idx + 1, par: par)
            hole.counts.append(ScoreEntry(playerId: player.id, value: score))
            ctx.insert(hole)
            holeList.append(hole)
        }
        round.holes = holeList
        try ctx.save()

        let result = aggregateStatistics(rounds: [round])
        let avgs = result.parTypeAverages

        XCTAssertEqual(avgs.count, 3, "par 3/4/5 모두 있어야 해요")

        let par3 = avgs.first { $0.par == 3 }
        let par4 = avgs.first { $0.par == 4 }
        let par5 = avgs.first { $0.par == 5 }

        XCTAssertEqual(par3?.averageScore ?? 0, 4.0, accuracy: 0.01)
        XCTAssertEqual(par4?.averageScore ?? 0, 5.0, accuracy: 0.01)
        XCTAssertEqual(par5?.averageScore ?? 0, 6.0, accuracy: 0.01)

        XCTAssertEqual(par3?.vsPar ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(par4?.vsPar ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(par5?.vsPar ?? 0, 1.0, accuracy: 0.01)
    }

    // MARK: 라운드 2개 → consistencySigma nil

    @MainActor
    func test_consistency_belowThreeRounds_isNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let r1 = makeFinishedRound(ctx: ctx, courseId: "c1", courseName: "A", holesCount: 9, scorePerHole: 5, finishedAt: Date())
        let r2 = makeFinishedRound(ctx: ctx, courseId: "c2", courseName: "B", holesCount: 9, scorePerHole: 6, finishedAt: Date())
        try ctx.save()

        let result = aggregateStatistics(rounds: [r1, r2])
        XCTAssertNil(result.consistencySigma, "라운드 2개면 sigma nil")
    }

    // MARK: recentEntries 순서·내용 검증

    @MainActor
    func test_recentEntries_orderedNewestFirst_andCorrectScores() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 7라운드 — 서로 다른 날짜, 코스명, 점수
        let base = Date(timeIntervalSinceReferenceDate: 0) // 고정 기준점
        var rounds: [Round] = []
        let courseNames = ["A코스", "B코스", "C코스", "D코스", "E코스", "F코스", "G코스"]
        let scoresPerHole = [4, 5, 6, 4, 5, 6, 4] // 9홀 총 36,45,54,36,45,54,36
        for i in 0..<7 {
            let r = makeFinishedRound(
                ctx: ctx,
                courseId: "re\(i)",
                courseName: courseNames[i],
                holesCount: 9,
                scorePerHole: scoresPerHole[i],
                finishedAt: base.addingTimeInterval(Double(i) * 86400)
            )
            rounds.append(r)
        }
        // import 라운드 1개 포함 (index=3, finishedAt 명시)
        rounds[3].isImported = true
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)

        // 최근 5개만
        XCTAssertEqual(result.recentEntries.count, 5)

        // 인덱스 0이 가장 최근 (i=6, base+6days)
        let newestDate = base.addingTimeInterval(6 * 86400)
        XCTAssertEqual(result.recentEntries[0].date, newestDate,
                       "recentEntries[0]은 가장 최근 날짜여야 해요")

        // 각 entry의 totalScore가 해당 라운드 실제 총 타수와 일치 (i=2..6 → 54,36,45,54,36)
        let expectedScores = [36, 45, 54, 36, 45].reversed() // i=6,5,4,3,2 → 36,54,45,54,54 아님
        // i=2:54, i=3:36, i=4:45, i=5:54, i=6:36 — 내림차순(i=6,5,4,3,2): 36,54,45,36,54
        let expectedByDesc = [scoresPerHole[6]*9, scoresPerHole[5]*9, scoresPerHole[4]*9,
                               scoresPerHole[3]*9, scoresPerHole[2]*9]
        for (idx, entry) in result.recentEntries.enumerated() {
            XCTAssertEqual(entry.totalScore, expectedByDesc[idx],
                           "entry[\(idx)] score 불일치: expected \(expectedByDesc[idx]), got \(entry.totalScore)")
        }

        // import 라운드 포함 시 finishedAt 기준 정렬 유지 — entry의 date가 오름차순 역방향
        let dates = result.recentEntries.map { $0.date }
        for i in 1..<dates.count {
            XCTAssertGreaterThanOrEqual(dates[i-1].timeIntervalSince1970,
                                        dates[i].timeIntervalSince1970,
                                        "recentEntries는 최신→오래된 순이어야 해요")
        }
    }

    // MARK: recentAverageScore — 최근 5R 평균 (전체 평균과 다름)

    @MainActor
    func test_recentAverageScore_lastFiveOnly_notAllRounds() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 6라운드, 9홀, 점수: 총 80,82,84,86,88,90 (홀당 정수 나눗셈으로 구성)
        // 각 9홀 총합을 만들기 위해 scorePerHole + 나머지 처리를 직접 삽입
        let base = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let totalScores = [80, 82, 84, 86, 88, 90]
        var rounds: [Round] = []
        for (i, total) in totalScores.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "ravg\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            // 9홀: 앞 (total % 9) 홀은 (total/9)+1, 나머지는 total/9
            let base9 = total / 9
            let rem = total % 9
            var holeList: [HoleScore] = []
            for h in 1...9 {
                let s = h <= rem ? base9 + 1 : base9
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)

        // 전체 평균: (80+82+84+86+88+90)/6 = 510/6 = 85.0
        XCTAssertEqual(result.averageScore ?? 0, 85.0, accuracy: 0.01)

        // 최근 5R 평균: (82+84+86+88+90)/5 = 430/5 = 86.0
        XCTAssertNotNil(result.recentAverageScore)
        XCTAssertEqual(result.recentAverageScore ?? 0, 86.0, accuracy: 0.01,
                       "최근 5R 평균은 86.0이어야 해요 (가장 오래된 80 제외)")

        // 전체 평균과 다름
        XCTAssertNotEqual(result.recentAverageScore ?? 0, result.averageScore ?? 0,
                          "recentAverageScore는 전체 averageScore와 달라야 해요")
    }

    // MARK: - 최근 추세 (recentTrend) 테스트

    // MARK: 8R, 좋아지는 추세 → .improving

    @MainActor
    func test_recentTrend_improvingDirection() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 8R, 시간순: 95,94,93,92 / 86,85,84,83
        // 앞 4R 평균 = 93.5, 뒤 4R 평균 = 84.5, delta = round(84.5 - 93.5) = -9 → .improving
        let scores9Hole = [95, 94, 93, 92, 86, 85, 84, 83]
        let base = Date(timeIntervalSinceReferenceDate: 2_000_000)
        var rounds: [Round] = []
        for (i, total) in scores9Hole.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "trend_imp\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            // 9홀로 total 구성: 나머지 처리
            let base9 = total / 9
            let rem = total % 9
            var holeList: [HoleScore] = []
            for h in 1...9 {
                let s = h <= rem ? base9 + 1 : base9
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)
        XCTAssertNotNil(result.recentTrend, "8R이면 recentTrend가 있어야 해요")
        XCTAssertEqual(result.recentTrend?.direction, .improving, "점수가 줄어드는 추세이면 .improving")
        XCTAssertEqual(result.recentTrend?.delta, -9, "delta == -9 기대")
    }

    // MARK: 6R, 나빠지는 추세 → .worsening

    @MainActor
    func test_recentTrend_worseningDirection() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 6R: 80,81,82 / 88,89,90
        // 앞 3R 평균 = 81.0, 뒤 3R 평균 = 89.0, delta = round(89 - 81) = +8 → .worsening
        let scores9Hole = [80, 81, 82, 88, 89, 90]
        let base = Date(timeIntervalSinceReferenceDate: 3_000_000)
        var rounds: [Round] = []
        for (i, total) in scores9Hole.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "trend_wor\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            let base9 = total / 9
            let rem = total % 9
            var holeList: [HoleScore] = []
            for h in 1...9 {
                let s = h <= rem ? base9 + 1 : base9
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)
        XCTAssertNotNil(result.recentTrend)
        XCTAssertEqual(result.recentTrend?.direction, .worsening, "점수가 늘어나는 추세이면 .worsening")
        XCTAssertEqual(result.recentTrend?.delta, 8, "delta == +8 기대")
    }

    // MARK: 6R, delta == +1 → .stable

    @MainActor
    func test_recentTrend_stableWithinThreshold() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 6R: 90,91,92 / 91,92,93
        // 앞 3R 평균 = 91.0, 뒤 3R 평균 = 92.0, delta = round(92 - 91) = +1 → .stable
        let scores9Hole = [90, 91, 92, 91, 92, 93]
        let base = Date(timeIntervalSinceReferenceDate: 4_000_000)
        var rounds: [Round] = []
        for (i, total) in scores9Hole.enumerated() {
            let player = Player(name: "나", isOwner: true)
            ctx.insert(player)
            let round = Round(courseId: "trend_sta\(i)", courseName: "장\(i)")
            round.isFinished = true
            round.finishedAt = base.addingTimeInterval(Double(i) * 86400)
            ctx.insert(round)
            round.players = [player]
            let base9 = total / 9
            let rem = total % 9
            var holeList: [HoleScore] = []
            for h in 1...9 {
                let s = h <= rem ? base9 + 1 : base9
                let hole = HoleScore(holeNumber: h, par: 4)
                hole.counts.append(ScoreEntry(playerId: player.id, value: s))
                ctx.insert(hole)
                holeList.append(hole)
            }
            round.holes = holeList
            rounds.append(round)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)
        XCTAssertNotNil(result.recentTrend)
        XCTAssertEqual(result.recentTrend?.direction, .stable, "delta == +1이면 .stable 임계값 이하")
        XCTAssertEqual(result.recentTrend?.delta, 1)
    }

    // MARK: 5R → recentTrend nil

    @MainActor
    func test_recentTrend_lessThanSixRounds_isNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let base = Date(timeIntervalSinceReferenceDate: 5_000_000)
        var rounds: [Round] = []
        for i in 0..<5 {
            let r = makeFinishedRound(
                ctx: ctx,
                courseId: "trend_nil\(i)",
                courseName: "장\(i)",
                holesCount: 9,
                scorePerHole: 5,
                finishedAt: base.addingTimeInterval(Double(i) * 86400)
            )
            rounds.append(r)
        }
        try ctx.save()

        let result = aggregateStatistics(rounds: rounds)
        XCTAssertNil(result.recentTrend, "5R이면 recentTrend는 nil이어야 해요")
    }

    // MARK: - 지역별 라운드 통계 (aggregateRegionStats)

    // MARK: 기본 그룹핑

    @MainActor
    func test_aggregateRegionStats_basicGrouping() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 경기 2회, 제주 1회, 강원 1회
        let r1 = makeFinishedRound(ctx: ctx, courseId: "gy1", courseName: "경기장A")
        let r2 = makeFinishedRound(ctx: ctx, courseId: "gy2", courseName: "경기장B")
        let r3 = makeFinishedRound(ctx: ctx, courseId: "jj1", courseName: "제주장")
        let r4 = makeFinishedRound(ctx: ctx, courseId: "gw1", courseName: "강원장")
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "gy1": GolfCourse(id: "gy1", name: "경기장A", region: "경기"),
            "gy2": GolfCourse(id: "gy2", name: "경기장B", region: "경기"),
            "jj1": GolfCourse(id: "jj1", name: "제주장", region: "제주"),
            "gw1": GolfCourse(id: "gw1", name: "강원장", region: "강원"),
        ]

        let result = aggregateRegionStats(rounds: [r1, r2, r3, r4]) { round in courses[round.courseId] }

        // 경기 2회가 첫 번째, 나머지는 1회씩 (강원/제주 알파벳 순)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].regionKey, "경기")
        XCTAssertEqual(result[0].displayName, "경기도")
        XCTAssertEqual(result[0].roundCount, 2)
        // 동률인 강원/제주 — 알파벳 순서로 강원이 먼저
        XCTAssertEqual(result[1].roundCount, 1)
        XCTAssertEqual(result[2].roundCount, 1)
    }

    // MARK: nil 또는 빈 region → "기타" 그룹

    @MainActor
    func test_aggregateRegionStats_emptyOrUnknownRegion_groupsAsEtc() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let r1 = makeFinishedRound(ctx: ctx, courseId: "nil1", courseName: "알수없는장")
        let r2 = makeFinishedRound(ctx: ctx, courseId: "empty1", courseName: "빈지역장")
        let r3 = makeFinishedRound(ctx: ctx, courseId: "gy1", courseName: "경기장")
        try ctx.save()

        let courses: [String: GolfCourse] = [
            // "nil1": nil → courseLookup 반환 nil
            "empty1": GolfCourse(id: "empty1", name: "빈지역장", region: ""),
            "gy1":    GolfCourse(id: "gy1",    name: "경기장",   region: "경기"),
        ]

        let result = aggregateRegionStats(rounds: [r1, r2, r3]) { round in courses[round.courseId] }

        let etcItem = result.first { $0.displayName == "기타" }
        XCTAssertNotNil(etcItem, "nil lookup + 빈 region은 '기타' 그룹이어야 해요")
        XCTAssertEqual(etcItem?.roundCount, 2, "nil + 빈 문자열 합산 2회")

        let gyItem = result.first { $0.regionKey == "경기" }
        XCTAssertEqual(gyItem?.roundCount, 1)
    }

    // MARK: 내림차순 정렬 검증

    @MainActor
    func test_aggregateRegionStats_sortedByCountDescending() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 경기 1회, 제주 3회, 강원 2회
        let rounds = [
            makeFinishedRound(ctx: ctx, courseId: "gy1", courseName: "경기장"),
            makeFinishedRound(ctx: ctx, courseId: "jj1", courseName: "제주장A"),
            makeFinishedRound(ctx: ctx, courseId: "jj2", courseName: "제주장B"),
            makeFinishedRound(ctx: ctx, courseId: "jj3", courseName: "제주장C"),
            makeFinishedRound(ctx: ctx, courseId: "gw1", courseName: "강원장A"),
            makeFinishedRound(ctx: ctx, courseId: "gw2", courseName: "강원장B"),
        ]
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "gy1": GolfCourse(id: "gy1", name: "경기장",  region: "경기"),
            "jj1": GolfCourse(id: "jj1", name: "제주장A", region: "제주"),
            "jj2": GolfCourse(id: "jj2", name: "제주장B", region: "제주"),
            "jj3": GolfCourse(id: "jj3", name: "제주장C", region: "제주"),
            "gw1": GolfCourse(id: "gw1", name: "강원장A", region: "강원"),
            "gw2": GolfCourse(id: "gw2", name: "강원장B", region: "강원"),
        ]

        let result = aggregateRegionStats(rounds: rounds) { round in courses[round.courseId] }

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].regionKey, "제주", "제주 3회가 첫 번째여야 해요")
        XCTAssertEqual(result[0].roundCount, 3)
        XCTAssertEqual(result[1].regionKey, "강원", "강원 2회가 두 번째여야 해요")
        XCTAssertEqual(result[1].roundCount, 2)
        XCTAssertEqual(result[2].regionKey, "경기", "경기 1회가 마지막이어야 해요")
        XCTAssertEqual(result[2].roundCount, 1)
    }

    // MARK: 지역명 정규화 검증

    @MainActor
    func test_regionDisplayName_normalization() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // "경기" → "경기도", "서울" → "서울", "" → "기타"
        let r1 = makeFinishedRound(ctx: ctx, courseId: "gy1", courseName: "경기장")
        let r2 = makeFinishedRound(ctx: ctx, courseId: "sl1", courseName: "서울장")
        let r3 = makeFinishedRound(ctx: ctx, courseId: "x1",  courseName: "알수없는장")
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "gy1": GolfCourse(id: "gy1", name: "경기장", region: "경기"),
            "sl1": GolfCourse(id: "sl1", name: "서울장", region: "서울"),
            // "x1" → nil lookup
        ]

        let result = aggregateRegionStats(rounds: [r1, r2, r3]) { round in courses[round.courseId] }

        let gyItem = result.first { $0.regionKey == "경기" }
        XCTAssertEqual(gyItem?.displayName, "경기도", "\"경기\" → \"경기도\" 정규화")

        let slItem = result.first { $0.regionKey == "서울" }
        XCTAssertEqual(slItem?.displayName, "서울", "\"서울\" → \"서울\" 유지")

        let etcItem = result.first { $0.regionKey == "" }
        XCTAssertEqual(etcItem?.displayName, "기타", "빈 key → \"기타\"")
    }

    // MARK: - roundLocations 테스트

    // MARK: 같은 courseId 중복 제거 + roundCount 누적

    @MainActor
    func test_roundLocations_dedupeByCourseId() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // courseId "A"로 라운드 3개, courseId "B"로 라운드 1개
        let rA1 = makeFinishedRound(ctx: ctx, courseId: "A", courseName: "A골프장")
        let rA2 = makeFinishedRound(ctx: ctx, courseId: "A", courseName: "A골프장")
        let rA3 = makeFinishedRound(ctx: ctx, courseId: "A", courseName: "A골프장")
        let rB1 = makeFinishedRound(ctx: ctx, courseId: "B", courseName: "B골프장")
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "A": GolfCourse(id: "A", name: "A골프장", region: "경기", clubhouse: Clubhouse(lat: 37.0, lng: 127.0)),
            "B": GolfCourse(id: "B", name: "B골프장", region: "제주", clubhouse: Clubhouse(lat: 33.5, lng: 126.5)),
        ]

        let result = roundLocations(rounds: [rA1, rA2, rA3, rB1]) { round in courses[round.courseId] }

        XCTAssertEqual(result.count, 2, "courseId별 dedupe — 2건이어야 해요")
        let aLoc = result.first { $0.courseId == "A" }
        let bLoc = result.first { $0.courseId == "B" }
        XCTAssertEqual(aLoc?.roundCount, 3, "A골프장 roundCount는 3이어야 해요")
        XCTAssertEqual(bLoc?.roundCount, 1, "B골프장 roundCount는 1이어야 해요")
    }

    // MARK: clubhouse 없는 골프장 제외

    @MainActor
    func test_roundLocations_excludesCoursesWithoutClubhouse() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let rA = makeFinishedRound(ctx: ctx, courseId: "withCoord", courseName: "좌표있는장")
        let rB = makeFinishedRound(ctx: ctx, courseId: "noCoord", courseName: "좌표없는장")
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "withCoord": GolfCourse(id: "withCoord", name: "좌표있는장", region: "강원",
                                    clubhouse: Clubhouse(lat: 37.5, lng: 128.0)),
            "noCoord":   GolfCourse(id: "noCoord", name: "좌표없는장", region: "전남",
                                    clubhouse: nil),
        ]

        let result = roundLocations(rounds: [rA, rB]) { round in courses[round.courseId] }

        XCTAssertEqual(result.count, 1, "clubhouse nil인 골프장은 제외되어야 해요")
        XCTAssertEqual(result.first?.courseId, "withCoord")
    }

    // MARK: 미완료 라운드 제외

    @MainActor
    func test_roundLocations_unfinishedRoundExcluded() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 완료 라운드
        let rFinished = makeFinishedRound(ctx: ctx, courseId: "C", courseName: "완료장")

        // 미완료 라운드
        let rUnfinished = Round(courseId: "C", courseName: "완료장")
        ctx.insert(rUnfinished)
        let uPlayer = Player(name: "나", isOwner: true)
        ctx.insert(uPlayer)
        rUnfinished.players = [uPlayer]
        // isFinished = false (기본값)
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "C": GolfCourse(id: "C", name: "완료장", region: "서울",
                            clubhouse: Clubhouse(lat: 37.5, lng: 126.9)),
        ]

        let result = roundLocations(rounds: [rFinished, rUnfinished]) { round in courses[round.courseId] }

        XCTAssertEqual(result.count, 1, "미완료 라운드는 위치 집계에 포함되어선 안 돼요")
        XCTAssertEqual(result.first?.roundCount, 1, "완료 라운드 1건만 카운트되어야 해요")
    }

    // MARK: - roundLocations 폴백 매칭 테스트

    // MARK: courseId 매칭 실패 → 코스명 정규화 폴백으로 핀 표시

    @MainActor
    func test_roundLocations_fuzzyMatchByCourseName() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // DB에는 id "베뉴지cc_경기", 이름 "베뉴지C.C" 로 등록
        let course = GolfCourse(
            id: "베뉴지cc_경기",
            name: "베뉴지C.C",
            region: "경기",
            clubhouse: Clubhouse(lat: 37.3, lng: 127.1)
        )

        // 라운드는 courseId "unknown_id_123", courseName "베뉴지 CC" — id 매칭 실패
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "unknown_id_123",
            courseName: "베뉴지 CC"
        )
        try ctx.save()

        // courseFor 클로저: courseId 매칭 실패 → areSimilar 폴백
        let allCourses: [GolfCourse] = [course]
        let idCache: [String: GolfCourse] = Dictionary(uniqueKeysWithValues: allCourses.map { ($0.id, $0) })

        let result = roundLocations(rounds: [round]) { r in
            // 1차: courseId 직접
            if let c = idCache[r.courseId] { return c }
            // 2차: areSimilar 폴백 (베뉴지C.C ↔ 베뉴지 CC)
            return allCourses.first { CourseNameMatcher.areSimilar($0.name, r.courseName) }
        }

        XCTAssertEqual(result.count, 1, "폴백 매칭으로 핀이 1개 표시되어야 해요")
        XCTAssertEqual(result.first?.courseId, course.id, "매칭된 GolfCourse의 id 사용")
        XCTAssertEqual(result.first?.courseName, course.name, "매칭된 GolfCourse의 이름 표시")
        XCTAssertEqual(result.first?.lat ?? 0, 37.3, accuracy: 0.001)
    }

    // MARK: courseId/courseName 모두 매칭 실패 → 핀 제외

    @MainActor
    func test_roundLocations_neitherIdNorNameMatches_excluded() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 라운드 courseId/courseName 모두 DB와 매칭 안 됨
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "no_match_id",
            courseName: "존재하지않는골프장"
        )
        try ctx.save()

        let courses: [String: GolfCourse] = [
            "other_course": GolfCourse(id: "other_course", name: "다른골프장", region: "경기",
                                       clubhouse: Clubhouse(lat: 37.0, lng: 127.0))
        ]

        let result = roundLocations(rounds: [round]) { r in
            if let c = courses[r.courseId] { return c }
            let key = CourseNameMatcher.normalize(r.courseName)
            if !key.isEmpty { return courses.values.first { CourseNameMatcher.normalize($0.name) == key } }
            return nil
        }

        XCTAssertTrue(result.isEmpty, "id/이름 모두 매칭 실패 시 locations 빈 배열이어야 해요")
    }

    // MARK: - aliases 매칭 테스트 (v4)

    // MARK: BELLA → 벨라스톤컨트리클럽 alias 매칭

    @MainActor
    func test_roundLocations_matchesByAlias_BELLAcase() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let course = GolfCourse(
            id: "벨라스톤cc_강원",
            name: "벨라스톤컨트리클럽",
            region: "강원",
            clubhouse: Clubhouse(lat: 37.453, lng: 127.83),
            aliases: ["BELLASTONE", "BELRASEUTON"]
        )

        // 라운드 courseName: "BELLA" — courseId 매칭 실패, 이름 exact 실패, alias contains 매칭 기대
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "unknown_bella_id",
            courseName: "BELLA"
        )
        try ctx.save()

        let allCourses: [GolfCourse] = [course]
        let idCache: [String: GolfCourse] = Dictionary(uniqueKeysWithValues: allCourses.map { ($0.id, $0) })

        let lookup: (Round) -> GolfCourse? = { r in
            if let c = idCache[r.courseId] { return c }
            let q = CourseNameMatcher.normalize(r.courseName)
            guard !q.isEmpty else { return nil }
            return allCourses.first { CourseNameMatcher.matches(course: $0, query: r.courseName) }
        }

        let result = roundLocations(rounds: [round], courseFor: lookup)

        XCTAssertEqual(result.count, 1, "BELLA alias contains 매칭으로 핀이 1개 표시되어야 해요")
        XCTAssertEqual(result.first?.courseId, course.id)
        XCTAssertEqual(result.first?.courseName, course.name)
    }

    // MARK: OAK VALLEY GOLF → 오크밸리골프장 alias 매칭

    @MainActor
    func test_roundLocations_matchesByAlias_OAKcase() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let course = GolfCourse(
            id: "오크밸리_kr",
            name: "오크밸리골프장",
            region: "강원",
            clubhouse: Clubhouse(lat: 37.4, lng: 127.9),
            aliases: ["OAKVALLEY", "OKEUBAELRI"]
        )

        // 라운드 courseName: "OAK VALLEY GOLF" — alias "OAKVALLEY" 와 normalize 후 contains 매칭 기대
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "unknown_oak_id",
            courseName: "OAK VALLEY GOLF"
        )
        try ctx.save()

        let allCourses: [GolfCourse] = [course]
        let idCache: [String: GolfCourse] = Dictionary(uniqueKeysWithValues: allCourses.map { ($0.id, $0) })

        let lookup: (Round) -> GolfCourse? = { r in
            if let c = idCache[r.courseId] { return c }
            let q = CourseNameMatcher.normalize(r.courseName)
            guard !q.isEmpty else { return nil }
            return allCourses.first { CourseNameMatcher.matches(course: $0, query: r.courseName) }
        }

        let result = roundLocations(rounds: [round], courseFor: lookup)

        XCTAssertEqual(result.count, 1, "OAK alias contains 매칭으로 핀이 1개 표시되어야 해요")
        XCTAssertEqual(result.first?.courseId, course.id)
    }

    // MARK: BELLA → XYZ alias 골프장 — 불일치 시 제외

    @MainActor
    func test_roundLocations_aliasNoMatch_excluded() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let course = GolfCourse(
            id: "vbella_x",
            name: "전혀다른골프장",
            region: "강원",
            clubhouse: Clubhouse(lat: 37.0, lng: 127.0),
            aliases: ["XYZ"]
        )

        // 라운드 courseName: "BELLA" — XYZ alias 와 매칭 안 됨
        let round = makeFinishedRound(
            ctx: ctx,
            courseId: "no_match_bella",
            courseName: "BELLA"
        )
        try ctx.save()

        let allCourses: [GolfCourse] = [course]
        let idCache: [String: GolfCourse] = Dictionary(uniqueKeysWithValues: allCourses.map { ($0.id, $0) })

        let lookup: (Round) -> GolfCourse? = { r in
            if let c = idCache[r.courseId] { return c }
            let q = CourseNameMatcher.normalize(r.courseName)
            guard !q.isEmpty else { return nil }
            return allCourses.first { CourseNameMatcher.matches(course: $0, query: r.courseName) }
        }

        let result = roundLocations(rounds: [round], courseFor: lookup)

        XCTAssertTrue(result.isEmpty, "XYZ alias 는 BELLA 와 매칭되지 않으므로 locations 빈 배열이어야 해요")
    }

    // MARK: PR 판정

    @MainActor
    func test_personalRecord_sameCourseBest_isTrue() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let base = Date(timeIntervalSinceNow: -7200)
        // 같은 courseId "pr1"에서 두 라운드: 80타, 90타 → 80타가 PR
        let r1 = makeFinishedRound(ctx: ctx, courseId: "pr1", courseName: "PR코스", holesCount: 18, scorePerHole: 4, par: 4, finishedAt: base)          // 72타
        // 더 높은 점수 라운드
        let r2 = makeFinishedRound(ctx: ctx, courseId: "pr1", courseName: "PR코스", holesCount: 18, scorePerHole: 5, par: 4, finishedAt: base.addingTimeInterval(3600))  // 90타
        try ctx.save()

        let result = aggregateStatistics(rounds: [r1, r2])
        // bestRound는 72타 (r1), courseId "pr1"의 최저도 72타 → PR
        XCTAssertTrue(result.isPersonalRecord, "같은 코스 최저타수이면 PR")
        XCTAssertEqual(result.bestRound?.totalScore, 72)
    }
}
