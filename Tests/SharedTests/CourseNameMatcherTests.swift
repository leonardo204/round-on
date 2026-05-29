import XCTest
import SwiftData
@testable import Shared

// MARK: - CourseNameMatcherTests
// CourseNameMatcher.normalize / areSimilar / findConflictingRound 단위 테스트

final class CourseNameMatcherTests: XCTestCase {

    // MARK: - normalize 테스트

    func test_normalize_victoria_CC() {
        XCTAssertEqual(CourseNameMatcher.normalize("빅토리아 CC"), "빅토리아")
    }

    func test_normalize_blueone_countryClub() {
        XCTAssertEqual(CourseNameMatcher.normalize("BlueOne 컨트리클럽"), "blueone")
    }

    func test_normalize_GC_suffix() {
        XCTAssertEqual(CourseNameMatcher.normalize("한양 GC"), "한양")
    }

    func test_normalize_golfJang_suffix() {
        XCTAssertEqual(CourseNameMatcher.normalize("베어크리크 골프장"), "베어크리크")
    }

    func test_normalize_golfClub_suffix() {
        XCTAssertEqual(CourseNameMatcher.normalize("서울 골프클럽"), "서울")
    }

    func test_normalize_resort_english() {
        XCTAssertEqual(CourseNameMatcher.normalize("Pine Resort"), "pine")
    }

    func test_normalize_resort_korean() {
        XCTAssertEqual(CourseNameMatcher.normalize("파인 리조트"), "파인")
    }

    func test_normalize_countryClub_english() {
        // "Country Club" 접미사 제거
        XCTAssertEqual(CourseNameMatcher.normalize("Spring Country Club"), "spring")
    }

    func test_normalize_emptyString() {
        XCTAssertEqual(CourseNameMatcher.normalize(""), "")
    }

    func test_normalize_whitespaceOnly() {
        XCTAssertEqual(CourseNameMatcher.normalize("   "), "")
    }

    func test_normalize_noSuffix() {
        // 접미사 없으면 소문자 + 공백 제거만
        XCTAssertEqual(CourseNameMatcher.normalize("서울 스프링"), "서울스프링")
    }

    func test_normalize_internalSpacesRemoved() {
        XCTAssertEqual(CourseNameMatcher.normalize("Blue  One  CC"), "blueone")
    }

    func test_normalize_mixedCase_cc() {
        // "cc" lowercase 접미사 제거
        XCTAssertEqual(CourseNameMatcher.normalize("victoria cc"), "victoria")
    }

    // MARK: - areSimilar 테스트

    func test_areSimilar_victoria_vs_victoriaCC() {
        XCTAssertTrue(CourseNameMatcher.areSimilar("빅토리아", "빅토리아 CC"))
    }

    func test_areSimilar_victoriaCC_vs_victoria() {
        // 양방향
        XCTAssertTrue(CourseNameMatcher.areSimilar("빅토리아 CC", "빅토리아"))
    }

    func test_areSimilar_springCC_vs_summerCC_isFalse() {
        XCTAssertFalse(CourseNameMatcher.areSimilar("Spring CC", "Summer CC"))
    }

    func test_areSimilar_springHill_vs_spring() {
        // "spring"이 "springhill"에 포함됨 → true
        XCTAssertTrue(CourseNameMatcher.areSimilar("Spring Hill", "Spring"))
    }

    func test_areSimilar_spring_vs_springHill() {
        // 역방향
        XCTAssertTrue(CourseNameMatcher.areSimilar("Spring", "Spring Hill"))
    }

    func test_areSimilar_emptyA_isFalse() {
        XCTAssertFalse(CourseNameMatcher.areSimilar("", "빅토리아"))
    }

    func test_areSimilar_emptyB_isFalse() {
        XCTAssertFalse(CourseNameMatcher.areSimilar("빅토리아", ""))
    }

    func test_areSimilar_bothEmpty_isFalse() {
        XCTAssertFalse(CourseNameMatcher.areSimilar("", ""))
    }

    func test_areSimilar_whitespaceOnly_isFalse() {
        XCTAssertFalse(CourseNameMatcher.areSimilar("   ", "빅토리아"))
    }

    func test_areSimilar_identical_isTrue() {
        XCTAssertTrue(CourseNameMatcher.areSimilar("빅토리아", "빅토리아"))
    }

    func test_areSimilar_caseInsensitive() {
        XCTAssertTrue(CourseNameMatcher.areSimilar("VICTORIA", "victoria"))
    }

    func test_areSimilar_blueone_vs_blueoneCountryClub() {
        XCTAssertTrue(CourseNameMatcher.areSimilar("BlueOne", "BlueOne 컨트리클럽"))
    }

    // MARK: - findConflictingRound 테스트
    // ModelContainer를 인스턴스 변수로 유지하지 않으면 ARC 해제 후 fetch crash 발생.
    // 각 테스트에서 container를 로컬로 보유하고 mainContext를 사용한다.

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @MainActor
    func test_findConflictingRound_sameDay_similarCourse_returnsRound() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // 기존 라운드: 2026-05-25 빅토리아 CC
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10))!

        let existing = Round(courseId: "abc", courseName: "빅토리아 CC", startedAt: day)
        existing.date = day
        ctx.insert(existing)
        try ctx.save()

        // 탐지: 같은 날짜 + "빅토리아" (접미사 없는 버전)
        let result = CourseNameMatcher.findConflictingRound(
            date: day,
            courseName: "빅토리아",
            context: ctx
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.courseName, "빅토리아 CC")
    }

    @MainActor
    func test_findConflictingRound_differentDay_returnsNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10))!
        let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 26, hour: 10))!

        let existing = Round(courseId: "abc", courseName: "빅토리아 CC", startedAt: day1)
        existing.date = day1
        ctx.insert(existing)
        try ctx.save()

        // 다른 날짜 → nil
        let result = CourseNameMatcher.findConflictingRound(
            date: day2,
            courseName: "빅토리아",
            context: ctx
        )
        XCTAssertNil(result)
    }

    @MainActor
    func test_findConflictingRound_sameDayDifferentCourse_returnsRound() throws {
        // date-only 정책: 같은 날이면 코스명이 달라도(영문/한글 표기차 포함) 후보로 반환한다.
        // 최종 대체/새기록 판단은 사용자 확인 팝업이 담당.
        let container = try makeContainer()
        let ctx = container.mainContext

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10))!

        let existing = Round(courseId: "abc", courseName: "서울 CC", startedAt: day)
        existing.date = day
        ctx.insert(existing)
        try ctx.save()

        // 같은 날 + 다른 코스명(또는 영문/한글 표기차) → 후보 반환
        let result = CourseNameMatcher.findConflictingRound(
            date: day,
            courseName: "부산 GC",
            context: ctx
        )
        XCTAssertNotNil(result, "date-only: 같은 날이면 코스 달라도 충돌 후보로 반환되어야 함")
        XCTAssertEqual(result?.courseName, "서울 CC")
    }

    @MainActor
    func test_findConflictingRound_multipleConflicts_returnsMostRecent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10))!
        let dayLater = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 14))!

        let older = Round(courseId: "a1", courseName: "빅토리아", startedAt: day)
        older.date = day
        older.lastActiveAt = day
        ctx.insert(older)

        let newer = Round(courseId: "a2", courseName: "빅토리아 CC", startedAt: dayLater)
        newer.date = dayLater
        newer.lastActiveAt = dayLater
        ctx.insert(newer)

        try ctx.save()

        let result = CourseNameMatcher.findConflictingRound(
            date: day,
            courseName: "빅토리아",
            context: ctx
        )
        // lastActiveAt desc → 최신 라운드 반환
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.courseId, "a2")
    }

    @MainActor
    func test_findConflictingRound_noRoundsInDB_returnsNil() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 10))!

        let result = CourseNameMatcher.findConflictingRound(
            date: day,
            courseName: "빅토리아",
            context: ctx
        )
        XCTAssertNil(result)
    }
}
