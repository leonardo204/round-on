import XCTest
import SwiftData
@testable import Shared

// MARK: - RoundResumeTests
// F6 확장: standby 복귀 시 마지막 홀/플레이어 복원 검증
// - Round.lastActive* 기본값 및 저장
// - HoleViewModel initialHoleNumber clamp
// - PlayerListViewModel initialIndex clamp
// - RoundViewModel.activate 복원 경로
// - resumeIfNeeded idempotent + lastActiveAt 우선 선택

final class RoundResumeTests: XCTestCase {

    // MARK: 헬퍼 — 인메모리 컨테이너

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeRound(holeCount: Int = 18, playerCount: Int = 2) -> Round {
        let players = (0..<playerCount).map { Player(name: "P\($0)", isOwner: $0 == 0, order: $0) }
        let holes = (1...holeCount).map { HoleScore(holeNumber: $0, par: 4) }
        let round = Round(courseId: "test", courseName: "테스트")
        round.players = players
        round.holes = holes
        return round
    }

    // MARK: Round 기본값 테스트

    @MainActor
    func test_Round_lastActiveDefaults() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = Round(courseId: "def", courseName: "기본값")
        ctx.insert(round)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Round>()).first!
        XCTAssertEqual(fetched.lastActiveHoleNumber, 1, "lastActiveHoleNumber 기본값은 1")
        XCTAssertEqual(fetched.lastActivePlayerIndex, 0, "lastActivePlayerIndex 기본값은 0")
        XCTAssertNil(fetched.lastActiveAt, "lastActiveAt 기본값은 nil")
    }

    @MainActor
    func test_Round_lastActiveFieldsPersist() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = Round(courseId: "p", courseName: "저장테스트")
        ctx.insert(round)
        round.lastActiveHoleNumber = 7
        round.lastActivePlayerIndex = 1
        round.lastActiveAt = Date(timeIntervalSince1970: 1000)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Round>()).first!
        XCTAssertEqual(fetched.lastActiveHoleNumber, 7)
        XCTAssertEqual(fetched.lastActivePlayerIndex, 1)
        XCTAssertNotNil(fetched.lastActiveAt)
    }

    // MARK: HoleViewModel initialHoleNumber clamp

    @MainActor
    func test_HoleViewModel_initClampsNormal() {
        let hvm = HoleViewModel(totalHoles: 18, initialHoleNumber: 5)
        XCTAssertEqual(hvm.currentHoleNumber, 5)
        XCTAssertEqual(hvm.currentHoleIndex, 4)
    }

    @MainActor
    func test_HoleViewModel_initClampsBelow1() {
        let hvm = HoleViewModel(totalHoles: 18, initialHoleNumber: 0)
        XCTAssertEqual(hvm.currentHoleNumber, 1, "0 이하는 1로 clamp")
    }

    @MainActor
    func test_HoleViewModel_initClampsAboveMax() {
        let hvm = HoleViewModel(totalHoles: 18, initialHoleNumber: 19)
        XCTAssertEqual(hvm.currentHoleNumber, 18, "총 홀 수 초과는 max로 clamp")
    }

    @MainActor
    func test_HoleViewModel_defaultIsHole1() {
        let hvm = HoleViewModel(totalHoles: 9)
        XCTAssertEqual(hvm.currentHoleNumber, 1, "initialHoleNumber 미지정 시 1홀")
    }

    // MARK: PlayerListViewModel initialIndex clamp

    @MainActor
    func test_PlayerListViewModel_initClampsNormal() {
        let players = [Player(name: "A", isOwner: true, order: 0),
                       Player(name: "B", isOwner: false, order: 1),
                       Player(name: "C", isOwner: false, order: 2)]
        let pvm = PlayerListViewModel(players: players, initialIndex: 2)
        XCTAssertEqual(pvm.activePlayerIndex, 2)
    }

    @MainActor
    func test_PlayerListViewModel_initClampsAboveMax() {
        let players = [Player(name: "A", isOwner: true, order: 0),
                       Player(name: "B", isOwner: false, order: 1)]
        let pvm = PlayerListViewModel(players: players, initialIndex: 5)
        XCTAssertEqual(pvm.activePlayerIndex, 1, "플레이어 수 초과 시 마지막 인덱스로 clamp")
    }

    @MainActor
    func test_PlayerListViewModel_initClampsNegative() {
        let players = [Player(name: "A", isOwner: true, order: 0)]
        let pvm = PlayerListViewModel(players: players, initialIndex: -1)
        XCTAssertEqual(pvm.activePlayerIndex, 0, "음수 인덱스는 0으로 clamp")
    }

    @MainActor
    func test_PlayerListViewModel_defaultIsIndex0() {
        let players = [Player(name: "A", isOwner: true, order: 0),
                       Player(name: "B", isOwner: false, order: 1)]
        let pvm = PlayerListViewModel(players: players)
        XCTAssertEqual(pvm.activePlayerIndex, 0, "initialIndex 미지정 시 0")
    }

    // MARK: RoundViewModel activate 복원

    @MainActor
    func test_activateRestoresHoleAndPlayer() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = makeRound(holeCount: 18, playerCount: 3)
        round.lastActiveHoleNumber = 9
        round.lastActivePlayerIndex = 2
        ctx.insert(round)
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.resumeIfNeeded()

        XCTAssertEqual(vm.holeViewModel?.currentHoleNumber, 9, "9홀로 복원")
        XCTAssertEqual(vm.playerListViewModel?.activePlayerIndex, 2, "플레이어 인덱스 2로 복원")
    }

    @MainActor
    func test_activateRestoresClampsOutOfRange() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = makeRound(holeCount: 9, playerCount: 2)
        round.lastActiveHoleNumber = 99  // 비정상 값
        round.lastActivePlayerIndex = 99 // 비정상 값
        ctx.insert(round)
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.resumeIfNeeded()

        XCTAssertEqual(vm.holeViewModel?.currentHoleNumber, 9, "99홀은 max(9)로 clamp")
        XCTAssertEqual(vm.playerListViewModel?.activePlayerIndex, 1, "인덱스 99는 max(1)로 clamp")
    }

    // MARK: resumeIfNeeded idempotent

    @MainActor
    func test_resumeIfNeeded_isIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = makeRound()
        round.lastActiveHoleNumber = 5
        ctx.insert(round)
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.resumeIfNeeded()
        let firstRound = vm.currentRound

        // 두 번째 호출 — 동일 라운드 활성 시 무동작
        vm.resumeIfNeeded()
        XCTAssertTrue(vm.currentRound === firstRound, "동일 라운드 이미 활성 시 교체 없음")
        XCTAssertEqual(vm.holeViewModel?.currentHoleNumber, 5, "홀 번호 변경 없음")
    }

    // MARK: resumeIfNeeded — lastActiveAt 기준 선택

    @MainActor
    func test_resumeIfNeeded_prefersLastActiveAt() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let older = makeRound()
        older.lastActiveAt = Date(timeIntervalSince1970: 1000)
        older.lastActiveHoleNumber = 3

        let newer = makeRound()
        newer.lastActiveAt = Date(timeIntervalSince1970: 2000)
        newer.lastActiveHoleNumber = 11

        ctx.insert(older)
        ctx.insert(newer)
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.resumeIfNeeded()

        XCTAssertEqual(vm.holeViewModel?.currentHoleNumber, 11, "lastActiveAt 최신 라운드(hole=11) 선택")
    }

    // MARK: lastActiveAt 없는 라운드 처리

    @MainActor
    func test_resumeIfNeeded_worksWhenLastActiveAtNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let round = makeRound()
        // lastActiveAt nil 상태 (기본값)
        round.lastActiveHoleNumber = 4
        ctx.insert(round)
        try ctx.save()

        let vm = RoundViewModel(modelContext: ctx)
        vm.resumeIfNeeded()

        XCTAssertEqual(vm.holeViewModel?.currentHoleNumber, 4)
    }
}
