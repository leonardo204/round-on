import XCTest
@testable import Shared

final class CourseRepositoryTests: XCTestCase {

    // MARK: 전체 로드

    func testLoadAllReturnsAllCourses() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        XCTAssertEqual(courses.count, 965, "v3 데이터셋은 965개 골프장을 포함해야 함 (좌표 2차 매칭 중복 제거 후)")
    }

    // MARK: dataQuality 분포

    func testDataQualityDistribution() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let groups = Dictionary(grouping: courses, by: { $0.dataQuality })

        XCTAssertEqual(groups[.complete]?.count ?? 0, 3,
                       "complete 등급 골프장은 3개여야 함 (F3 GPS 자동 감지 활성 후보)")
        XCTAssertEqual(groups[.partial]?.count ?? 0, 12,
                       "partial 등급 골프장은 12개여야 함")
        XCTAssertEqual(groups[.minimal]?.count ?? 0, 9,
                       "minimal 등급 골프장은 9개여야 함")
        XCTAssertEqual(groups[.low]?.count ?? 0, 941,
                       "low 등급이 압도적 다수(941개)여야 함")
    }

    // MARK: holesCount 커버리지

    func testHolesCountCoverage() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let withHolesCount = courses.filter { $0.holesCount != nil }.count
        XCTAssertEqual(withHolesCount, 818,
                       "holesCount가 기록된 골프장은 818개여야 함 (네이버 검색 보강 후)")
    }

    // MARK: 지역 필터

    func testRegionFilterGyeonggi() async throws {
        let gyeonggi = try await CourseRepository.shared.filter(region: "경기")
        XCTAssertGreaterThan(gyeonggi.count, 0, "경기 지역 골프장이 존재해야 함")
    }

    // MARK: region 보강 검증

    func testRegionCoverage() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let withRegion = courses.filter { !$0.region.isEmpty }.count
        // normalize_region.py 결과: 708 → 859 (주소 파싱으로 151건 추가)
        XCTAssertGreaterThanOrEqual(withRegion, 850,
            "region이 기록된 골프장이 850개 이상이어야 함 (normalize_region.py 결과 859건)")
    }

    // MARK: 카카오 URL

    func testKakaoUrlPresence() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let withKakao = courses.filter { $0.kakaoPlaceUrl != nil }.count
        XCTAssertEqual(withKakao, 664,
                       "kakaoPlaceUrl이 기록된 골프장은 664개여야 함 (카카오 API 보강 결과)")
    }

    // MARK: 이름 검색

    func testSearchByName() async throws {
        let results = try await CourseRepository.shared.search(byName: "한양")
        XCTAssertGreaterThan(results.count, 0, "'한양' 검색 결과가 존재해야 함")
        XCTAssertTrue(results.allSatisfy { $0.name.contains("한양") },
                      "검색 결과는 모두 '한양'을 포함해야 함")
    }

    func testSearchByEmptyStringReturnsAll() async throws {
        let all = try await CourseRepository.shared.loadAll()
        let searched = try await CourseRepository.shared.search(byName: "")
        XCTAssertEqual(searched.count, all.count, "빈 문자열 검색은 전체 목록을 반환해야 함")
    }

    // MARK: 디코딩 무결성 (clubhouse 중첩 구조)

    func testClubhouseCoordinatesDecodedCorrectly() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        // clubhouse 좌표가 있는 코스가 존재하는지 확인
        let withClubhouse = courses.filter { $0.clubhouse != nil }
        XCTAssertGreaterThan(withClubhouse.count, 0, "clubhouse 좌표가 있는 코스가 존재해야 함")

        // computed property 호환 확인
        if let first = withClubhouse.first, let ch = first.clubhouse {
            XCTAssertEqual(first.clubhouseLat, ch.lat)
            XCTAssertEqual(first.clubhouseLng, ch.lng)
        }
    }

    // MARK: holes 디코딩 (중첩 tee/green)

    func testHolesDecodedCorrectly() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let withHoles = courses.filter { !$0.holes.isEmpty }
        XCTAssertGreaterThan(withHoles.count, 0, "holes가 있는 코스가 존재해야 함")

        // tee/green 좌표가 올바르게 파싱됐는지 첫 번째 홀로 확인
        if let course = withHoles.first, let hole = course.holes.first {
            XCTAssertGreaterThan(hole.teeLat, 0, "teeLat은 0보다 커야 함")
            XCTAssertGreaterThan(hole.teeLng, 0, "teeLng은 0보다 커야 함")
        }
    }

    // MARK: 캐시 동작 (동일 인스턴스 재호출)

    func testLoadAllUsesCache() async throws {
        let first = try await CourseRepository.shared.loadAll()
        let second = try await CourseRepository.shared.loadAll()
        XCTAssertEqual(first.count, second.count, "캐시된 결과는 동일한 개수를 반환해야 함")
    }

    // MARK: subCourses 보강 검증

    func testSubCoursesPopulated() async throws {
        let courses = try await CourseRepository.shared.loadAll()
        let withSub = courses.filter { ($0.subCourses ?? []).count >= 2 }.count
        // enrich_subcourses.py v3 결과: 수동 매핑 47건 + 네이버 31건 = 78건 (기존 54건 포함 총 132건)
        // 패턴: hanja/theme/trad/newold/num/alpha/en_full 7종 + manual_subcourses.json
        XCTAssertGreaterThanOrEqual(withSub, 100,
            "subCourses 보유 코스가 100개 이상이어야 함 (enrich_subcourses.py v3 결과 132건)")
    }
}
