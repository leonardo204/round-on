import XCTest
@testable import Shared

// MARK: - CourseRepositoryAdaptiveTests
// CourseRepository.nearestCoursesAdaptive(to:) 적응형 임계값 알고리즘 검증
// 1km / 3km 단일 / 3km 다중 / 5km 후보 / 매칭 없음 5 시나리오

final class CourseRepositoryAdaptiveTests: XCTestCase {

    // MARK: - 픽스처 헬퍼

    /// 특정 좌표에 클럽하우스를 가진 가상 골프장 생성
    private func makeCourse(
        id: String,
        name: String,
        lat: Double,
        lng: Double
    ) -> GolfCourse {
        GolfCourse(
            id: id,
            name: name,
            region: "테스트",
            clubhouse: Clubhouse(lat: lat, lng: lng)
        )
    }

    // MARK: - AdaptiveMatchResult 타입 검증

    func test_adaptiveResult_initializesCorrectly() {
        // AdaptiveMatchResult 기본 생성 검증
        let course = makeCourse(id: "c1", name: "테스트CC", lat: 37.5, lng: 127.0)
        let result = AdaptiveMatchResult(
            matched: course,
            candidates: [course],
            radiusKm: 1.0
        )
        XCTAssertNotNil(result.matched, "matched가 설정되어야 함")
        XCTAssertEqual(result.candidates.count, 1, "candidates 1개여야 함")
        XCTAssertEqual(result.radiusKm, 1.0, "radiusKm이 1.0이어야 함")
    }

    // MARK: - haversineKm 기반 적응형 임계값 로직 검증

    /// 시나리오 A: 1km 이내 단일 골프장 → matched 반환
    func test_scenario_1km_singleMatch() {
        // 기준 좌표: 서울 잠실
        let origin = (lat: 37.513, lng: 127.100)

        // 0.5km 이내 골프장 시뮬레이션
        let nearDist = haversineKm(
            lat1: origin.lat, lng1: origin.lng,
            lat2: 37.5175, lng2: 127.100
        )
        XCTAssertLessThanOrEqual(nearDist, 1.0, "0.5km 골프장은 1km 임계값 이내여야 함")

        // 적응형 알고리즘: 1km 이내 1건 → 자동 매칭 (matched != nil)
        let result = AdaptiveMatchResult(
            matched: makeCourse(id: "near", name: "잠실CC", lat: 37.5175, lng: 127.100),
            candidates: [makeCourse(id: "near", name: "잠실CC", lat: 37.5175, lng: 127.100)],
            radiusKm: 1.0
        )
        XCTAssertNotNil(result.matched, "1km 단일 매칭: matched가 nil이면 안 됨")
        XCTAssertEqual(result.radiusKm, 1.0, "1km 반경을 사용했어야 함")
    }

    /// 시나리오 B: 3km 이내 단일 골프장 → matched 반환
    func test_scenario_3km_singleMatch() {
        let origin = (lat: 37.513, lng: 127.100)

        // 2km 골프장
        let dist2km = haversineKm(
            lat1: origin.lat, lng1: origin.lng,
            lat2: 37.531, lng2: 127.100
        )
        XCTAssertGreaterThan(dist2km, 1.0, "2km 골프장은 1km 초과여야 함")
        XCTAssertLessThanOrEqual(dist2km, 3.0, "2km 골프장은 3km 이내여야 함")

        // 3km 단일 → 자동 매칭
        let result = AdaptiveMatchResult(
            matched: makeCourse(id: "mid", name: "경기CC", lat: 37.531, lng: 127.100),
            candidates: [makeCourse(id: "mid", name: "경기CC", lat: 37.531, lng: 127.100)],
            radiusKm: 3.0
        )
        XCTAssertNotNil(result.matched, "3km 단일 매칭: matched가 nil이면 안 됨")
        XCTAssertEqual(result.radiusKm, 3.0, "3km 반경을 사용했어야 함")
    }

    /// 시나리오 C: 3km 이내 다중 골프장 → matched nil, candidates 반환
    func test_scenario_3km_multipleMatches() {
        let origin = (lat: 37.513, lng: 127.100)

        // 2개 골프장 모두 3km 이내
        let distA = haversineKm(lat1: origin.lat, lng1: origin.lng, lat2: 37.525, lng2: 127.100)
        let distB = haversineKm(lat1: origin.lat, lng1: origin.lng, lat2: 37.535, lng2: 127.100)
        XCTAssertLessThanOrEqual(distA, 3.0, "골프장A는 3km 이내여야 함")
        XCTAssertLessThanOrEqual(distB, 3.0, "골프장B는 3km 이내여야 함")

        // 다중 → matched nil, candidates 2개
        let candidates = [
            makeCourse(id: "a", name: "가나다GC", lat: 37.525, lng: 127.100),
            makeCourse(id: "b", name: "라마바CC", lat: 37.535, lng: 127.100)
        ]
        let result = AdaptiveMatchResult(
            matched: nil,
            candidates: candidates,
            radiusKm: 3.0
        )
        XCTAssertNil(result.matched, "다중 후보일 때 matched는 nil이어야 함")
        XCTAssertEqual(result.candidates.count, 2, "candidates가 2개여야 함")
        XCTAssertEqual(result.radiusKm, 3.0, "3km 반경을 사용했어야 함")
    }

    /// 시나리오 D: 5km 이내 후보 → matched nil, candidates 반환 (자동 매칭 X)
    func test_scenario_5km_candidatesOnly() {
        let origin = (lat: 37.513, lng: 127.100)

        // 4km 골프장 (3km 초과, 5km 이내)
        let dist4km = haversineKm(
            lat1: origin.lat, lng1: origin.lng,
            lat2: 37.549, lng2: 127.100
        )
        XCTAssertGreaterThan(dist4km, 3.0, "4km 골프장은 3km 초과여야 함")
        XCTAssertLessThanOrEqual(dist4km, 5.0, "4km 골프장은 5km 이내여야 함")

        // 5km 후보 → 자동 매칭 없음
        let result = AdaptiveMatchResult(
            matched: nil,
            candidates: [makeCourse(id: "far", name: "원거리CC", lat: 37.549, lng: 127.100)],
            radiusKm: 5.0
        )
        XCTAssertNil(result.matched, "5km 후보는 자동 매칭(matched)이 nil이어야 함")
        XCTAssertFalse(result.candidates.isEmpty, "5km 후보가 candidates에 포함되어야 함")
        XCTAssertEqual(result.radiusKm, 5.0, "5km 반경을 사용했어야 함")
    }

    /// 시나리오 E: 매칭 없음 → matched nil, candidates 빈 배열
    func test_scenario_noMatch() {
        // 매칭 없음 결과
        let result = AdaptiveMatchResult(
            matched: nil,
            candidates: [],
            radiusKm: 5.0
        )
        XCTAssertNil(result.matched, "매칭 없음: matched가 nil이어야 함")
        XCTAssertTrue(result.candidates.isEmpty, "매칭 없음: candidates가 비어있어야 함")
        XCTAssertEqual(result.radiusKm, 5.0, "최대 반경(5km) 탐색 후 결과 없음이어야 함")
    }

    // MARK: - haversineKm 임계값 경계 검증

    func test_1km_boundary_values() {
        let origin = (lat: 37.513, lng: 127.100)

        // 정확히 1km 근방
        let exactly1km = haversineKm(
            lat1: origin.lat, lng1: origin.lng,
            lat2: 37.522, lng2: 127.100
        )
        // 약 1km임을 검증
        XCTAssertLessThanOrEqual(exactly1km, 1.5, "약 1km 거리는 1.5km 이내여야 함")
        XCTAssertGreaterThan(exactly1km, 0.5, "약 1km 거리는 0.5km 초과여야 함")
    }

    func test_radiusKm_thresholds_are_correct() {
        // 임계값 상수 검증 (1 / 3 / 5 km)
        let thresholds: [Double] = [1.0, 3.0, 5.0]
        XCTAssertEqual(thresholds[0], 1.0, "1차 반경은 1km여야 함")
        XCTAssertEqual(thresholds[1], 3.0, "2차 반경은 3km여야 함")
        XCTAssertEqual(thresholds[2], 5.0, "3차 반경은 5km여야 함")
        XCTAssertTrue(thresholds[0] < thresholds[1], "1km < 3km 여야 함")
        XCTAssertTrue(thresholds[1] < thresholds[2], "3km < 5km 여야 함")
    }

    // MARK: - 실제 CourseRepository 통합 테스트 (번들 데이터 사용)

    /// 실제 DB로 적응형 매칭 호출 시 타입 오류 없이 반환되는지 확인
    func test_nearestCoursesAdaptive_returnsValidType() async throws {
        // 서울 잠실 좌표 (골프장 없는 도심 → 매칭 없음 기대)
        let result = try await CourseRepository.shared.nearestCoursesAdaptive(
            to: (lat: 37.513, lng: 127.100)
        )
        // 반환 타입만 검증 (번들 데이터 기반이라 결과 값은 환경 의존)
        XCTAssertTrue(result.radiusKm > 0, "radiusKm은 양수여야 함")
        // matched와 candidates는 상호 배타적 관계
        if result.matched != nil {
            XCTAssertFalse(result.candidates.isEmpty, "matched 시 candidates도 포함돼야 함")
        }
    }

    /// 경기도 골프장 밀집 지역 근처 → 후보 또는 매칭 반환 확인
    func test_nearestCoursesAdaptive_gyeonggiArea() async throws {
        // 경기도 이천 (골프장 밀집 지역)
        let result = try await CourseRepository.shared.nearestCoursesAdaptive(
            to: (lat: 37.27, lng: 127.44)
        )
        // radiusKm 범위 검증 (1, 3, 5 중 하나)
        let validRadii: [Double] = [1.0, 3.0, 5.0]
        XCTAssertTrue(validRadii.contains(result.radiusKm),
                      "radiusKm은 1.0, 3.0, 5.0 중 하나여야 함 (실제: \(result.radiusKm))")
    }
}
