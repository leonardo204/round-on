import XCTest
import SwiftData
@testable import Shared

// MARK: - ScoreCardViewModelStressTests
// Task E: ScoreCardViewModel 보강 테스트 (18홀 4인 스트레스 + OUT/IN 합계 + 바운드)

final class ScoreCardViewModelStressTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - 18홀 4인 stress test (1000회 랜덤 ops → 일관성)

    @MainActor
    func test_stress_18holes_4players_1000ops_consistency() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let players = (0..<4).map { i in Player(name: "P\(i)", isOwner: i == 0, order: i) }
        players.forEach { ctx.insert($0) }

        let round = Round(courseId: "s", courseName: "스트레스")
        ctx.insert(round)
        round.players = players

        for h in 1...18 {
            let hole = HoleScore(holeNumber: h, par: [3, 4, 5].randomElement()!)
            ctx.insert(hole)
            round.holes.append(hole)
        }
        try ctx.save()

        // 독립 기대값 추적
        var expected: [UUID: [Int: Int]] = [:]
        players.forEach { expected[$0.id] = [:] }

        for _ in 0..<1000 {
            let player = players.randomElement()!
            let hole = round.holes.randomElement()!
            let delta = Bool.random() ? 1 : -1

            let cur = hole.count(for: player.id)
            if delta == 1 && cur < 15 {
                if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
                    hole.counts[idx].value += 1
                } else {
                    hole.counts.append(ScoreEntry(playerId: player.id, value: 1))
                }
                expected[player.id]![hole.holeNumber] = cur + 1
            } else if delta == -1 && cur > 0 {
                if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
                    hole.counts[idx].value -= 1
                }
                expected[player.id]![hole.holeNumber] = cur - 1
            }
        }

        let vm = ScoreCardViewModel(round: round)
        vm.refresh(from: round)

        for player in players {
            var expectedTotal = 0
            for h in 1...18 {
                let exp = expected[player.id]![h] ?? 0
                let actual = vm.count(holeNumber: h, playerId: player.id)
                XCTAssertEqual(actual, exp,
                    "\(player.name) H\(h): expected \(exp) actual \(actual)")
                expectedTotal += exp
            }
            XCTAssertEqual(vm.totalByPlayer[player.id] ?? 0, expectedTotal,
                "\(player.name) 합계 불일치")
        }
    }

    // MARK: - OUT/IN 합계 정확도 (18홀)

    @MainActor
    func test_outInTotal_18holes_accuracy() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)
        let round = Round(courseId: "t", courseName: "OUT/IN")
        ctx.insert(round)
        round.players = [player]

        // 1-9홀: 3타씩, 10-18홀: 5타씩
        for h in 1...18 {
            let score = h <= 9 ? 3 : 5
            let hole = HoleScore(holeNumber: h, par: 4,
                                 counts: [ScoreEntry(playerId: player.id, value: score)])
            ctx.insert(hole)
            round.holes.append(hole)
        }
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)

        // OUT 합계: 3×9 = 27, IN 합계: 5×9 = 45
        XCTAssertEqual(vm.outTotal(for: player.id), 27, "OUT 합계는 27이어야 해요")
        XCTAssertEqual(vm.inTotal(for: player.id), 45, "IN 합계는 45이어야 해요")
        XCTAssertEqual((vm.totalByPlayer[player.id] ?? 0), 72, "총 타수는 72여야 해요")
    }

    // MARK: - currentHoleIndex 바운드 검증 (HoleViewModel)

    @MainActor
    func test_holeViewModel_bounds() {
        let vm = HoleViewModel(totalHoles: 18)
        XCTAssertEqual(vm.currentHoleNumber, 1, "초기 홀은 1이어야 해요")

        // 18홀 마지막으로 이동
        for _ in 1..<18 { vm.nextHole() }
        XCTAssertEqual(vm.currentHoleNumber, 18, "마지막 홀은 18이어야 해요")

        // 더 이상 진행 불가
        vm.nextHole()
        XCTAssertEqual(vm.currentHoleNumber, 18, "18홀 이후 이동 시 18을 유지해야 해요")

        // 처음으로 이동 시도
        for _ in 0..<20 { vm.previousHole() }
        XCTAssertEqual(vm.currentHoleNumber, 1, "1홀 이전 이동 시 1을 유지해야 해요")
    }

    // MARK: - ScoreCategory 경계 5단계 검증 (par diff별)

    @MainActor
    func test_scoreCategory_boundaries_allFiveStages() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)
        let round = Round(courseId: "t", courseName: "분류경계")
        ctx.insert(round)
        round.players = [player]

        // par=4 기준: count=2→eagle, 3→birdie, 4→par, 5→bogey, 6→doublePlus, 0→empty
        let cases: [(holeNum: Int, count: Int)] = [(1,2),(2,3),(3,4),(4,5),(5,6),(6,0)]
        for c in cases {
            let hole = HoleScore(holeNumber: c.holeNum, par: 4)
            if c.count > 0 { hole.counts.append(ScoreEntry(playerId: player.id, value: c.count)) }
            ctx.insert(hole)
            round.holes.append(hole)
        }
        try ctx.save()

        let vm = ScoreCardViewModel(round: round)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 1, playerId: player.id), .eagle)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 2, playerId: player.id), .birdie)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 3, playerId: player.id), .par)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 4, playerId: player.id), .bogey)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 5, playerId: player.id), .doublePlus)
        XCTAssertEqual(vm.scoreCategory(holeNumber: 6, playerId: player.id), .empty)
    }
}
