import XCTest
import SwiftData
@testable import Shared

// MARK: - HoleLockTests
// 홀 자동 잠금 / 수동 해제 / 라운드 종료 전체 잠금 / 멘트 시스템 검증

final class HoleLockTests: XCTestCase {

    // MARK: 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, UserParOverride.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// 단순 라운드 + owner 플레이어 셋업 헬퍼
    @MainActor
    private func makeActiveRound(holesCount: Int = 9, in ctx: ModelContext) -> (RoundViewModel, Player) {
        let vm = RoundViewModel(modelContext: ctx)
        let owner = Player(name: "나", isOwner: true, order: 0)
        ctx.insert(owner)
        vm.startRound(
            courseId: "test_c1",
            courseName: "테스트장",
            players: [owner],
            holesCount: holesCount
        )
        return (vm, owner)
    }

    // MARK: test_nextHole_locksPreviousHoleWhenOwnerHasShots

    /// 다음 홀로 이동할 때 본인 샷이 있는 직전 홀이 isLocked = true가 되어야 한다.
    @MainActor
    func test_nextHole_locksPreviousHoleWhenOwnerHasShots() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let (vm, owner) = makeActiveRound(in: ctx)

        guard let round = vm.currentRound,
              let holeVM = vm.holeViewModel else {
            XCTFail("라운드 또는 holeVM 없음")
            return
        }

        // 1번 홀에 1타 입력
        vm.increment(holeNumber: 1, playerId: owner.id)
        XCTAssertEqual(round.holeList.first(where: { $0.holeNumber == 1 })?.count(for: owner.id), 1)

        // 2번 홀로 이동
        holeVM.nextHole()

        // 1번 홀이 잠겨야 함
        let hole1 = try XCTUnwrap(round.holeList.first(where: { $0.holeNumber == 1 }))
        XCTAssertTrue(hole1.isLocked, "본인 샷 있는 홀은 다음 홀 이동 시 잠겨야 합니다")
    }

    // MARK: test_nextHole_doesNotLockHoleWithZeroOwnerShots

    /// 본인 샷이 0인 홀은 다음 홀 이동 시 잠기지 않아야 한다.
    @MainActor
    func test_nextHole_doesNotLockHoleWithZeroOwnerShots() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let (vm, _) = makeActiveRound(in: ctx)

        guard let round = vm.currentRound,
              let holeVM = vm.holeViewModel else {
            XCTFail("라운드 또는 holeVM 없음")
            return
        }

        // 1번 홀 샷 입력 없이 다음 홀로 이동
        holeVM.nextHole()

        let hole1 = try XCTUnwrap(round.holeList.first(where: { $0.holeNumber == 1 }))
        XCTAssertFalse(hole1.isLocked, "본인 샷이 없으면 잠기지 않아야 합니다")
    }

    // MARK: test_unlockHole_setsIsLockedFalse

    /// unlockHole 호출 후 해당 홀의 isLocked가 false가 되어야 한다.
    @MainActor
    func test_unlockHole_setsIsLockedFalse() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let (vm, owner) = makeActiveRound(in: ctx)

        guard let round = vm.currentRound,
              let holeVM = vm.holeViewModel else {
            XCTFail("라운드 또는 holeVM 없음")
            return
        }

        // 1번 홀 샷 → 2번 홀 이동 → 1번 홀 잠금 확인
        vm.increment(holeNumber: 1, playerId: owner.id)
        holeVM.nextHole()
        let hole1 = try XCTUnwrap(round.holeList.first(where: { $0.holeNumber == 1 }))
        XCTAssertTrue(hole1.isLocked, "사전 조건: 잠겨 있어야 함")

        // 잠금 해제
        vm.unlockHole(1)
        XCTAssertFalse(hole1.isLocked, "unlockHole 후 isLocked는 false여야 합니다")
    }

    // MARK: test_unlockHole_allowsIncrementAfterUnlock

    /// 잠금 해제 후 increment가 다시 동작해야 한다.
    @MainActor
    func test_unlockHole_allowsIncrementAfterUnlock() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let (vm, owner) = makeActiveRound(in: ctx)

        guard let round = vm.currentRound,
              let holeVM = vm.holeViewModel else {
            XCTFail("라운드 또는 holeVM 없음")
            return
        }

        // 잠금
        vm.increment(holeNumber: 1, playerId: owner.id)
        holeVM.nextHole()
        let hole1 = try XCTUnwrap(round.holeList.first(where: { $0.holeNumber == 1 }))
        XCTAssertTrue(hole1.isLocked)

        // 잠금 상태에서 increment 차단 확인
        let blockedResult = vm.increment(holeNumber: 1, playerId: owner.id)
        XCTAssertFalse(blockedResult, "잠긴 홀에서 increment는 차단되어야 합니다")
        XCTAssertEqual(hole1.count(for: owner.id), 1, "잠긴 동안 카운트는 변하지 않아야 합니다")

        // 잠금 해제 후 increment 허용 확인
        vm.unlockHole(1)
        let okResult = vm.increment(holeNumber: 1, playerId: owner.id)
        XCTAssertTrue(okResult, "잠금 해제 후 increment는 성공해야 합니다")
        XCTAssertEqual(hole1.count(for: owner.id), 2, "잠금 해제 후 카운트는 2여야 합니다")
    }

    // MARK: test_finishRound_locksAllHoles

    /// finishRound 시 모든 홀이 isLocked = true가 되어야 한다.
    @MainActor
    func test_finishRound_locksAllHoles() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 9홀 라운드
        let vm = RoundViewModel(modelContext: ctx)
        let owner = Player(name: "나", isOwner: true, order: 0)
        ctx.insert(owner)
        vm.startRound(courseId: "c1", courseName: "종료 테스트", players: [owner], holesCount: 9)

        guard let round = vm.currentRound else {
            XCTFail("라운드 없음")
            return
        }

        // 일부 홀만 샷 입력
        vm.increment(holeNumber: 1, playerId: owner.id)
        vm.increment(holeNumber: 3, playerId: owner.id)

        // 라운드 종료
        vm.finishRound()

        // 모든 홀이 잠겨야 함 — DB에서 재조회
        let descriptor = FetchDescriptor<Round>()
        let fetched = try ctx.fetch(descriptor)
        let fetchedRound = try XCTUnwrap(fetched.first)
        for hole in fetchedRound.holeList {
            XCTAssertTrue(hole.isLocked, "\(hole.holeNumber)번 홀이 종료 시 잠겨야 합니다")
        }
    }

    // MARK: test_lockedHole_blocksDecrement

    /// 잠긴 홀에서 decrement도 차단되어야 한다.
    @MainActor
    func test_lockedHole_blocksDecrement() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let (vm, owner) = makeActiveRound(in: ctx)

        guard let round = vm.currentRound,
              let holeVM = vm.holeViewModel else {
            XCTFail("라운드 또는 holeVM 없음")
            return
        }

        vm.increment(holeNumber: 1, playerId: owner.id)
        vm.increment(holeNumber: 1, playerId: owner.id)
        holeVM.nextHole()

        let hole1 = try XCTUnwrap(round.holeList.first(where: { $0.holeNumber == 1 }))
        let countBeforeDecrement = hole1.count(for: owner.id)
        XCTAssertTrue(hole1.isLocked)

        vm.decrement(holeNumber: 1, playerId: owner.id)
        XCTAssertEqual(hole1.count(for: owner.id), countBeforeDecrement, "잠긴 홀에서 decrement는 차단되어야 합니다")
    }

    // MARK: test_holeResultMessage_birdie

    /// HoleResultMessage.text(for: .birdie)는 빈 문자열이 아니고 60자 이하여야 한다.
    func test_holeResultMessage_birdie() {
        let msg = HoleResultMessage.text(for: .birdie)
        XCTAssertFalse(msg.isEmpty, "버디 멘트가 비어있으면 안 됩니다")
        XCTAssertLessThanOrEqual(msg.count, 60, "버디 멘트는 60자 이하여야 합니다. 실제: \(msg.count)자")
    }

    // MARK: test_holeResultMessage_par

    func test_holeResultMessage_par() {
        let msg = HoleResultMessage.text(for: .par)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertLessThanOrEqual(msg.count, 60, "파 멘트는 60자 이하여야 합니다. 실제: \(msg.count)자")
    }

    // MARK: test_holeResultMessage_bogey

    func test_holeResultMessage_bogey() {
        let msg = HoleResultMessage.text(for: .bogey)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertLessThanOrEqual(msg.count, 60, "보기 멘트는 60자 이하여야 합니다. 실제: \(msg.count)자")
    }

    // MARK: test_holeResultMessage_double

    func test_holeResultMessage_double() {
        let msg = HoleResultMessage.text(for: .double)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertLessThanOrEqual(msg.count, 60, "더블 멘트는 60자 이하여야 합니다. 실제: \(msg.count)자")
    }

    // MARK: test_lockedHole_defaultIsFalse

    /// 새 HoleScore는 기본값 isLocked = false여야 한다.
    func test_lockedHole_defaultIsFalse() {
        let hole = HoleScore(holeNumber: 1, par: 4)
        XCTAssertFalse(hole.isLocked, "새 HoleScore의 isLocked 기본값은 false여야 합니다")
    }
}
