import XCTest
import SwiftData
@testable import Shared

// MARK: - RoundViewModelHealthKitTests
// A4: HealthKit 클로저 DI 검증
// @MainActor throws 동기 테스트 패턴 사용 (ScoreCardViewModelTests와 동일 방식)
// onWorkoutStart/End는 Task로 비동기 실행되므로 XCTestExpectation 사용

final class RoundViewModelHealthKitTests: XCTestCase {

    // MARK: 헬퍼 — 인메모리 컨테이너

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: startRound → onWorkoutStart 호출

    @MainActor
    func test_startRound_callsWorkoutStart() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)
        let expectation = expectation(description: "onWorkoutStart 호출")
        var calledCourseName: String?

        vm.onWorkoutStart = { name in
            calledCourseName = name
            expectation.fulfill()
        }

        vm.startRound(
            courseId: "test-id",
            courseName: "남해 클럽",
            courseSubName: nil,
            players: [],
            holesCount: 18
        )

        waitForExpectations(timeout: 3.0)
        XCTAssertEqual(calledCourseName, "남해 클럽", "startRound 호출 시 골프장 이름을 onWorkoutStart에 전달해야 한다")
    }

    // MARK: finishRound → onWorkoutEnd 호출

    @MainActor
    func test_finishRound_callsWorkoutEnd() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)
        let expectation = expectation(description: "onWorkoutEnd 호출")

        vm.onWorkoutEnd = {
            expectation.fulfill()
        }

        vm.startRound(
            courseId: "test-id",
            courseName: "남해 클럽",
            courseSubName: nil,
            players: [],
            holesCount: 9
        )
        XCTAssertTrue(vm.isRoundActive, "startRound 후 라운드가 활성화되어야 한다")

        vm.finishRound()
        XCTAssertFalse(vm.isRoundActive, "finishRound 후 라운드가 비활성화되어야 한다")

        waitForExpectations(timeout: 3.0)
    }

    // MARK: HealthKit 권한 실패 시 라운드 정상 진행

    @MainActor
    func test_workoutStartFailure_roundContinues() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)
        let expectation = expectation(description: "onWorkoutStart 호출 (권한 거부 시뮬레이션)")

        vm.onWorkoutStart = { _ in
            // 권한 거부 시뮬레이션: 아무것도 하지 않음
            expectation.fulfill()
        }
        vm.onWorkoutBannerUpdate = {
            return "건강 데이터 권한이 없어 운동 기록이 저장되지 않습니다."
        }

        vm.startRound(
            courseId: "test-id",
            courseName: "서울 CC",
            courseSubName: nil,
            players: [],
            holesCount: 18
        )

        // 라운드는 즉시 시작되어야 함 (HealthKit과 무관)
        XCTAssertTrue(vm.isRoundActive, "HealthKit 권한 실패해도 라운드는 정상 진행되어야 한다")
        XCTAssertNotNil(vm.currentRound, "currentRound가 설정되어야 한다")

        waitForExpectations(timeout: 3.0)
    }

    // MARK: 클로저 미주입 시에도 크래시 없음

    @MainActor
    func test_noWorkoutClosures_noCrash() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        // 클로저 주입 없이 startRound/finishRound 호출
        vm.startRound(
            courseId: "test",
            courseName: "클럽",
            courseSubName: nil,
            players: [],
            holesCount: 18
        )
        XCTAssertTrue(vm.isRoundActive, "startRound 후 활성화되어야 한다")

        vm.finishRound()
        XCTAssertFalse(vm.isRoundActive, "finishRound 후 비활성화되어야 한다")

        // 내부 Task들이 완료될 시간 대기 (expectation 없이 짧게 sleep)
        Thread.sleep(forTimeInterval: 0.3)
    }
}
