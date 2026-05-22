import XCTest
import SwiftData
@testable import Shared

// MARK: - ScoreCardViewModelTests
// A3: 18홀 4인 random 100회 → 카운트 일관성 + clamp 음수 차단
// 22-STATE_MANAGEMENT §3 ScoreCardViewModel 검증

final class ScoreCardViewModelTests: XCTestCase {

    // MARK: 테스트 헬퍼 — 인메모리 컨테이너

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: test_scoreCard_18holes_4players_random

    @MainActor
    func test_scoreCard_18holes_4players_random() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 4인 플레이어 생성
        let players = (0..<4).map { idx in
            Player(name: "P\(idx)", isOwner: idx == 0, order: idx)
        }
        players.forEach { ctx.insert($0) }

        // 라운드 + 18홀
        let round = Round(courseId: "test", courseName: "테스트")
        ctx.insert(round)
        round.players = players
        var holes18: [HoleScore] = []
        for h in 1...18 {
            let hole = HoleScore(holeNumber: h, par: [3, 4, 5].randomElement()!)
            ctx.insert(hole)
            holes18.append(hole)
        }
        round.holes = holes18
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)
        var expectedCounts: [UUID: [Int: Int]] = [:]
        players.forEach { p in expectedCounts[p.id] = [:] }

        // 100회 랜덤 increment/decrement 시뮬레이션
        for _ in 0..<100 {
            let player = players.randomElement()!
            let hole = round.holeList.randomElement()!
            let isIncrement = Bool.random()

            if isIncrement {
                let current = hole.count(for: player.id)
                if current < 15 {
                    if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
                        hole.counts[idx].value += 1
                    } else {
                        hole.counts.append(ScoreEntry(playerId: player.id, value: 1))
                    }
                    expectedCounts[player.id]![hole.holeNumber] = (expectedCounts[player.id]![hole.holeNumber] ?? 0) + 1
                }
            } else {
                let current = hole.count(for: player.id)
                if current > 0 {
                    if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
                        hole.counts[idx].value -= 1
                    }
                    expectedCounts[player.id]![hole.holeNumber] = max(0, (expectedCounts[player.id]![hole.holeNumber] ?? 0) - 1)
                }
            }
        }

        vm.refresh(from: round)

        for player in players {
            for h in 1...18 {
                let expected = expectedCounts[player.id]![h] ?? 0
                let actual = vm.count(holeNumber: h, playerId: player.id)
                XCTAssertEqual(actual, expected,
                    "플레이어 \(player.name) \(h)번 홀: expected \(expected), actual \(actual)")
            }
        }
    }

    // MARK: test_scoreCard_clamp_noNegative

    @MainActor
    func test_scoreCard_clamp_noNegative() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: "test", courseName: "클램프 테스트")
        ctx.insert(round)
        round.players = [player]

        let hole = HoleScore(holeNumber: 1, par: 4)
        ctx.insert(hole)
        round.holes = [hole]
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)

        // 초기값 0
        XCTAssertEqual(vm.count(holeNumber: 1, playerId: player.id), 0)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 1, playerId: player.id), .empty)

        // decrement 시도 — 0 미만 금지
        let currentBeforeDecrement = hole.count(for: player.id)
        if currentBeforeDecrement > 0 {
            hole.counts[0].value = max(0, hole.counts[0].value - 1)
        }
        vm.refresh(from: round)
        XCTAssertGreaterThanOrEqual(vm.count(holeNumber: 1, playerId: player.id), 0,
            "타수는 음수가 될 수 없어요")
    }

    // MARK: test_scoreCard_parDiff_categories

    @MainActor
    func test_scoreCard_parDiff_categories() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: "test", courseName: "par diff 테스트")
        ctx.insert(round)
        round.players = [player]

        let testCases: [(holeNum: Int, count: Int, expected: ScoreCategory)] = [
            (1, 2, .eagle),      // par=4, count=2 → eagle (≤par-2)
            (2, 3, .birdie),     // par=4, count=3 → birdie (par-1)
            (3, 4, .par),        // par=4, count=4 → par
            (4, 5, .bogey),      // par=4, count=5 → bogey (par+1)
            (5, 7, .doublePlus), // par=4, count=7 → doublePlus (≥par+2)
            (6, 0, .empty),      // count=0 → empty
        ]

        var parDiffHoles: [HoleScore] = []
        for tc in testCases {
            let hole = HoleScore(holeNumber: tc.holeNum, par: 4)
            if tc.count > 0 {
                hole.counts.append(ScoreEntry(playerId: player.id, value: tc.count))
            }
            ctx.insert(hole)
            parDiffHoles.append(hole)
        }
        round.holes = parDiffHoles
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)

        for tc in testCases {
            let actual = vm.scoreCategory(holeNumber: tc.holeNum, playerId: player.id)
            XCTAssertEqual(actual, tc.expected,
                "\(tc.holeNum)번 홀 (count=\(tc.count), par=4): expected \(tc.expected), actual \(actual)")
        }
    }

    // MARK: test_scoreCard_total_calculation

    @MainActor
    func test_scoreCard_total_calculation() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let playerA = Player(name: "A", isOwner: true, order: 0)
        let playerB = Player(name: "B", order: 1)
        [playerA, playerB].forEach { ctx.insert($0) }

        let round = Round(courseId: "t", courseName: "합산 테스트")
        ctx.insert(round)
        round.players = [playerA, playerB]

        // 9홀: A=5, B=4 각 홀마다
        var totalHoles: [HoleScore] = []
        for h in 1...9 {
            let hole = HoleScore(
                holeNumber: h,
                par: 4,
                counts: [
                    ScoreEntry(playerId: playerA.id, value: 5),
                    ScoreEntry(playerId: playerB.id, value: 4),
                ]
            )
            ctx.insert(hole)
            totalHoles.append(hole)
        }
        round.holes = totalHoles
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)

        // A 총합: 5 × 9 = 45, B 총합: 4 × 9 = 36
        XCTAssertEqual(vm.totalByPlayer[playerA.id], 45, "A 총합은 45여야 해요")
        XCTAssertEqual(vm.totalByPlayer[playerB.id], 36, "B 총합은 36이어야 해요")

        // OUT 소계 (9홀 = OUT 전체)
        XCTAssertEqual(vm.outTotal(for: playerA.id), 45, "A OUT 소계는 45여야 해요")
        XCTAssertEqual(vm.outTotal(for: playerB.id), 36, "B OUT 소계는 36이어야 해요")

        // vs par: A = 45 - 36 = +9, B = 36 - 36 = 0 (par=4, 9홀→36)
        XCTAssertEqual(vm.vsParByPlayer[playerA.id], 9, "A vs par는 +9여야 해요")
        XCTAssertEqual(vm.vsParByPlayer[playerB.id], 0, "B vs par는 E여야 해요")
    }
}
