import XCTest
import SwiftData
@testable import Shared

// MARK: - RoundEditTests
// F7 사후 편집 — 완료된 라운드 카운트 수정 후 저장 검증
// RoundViewModel.editRound(_:) + commitEdit() 경로

final class RoundEditTests: XCTestCase {

    // MARK: 테스트 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: test_editRound_incrementCount_reflectedAfterCommit

    /// 완료된 라운드의 카운트를 +1한 뒤 commitEdit 호출 시 변경이 영속화되어야 한다.
    @MainActor
    func test_editRound_incrementCount_reflectedAfterCommit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 라운드 셋업
        let player = Player(name: "나", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: "c1", courseName: "편집 테스트장")
        round.isFinished = true
        round.finishedAt = .now
        ctx.insert(round)
        round.players = [player]

        let hole = HoleScore(holeNumber: 1, par: 4)
        hole.counts.append(ScoreEntry(playerId: player.id, value: 3))  // 초기 3타
        ctx.insert(hole)
        round.holes = [hole]
        try ctx.save()

        // 편집 진입
        let vm = RoundViewModel(modelContext: ctx)
        vm.editRound(round)

        // 홀 1 카운트 +1 (3 → 4)
        if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
            hole.counts[idx].value += 1
        }

        // commitEdit
        try vm.commitEdit()

        // fetch 후 검증
        let descriptor = FetchDescriptor<Round>()
        let fetched = try ctx.fetch(descriptor)
        let fetchedRound = try XCTUnwrap(fetched.first)
        let fetchedHole = try XCTUnwrap(fetchedRound.holeList.first(where: { $0.holeNumber == 1 }))
        let fetchedCount = fetchedHole.count(for: player.id)

        XCTAssertEqual(fetchedCount, 4, "편집 후 카운트는 4여야 해요")
    }

    // MARK: test_editRound_decrementCount_reflectedAfterCommit

    /// 카운트 -1 후 commitEdit 시 저장 확인
    @MainActor
    func test_editRound_decrementCount_reflectedAfterCommit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let player = Player(name: "A", isOwner: true)
        ctx.insert(player)

        let round = Round(courseId: "c2", courseName: "감소 편집 테스트")
        round.isFinished = true
        round.finishedAt = .now
        ctx.insert(round)
        round.players = [player]

        let hole = HoleScore(holeNumber: 1, par: 4)
        hole.counts.append(ScoreEntry(playerId: player.id, value: 6))  // 초기 6타
        ctx.insert(hole)
        round.holes = [hole]
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.editRound(round)

        // 카운트 -1 (6 → 5)
        if let idx = hole.counts.firstIndex(where: { $0.playerId == player.id }) {
            hole.counts[idx].value = max(0, hole.counts[idx].value - 1)
        }

        try vm.commitEdit()

        let fetched = try ctx.fetch(FetchDescriptor<Round>())
        let fetchedHole = try XCTUnwrap(fetched.first?.holeList.first(where: { $0.holeNumber == 1 }))
        XCTAssertEqual(fetchedHole.count(for: player.id), 5, "감소 편집 후 카운트는 5여야 해요")
    }

    // MARK: test_editRound_multiPlayer_onlyTargetChanged

    /// 2인 라운드에서 한 명만 편집 시 다른 플레이어 카운트는 불변이어야 한다.
    @MainActor
    func test_editRound_multiPlayer_onlyTargetChanged() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let playerA = Player(name: "A", isOwner: true, order: 0)
        let playerB = Player(name: "B", order: 1)
        [playerA, playerB].forEach { ctx.insert($0) }

        let round = Round(courseId: "c3", courseName: "다인 편집 테스트")
        round.isFinished = true
        ctx.insert(round)
        round.players = [playerA, playerB]

        let hole = HoleScore(holeNumber: 1, par: 4,
                             counts: [
                                ScoreEntry(playerId: playerA.id, value: 4),
                                ScoreEntry(playerId: playerB.id, value: 5),
                             ])
        ctx.insert(hole)
        round.holes = [hole]
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.editRound(round)

        // A만 +1 (4 → 5)
        if let idx = hole.counts.firstIndex(where: { $0.playerId == playerA.id }) {
            hole.counts[idx].value += 1
        }

        try vm.commitEdit()

        let fetched = try ctx.fetch(FetchDescriptor<Round>())
        let fetchedHole = try XCTUnwrap(fetched.first?.holeList.first(where: { $0.holeNumber == 1 }))

        XCTAssertEqual(fetchedHole.count(for: playerA.id), 5, "A 카운트는 5여야 해요")
        XCTAssertEqual(fetchedHole.count(for: playerB.id), 5, "B 카운트는 변경 없이 5여야 해요")
    }
}
