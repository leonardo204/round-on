import XCTest
import SwiftData
@testable import Shared

// MARK: - RoundCourseLabelingTests
// 라운드 코스 라벨링 시나리오 검증 (8건)
// Task 8: frontCourseName / backCourseName / displaySubLabel / guard(holesCount)

final class RoundCourseLabelingTests: XCTestCase {

    // MARK: 인메모리 컨테이너 헬퍼

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: (a) 9홀 라운드: backCourseName이 nil인 채로 startRound → holes.count == 9, backCourseName == nil

    @MainActor
    func test_9hole_backCourseNameIsNil() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "course-9h",
            courseName: "동해 CC",
            frontCourseName: "동코스",
            backCourseName: nil,
            players: [],
            holesCount: 9
        )

        let round = try XCTUnwrap(vm.currentRound, "9홀 startRound 후 currentRound가 설정되어야 한다")
        XCTAssertEqual(round.holeList.count, 9, "9홀 라운드의 holes.count는 9이어야 한다")
        XCTAssertNil(round.backCourseName, "9홀 라운드에서 backCourseName은 nil이어야 한다")
        XCTAssertEqual(round.frontCourseName, "동코스", "frontCourseName은 그대로 저장되어야 한다")
    }

    // MARK: (b) 18홀 전반+후반 둘 다 있음: displaySubLabel == "동코스 / 남코스"

    @MainActor
    func test_18hole_bothCourseNames_displaySubLabel() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "course-18h",
            courseName: "남해 GC",
            frontCourseName: "동코스",
            backCourseName: "남코스",
            players: [],
            holesCount: 18
        )

        let round = try XCTUnwrap(vm.currentRound)
        XCTAssertEqual(
            round.displaySubLabel,
            "동코스 / 남코스",
            "전반+후반 모두 있으면 ' / '로 합성되어야 한다"
        )
    }

    // MARK: (c) 18홀 전반만: displaySubLabel == "동코스"

    @MainActor
    func test_18hole_frontCourseNameOnly_displaySubLabel() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "course-18h-front",
            courseName: "서해 CC",
            frontCourseName: "동코스",
            backCourseName: nil,
            players: [],
            holesCount: 18
        )

        let round = try XCTUnwrap(vm.currentRound)
        XCTAssertEqual(
            round.displaySubLabel,
            "동코스",
            "전반만 있으면 전반 코스명만 반환되어야 한다"
        )
    }

    // MARK: (d) 18홀 후반만 (드문 케이스): displaySubLabel == "남코스"

    @MainActor
    func test_18hole_backCourseNameOnly_displaySubLabel() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "course-18h-back",
            courseName: "제주 리조트",
            frontCourseName: nil,
            backCourseName: "남코스",
            players: [],
            holesCount: 18
        )

        let round = try XCTUnwrap(vm.currentRound)
        XCTAssertEqual(
            round.displaySubLabel,
            "남코스",
            "후반만 있으면 후반 코스명만 반환되어야 한다"
        )
    }

    // MARK: (e) 둘 다 nil + legacy courseSubName 있음: displaySubLabel == legacy 값 (마이그레이션 안전)

    @MainActor
    func test_legacyCourseSubName_fallback() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // legacy 방식으로 직접 Round 생성 (마이그레이션 안전 회귀 방지)
        let round = Round(
            courseId: "legacy-course",
            courseName: "구형 골프장",
            courseSubName: "구형코스",  // legacy 필드만 설정
            frontCourseName: nil,
            backCourseName: nil
        )
        ctx.insert(round)
        try ctx.save()

        XCTAssertEqual(
            round.displaySubLabel,
            "구형코스",
            "frontCourseName/backCourseName 둘 다 nil이면 legacy courseSubName으로 폴백되어야 한다"
        )
    }

    // MARK: (f) 모두 nil: displaySubLabel == nil

    @MainActor
    func test_allNil_displaySubLabelIsNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let round = Round(
            courseId: "no-sub",
            courseName: "서울 CC",
            courseSubName: nil,
            frontCourseName: nil,
            backCourseName: nil
        )
        ctx.insert(round)
        try ctx.save()

        XCTAssertNil(
            round.displaySubLabel,
            "frontCourseName/backCourseName/courseSubName 모두 nil이면 displaySubLabel도 nil이어야 한다"
        )
    }

    // MARK: (g) holesCount == 27 → guard 동작 → currentRound nil 유지

    @MainActor
    func test_holesCount27_guardRejectsRound() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        // 27은 유효하지 않은 값 — guard 거부 + #if DEBUG print 출력 (release 빌드 크래시 없음)
        // XCTest에서 DEBUG print는 콘솔에 출력되나 테스트 실패/크래시를 유발하지 않음
        vm.startRound(
            courseId: "27h",
            courseName: "27홀 골프장",
            frontCourseName: nil,
            backCourseName: nil,
            players: [],
            holesCount: 27
        )

        XCTAssertNil(
            vm.currentRound,
            "holesCount == 27은 guard에서 거부되어 라운드가 생성되지 않아야 한다"
        )
    }

    // MARK: (h) holesCount == 13 (잘못된 값) → guard 동작

    @MainActor
    func test_holesCount13_guardRejectsRound() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "13h",
            courseName: "13홀 골프장",
            frontCourseName: nil,
            backCourseName: nil,
            players: [],
            holesCount: 13
        )

        XCTAssertNil(
            vm.currentRound,
            "holesCount == 13은 guard에서 거부되어 라운드가 생성되지 않아야 한다"
        )
    }

    // MARK: (i) [필수 #1 회귀 방지] 18홀+front+back → courseSubName이 displaySubLabel과 동기화

    @MainActor
    func test_legacy_courseSubName_synced_with_displaySubLabel() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        vm.startRound(
            courseId: "course-sync",
            courseName: "동해 CC",
            frontCourseName: "동코스",
            backCourseName: "남코스",
            players: [],
            holesCount: 18
        )

        let round = try XCTUnwrap(vm.currentRound, "18홀 startRound 후 currentRound가 설정되어야 한다")
        // legacy courseSubName은 displaySubLabel과 동일해야 한다 (마이그레이션 reader 안전)
        XCTAssertEqual(
            round.displaySubLabel,
            "동코스 / 남코스",
            "displaySubLabel은 '동코스 / 남코스'이어야 한다"
        )
        // courseSubName(legacy)도 동일 값으로 동기화되어야 한다
        // deprecated 프로퍼티 접근 — 테스트 내에서만 legacy 검증 목적으로 허용
        // swiftlint:disable:next deprecated_declaration
        XCTAssertEqual(
            round.courseSubName,
            "동코스 / 남코스",
            "legacy courseSubName은 displaySubLabel과 동일한 '동코스 / 남코스'이어야 한다"
        )
    }

    // MARK: (j) [필수 #2 회귀 방지] 9홀 startRound에 backCourseName 전달해도 ViewModel이 nil 강제

    @MainActor
    func test_9hole_back_normalized_to_nil() throws {
        let container = try makeContainer()
        let vm = RoundViewModel(modelContext: container.mainContext)

        // UI가 selectedBackSubCourse 리셋을 누락했다고 가정하여 backCourseName을 전달
        vm.startRound(
            courseId: "course-9h-back",
            courseName: "서해 CC",
            frontCourseName: "동코스",
            backCourseName: "남코스",  // 9홀인데 back을 전달 → ViewModel이 nil로 강제해야 함
            players: [],
            holesCount: 9
        )

        let round = try XCTUnwrap(vm.currentRound, "9홀 startRound 후 currentRound가 설정되어야 한다")
        XCTAssertNil(
            round.backCourseName,
            "9홀 라운드에서 ViewModel은 backCourseName을 nil로 강제해야 한다 (UI 누락 방어)"
        )
        XCTAssertEqual(
            round.holeList.count, 9,
            "9홀 라운드의 holes.count는 9이어야 한다"
        )
    }
}
