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
}
