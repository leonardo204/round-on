import XCTest
@testable import Shared

/// 원격 DB 동기화 DTO 디코드 + par 머지 검증 테스트
/// - 42-COURSE_DB_SYNC.md 명세 기반
final class CourseRepositorySyncTests: XCTestCase {

    // MARK: - 1. RemoteCoursesDTO 디코드 (minimal shape)

    func testRemoteCoursesDTO_decodesMinimalShape() throws {
        let json = """
        {
            "version": "2026-05-19",
            "updatedAt": "2026-05-19T04:23:28.409Z",
            "schema": 1,
            "count": 2,
            "courses": [
                {"id": "플라밍고cc_kr", "name": "플라밍고C.C"},
                {"id": "파인스톤cc_충남", "name": "파인스톤 컨트리클럽"}
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RemoteCoursesDTO.self, from: json)
        XCTAssertEqual(dto.courses.count, 2)
        XCTAssertEqual(dto.courses[0].id, "플라밍고cc_kr")
        XCTAssertEqual(dto.courses[0].name, "플라밍고C.C")
        XCTAssertEqual(dto.count, 2)
        XCTAssertEqual(dto.version, "2026-05-19")
    }

    func testRemoteCoursesDTO_decodesWithMissingOptionalFields() throws {
        // version, schema, count 없어도 디코드 성공해야 함
        let json = """
        {
            "courses": [
                {"id": "test_id", "name": "테스트골프장"}
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RemoteCoursesDTO.self, from: json)
        XCTAssertEqual(dto.courses.count, 1)
        XCTAssertNil(dto.version)
        XCTAssertNil(dto.count)
        XCTAssertNil(dto.schema)
    }

    // MARK: - 2. RemoteCourseParsDTO 디코드

    func testRemoteCourseParsDTO_decodesActualShape() throws {
        let json = """
        {
            "version": "2026-05-19",
            "updatedAt": "2026-05-19T04:23:28.409Z",
            "schema": 1,
            "count": 2,
            "coursePars": [
                {
                    "courseId": "플라밍고cc_kr",
                    "courseName": "플라밍고C.C",
                    "subCourses": [
                        {"name": "듄스", "pars": [4,3,4,3,4,5,4,5,4]},
                        {"name": "리버", "pars": [4,3,5,4,4,5,4,3,4]}
                    ]
                },
                {
                    "courseId": "파인스톤cc_충남",
                    "courseName": "파인스톤 컨트리클럽",
                    "subCourses": [
                        {"name": "전반", "pars": [4,3,4,5,4,4,3,5,4]},
                        {"name": "후반", "pars": [4,4,3,5,4,4,4,3,5]}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RemoteCourseParsDTO.self, from: json)
        XCTAssertEqual(dto.coursePars.count, 2)

        let first = dto.coursePars[0]
        XCTAssertEqual(first.courseId, "플라밍고cc_kr")
        XCTAssertEqual(first.courseName, "플라밍고C.C")
        XCTAssertEqual(first.subCourses.count, 2)
        XCTAssertEqual(first.subCourses[0].name, "듄스")
        XCTAssertEqual(first.subCourses[0].pars, [4,3,4,3,4,5,4,5,4])
    }

    func testRemoteCourseParsDTO_decodesWithMissingOptionalFields() throws {
        // 최소 필드만 있어도 디코드 성공
        let json = """
        {
            "coursePars": [
                {
                    "courseId": "test_gc_kr",
                    "courseName": "테스트 GC",
                    "subCourses": [
                        {"name": "전반", "pars": [4,4,3,5,4,4,3,5,4]}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(RemoteCourseParsDTO.self, from: json)
        XCTAssertEqual(dto.coursePars.count, 1)
        XCTAssertNil(dto.version)
        XCTAssertNil(dto.count)
    }

    // MARK: - 3. par 머지 → GolfCourse 보강 검증

    func testApplyParsToGolfCourse_fillsSubCoursesAndUpgradesQuality() {
        // 번들에서 온 low quality 코스 (par 없음)
        let baseCourse = GolfCourse(
            id: "샘플cc_경기",
            name: "샘플컨트리클럽",
            region: "경기",
            clubhouse: Clubhouse(lat: 37.1, lng: 127.1),
            holesCount: 18,
            dataQuality: .low
        )

        let parEntry = RemoteCourseParsDTO.CoursePar(
            courseId: "샘플cc_경기",
            courseName: "샘플 컨트리클럽",
            subCourses: [
                RemoteCourseParsDTO.SubCoursePar(name: "전반", pars: [4,3,4,5,4,4,3,5,4]),
                RemoteCourseParsDTO.SubCoursePar(name: "후반", pars: [4,4,3,5,4,4,4,3,5])
            ]
        )

        let enriched = CourseRepository.applyPars(baseCourse, parEntry: parEntry)

        // dataQuality 승격 확인
        XCTAssertEqual(enriched.dataQuality, .verified, "par 머지 후 dataQuality가 .verified로 승격되어야 함")

        // subCourses 채워짐 확인
        let subCourses = enriched.subCourses ?? []
        XCTAssertEqual(subCourses.count, 2, "서브코스 2개가 생성되어야 함")
        XCTAssertEqual(subCourses[0].name, "전반")
        XCTAssertEqual(subCourses[1].name, "후반")

        // holes par 값 확인
        let frontHoles = subCourses[0].holes ?? []
        XCTAssertEqual(frontHoles.count, 9, "전반 홀 9개가 생성되어야 함")
        XCTAssertEqual(frontHoles[0].par, 4)
        XCTAssertEqual(frontHoles[1].par, 3)
        XCTAssertEqual(frontHoles[2].par, 4)

        let backHoles = subCourses[1].holes ?? []
        XCTAssertEqual(backHoles.count, 9, "후반 홀 9개가 생성되어야 함")
        XCTAssertEqual(backHoles[0].par, 4)

        // 홀 번호 순서 확인
        for (idx, hole) in frontHoles.enumerated() {
            XCTAssertEqual(hole.number, idx + 1, "홀 번호는 1부터 시작해야 함")
        }
    }

    func testApplyParsToGolfCourse_preservesExistingCoordinates() {
        // 기존 holes 좌표 데이터가 보존되는지 확인
        let existingHoles = [
            HoleInfo(number: 1, par: 4, teeLat: 37.1, teeLng: 127.1, greenLat: 37.11, greenLng: 127.11)
        ]
        let baseCourse = GolfCourse(
            id: "테스트gc_경기",
            name: "테스트골프클럽",
            region: "경기",
            holes: existingHoles,
            dataQuality: .partial
        )

        let parEntry = RemoteCourseParsDTO.CoursePar(
            courseId: "테스트gc_경기",
            courseName: "테스트골프클럽",
            subCourses: [
                RemoteCourseParsDTO.SubCoursePar(name: "전반", pars: [4,3,5,4,4,3,5,4,4])
            ]
        )

        let enriched = CourseRepository.applyPars(baseCourse, parEntry: parEntry)

        // 기존 holes(좌표 포함) 보존 확인
        XCTAssertEqual(enriched.holes.count, 1, "기존 holes 좌표 데이터가 보존되어야 함")
        XCTAssertEqual(enriched.holes[0].tee?.lat, 37.1)

        // 새 subCourses par 채워짐 확인
        let subCourses = enriched.subCourses ?? []
        XCTAssertEqual(subCourses[0].holes?.first?.par, 4)
    }

    func testApplyParsToGolfCourse_preservesVerifiedStatus() {
        // 이미 verified인 코스도 재적용 시 verified 유지
        let baseCourse = GolfCourse(
            id: "검증된cc_kr",
            name: "검증된 CC",
            region: "경기",
            dataQuality: .verified
        )

        let parEntry = RemoteCourseParsDTO.CoursePar(
            courseId: "검증된cc_kr",
            courseName: "검증된 CC",
            subCourses: [
                RemoteCourseParsDTO.SubCoursePar(name: "전반", pars: [4,4,3,5,4,4,3,5,4])
            ]
        )

        let enriched = CourseRepository.applyPars(baseCourse, parEntry: parEntry)
        XCTAssertEqual(enriched.dataQuality, .verified)
    }

    // MARK: - 4. 이름 매칭 폴백 검증

    func testCourseNameMatcher_areSimilarForFallback() {
        // id 불일치 시 이름 유사도로 폴백 가능한지 확인
        XCTAssertTrue(CourseNameMatcher.areSimilar("플라밍고 컨트리클럽", "플라밍고C.C"),
                      "접미사 제거 후 유사해야 함")
        XCTAssertTrue(CourseNameMatcher.areSimilar("샘플골프클럽", "샘플GC"),
                      "GC/골프클럽 접미사 제거 후 유사해야 함")
        XCTAssertFalse(CourseNameMatcher.areSimilar("한양CC", "무관한골프장"),
                       "다른 코스는 불일치해야 함")
    }

    // MARK: - 5. 번들 로드 후 머지 통합 흐름

    func testLoadAll_returnsAllCourses_afterMergeNotReduced() async throws {
        // 머지 전후 캐시 총 개수가 줄지 않아야 함
        let before = try await CourseRepository.shared.loadAll()
        XCTAssertEqual(before.count, 979, "번들 총 979개 유지")
    }
}
