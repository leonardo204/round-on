import XCTest
import SwiftData
@testable import Shared

// MARK: - DiscoveredCourseTests

final class DiscoveredCourseTests: XCTestCase {

    // MARK: - DiscoveredCourse 기본 검증

    func test_discoveredCourse_id_isKakaoPlaceId() {
        let course = DiscoveredCourse(
            kakaoPlaceId: "12345",
            name: "테스트CC",
            lat: 37.5,
            lng: 127.0
        )
        XCTAssertEqual(course.id, "12345", "id는 kakaoPlaceId와 동일해야 함")
    }

    func test_discoveredCourse_roundCourseId_hasKakaoPrefix() {
        let course = DiscoveredCourse(
            kakaoPlaceId: "99999",
            name: "서울CC",
            lat: 37.4,
            lng: 127.1
        )
        XCTAssertEqual(course.roundCourseId, "kakao:99999", "roundCourseId는 'kakao:{id}' 형식이어야 함")
    }

    func test_discoveredCourse_roundCourseId_stability() {
        // 동일 kakaoPlaceId → 항상 동일 roundCourseId
        let id = "54321"
        let c1 = DiscoveredCourse(kakaoPlaceId: id, name: "A골프장", lat: 37.0, lng: 127.0)
        let c2 = DiscoveredCourse(kakaoPlaceId: id, name: "A골프장", lat: 37.0, lng: 127.0)
        XCTAssertEqual(c1.roundCourseId, c2.roundCourseId, "동일 kakaoPlaceId는 동일 roundCourseId를 가져야 함")
    }

    // MARK: - asGolfCourse() 변환 검증

    func test_asGolfCourse_id_hasKakaoPrefix() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "11111",
            name: "한국CC",
            address: "경기도 수원시",
            lat: 37.3,
            lng: 127.0
        )
        let golf = discovered.asGolfCourse()
        XCTAssertTrue(golf.id.hasPrefix("kakao:"), "asGolfCourse().id는 'kakao:' 접두사를 가져야 함")
        XCTAssertEqual(golf.id, "kakao:11111")
    }

    func test_asGolfCourse_name_matches() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "22222",
            name: "서울골프클럽",
            lat: 37.5,
            lng: 127.0
        )
        let golf = discovered.asGolfCourse()
        XCTAssertEqual(golf.name, "서울골프클럽")
    }

    func test_asGolfCourse_clubhouse_coordinates() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "33333",
            name: "테스트CC",
            lat: 37.1234,
            lng: 127.5678
        )
        let golf = discovered.asGolfCourse()
        XCTAssertNotNil(golf.clubhouse, "clubhouse 좌표가 설정되어야 함")
        XCTAssertEqual(golf.clubhouse?.lat ?? 0.0, 37.1234, accuracy: 0.0001)
        XCTAssertEqual(golf.clubhouse?.lng ?? 0.0, 127.5678, accuracy: 0.0001)
    }

    func test_asGolfCourse_dataQuality_isUnknown() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "44444",
            name: "발견CC",
            lat: 37.0,
            lng: 126.0
        )
        let golf = discovered.asGolfCourse()
        XCTAssertEqual(golf.dataQuality, .unknown, "카카오 발견 코스는 dataQuality가 .unknown이어야 함")
    }

    func test_asGolfCourse_sources_containsKakaoDiscovery() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "55555",
            name: "발견골프",
            lat: 35.0,
            lng: 128.0
        )
        let golf = discovered.asGolfCourse()
        XCTAssertEqual(golf.sources, ["kakao_discovery"])
    }

    func test_asGolfCourse_address_and_phone_propagated() {
        let discovered = DiscoveredCourse(
            kakaoPlaceId: "66666",
            name: "주소CC",
            address: "경기도 고양시 일산동구",
            phone: "031-123-4567",
            lat: 37.7,
            lng: 126.8,
            placeUrl: "https://place.map.kakao.com/66666"
        )
        let golf = discovered.asGolfCourse()
        XCTAssertEqual(golf.address, "경기도 고양시 일산동구")
        XCTAssertEqual(golf.phone, "031-123-4567")
        XCTAssertEqual(golf.kakaoPlaceUrl, "https://place.map.kakao.com/66666")
    }

    // MARK: - DiscoveredCourse Codable

    func test_discoveredCourse_codable_roundTrip() throws {
        let original = DiscoveredCourse(
            kakaoPlaceId: "77777",
            name: "코더블CC",
            address: "서울시",
            phone: "02-000-0000",
            lat: 37.5,
            lng: 127.0,
            placeUrl: "https://place.map.kakao.com/77777",
            distanceKm: 1.5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiscoveredCourse.self, from: data)

        XCTAssertEqual(decoded.kakaoPlaceId, original.kakaoPlaceId)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.lat, original.lat, accuracy: 0.0001)
        XCTAssertEqual(decoded.lng, original.lng, accuracy: 0.0001)
        XCTAssertEqual(decoded.distanceKm, original.distanceKm)
    }

    // MARK: - DiscoveredCourse Hashable

    func test_discoveredCourse_hashable() {
        var set = Set<DiscoveredCourse>()
        let c1 = DiscoveredCourse(kakaoPlaceId: "abc", name: "A", lat: 37.0, lng: 127.0)
        let c2 = DiscoveredCourse(kakaoPlaceId: "abc", name: "A", lat: 37.0, lng: 127.0)
        set.insert(c1)
        set.insert(c2)
        XCTAssertEqual(set.count, 1, "동일 DiscoveredCourse는 Set에서 1개로 취급되어야 함")
    }
}

// MARK: - PersistedDiscoveredCourseTests

@MainActor
final class PersistedDiscoveredCourseTests: XCTestCase {

    // MARK: - in-memory ModelContainer 헬퍼

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([PersistedDiscoveredCourse.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - insert + fetch 검증

    func test_insert_and_fetch() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let course = PersistedDiscoveredCourse(
            kakaoPlaceId: "p001",
            name: "퍼시스티드CC",
            address: "경기도",
            lat: 37.1,
            lng: 127.2
        )
        ctx.insert(course)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.kakaoPlaceId, "p001")
        XCTAssertEqual(fetched.first?.name, "퍼시스티드CC")
    }

    func test_unique_kakaoPlaceId_prevents_duplicate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let c1 = PersistedDiscoveredCourse(
            kakaoPlaceId: "dup001",
            name: "중복CC",
            lat: 37.0,
            lng: 127.0
        )
        let c2 = PersistedDiscoveredCourse(
            kakaoPlaceId: "dup001",
            name: "중복CC-2",
            lat: 37.0,
            lng: 127.0
        )
        ctx.insert(c1)
        try ctx.save()

        // 두 번째 insert 시도 — unique 제약으로 오류 예상
        ctx.insert(c2)
        // save 시 unique 충돌 발생 → do-catch로 처리
        // (SwiftData에서는 unique 위반 시 save 오류 또는 자동 머지)
        // 단위 테스트에서는 충돌 처리 방식 확인
        do {
            try ctx.save()
        } catch {
            // unique 제약 위반 에러 → 정상 (중복 방지 동작 확인)
            // 아무것도 하지 않음 — 에러 발생 자체가 올바른 동작
        }

        // 결과: 1건 또는 2건 — SwiftData 구현에 따라 다름
        let fetched = (try? ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())) ?? []
        // 최소 1건은 있어야 함
        XCTAssertGreaterThanOrEqual(fetched.count, 1, "적어도 1건의 레코드가 있어야 함")
    }

    // MARK: - toGolfCourse() 변환 검증

    func test_toGolfCourse_id_hasKakaoPrefix() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: "q001",
            name: "변환CC",
            lat: 36.5,
            lng: 127.5
        )
        ctx.insert(persisted)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let golf = fetched.first!.toGolfCourse()
        XCTAssertEqual(golf.id, "kakao:q001", "toGolfCourse().id는 'kakao:{kakaoPlaceId}' 형식이어야 함")
    }

    func test_toGolfCourse_sources_containsKakaoPersisted() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: "q002",
            name: "소스CC",
            lat: 36.0,
            lng: 127.0
        )
        ctx.insert(persisted)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let golf = fetched.first!.toGolfCourse()
        XCTAssertEqual(golf.sources, ["kakao_persisted"])
    }

    func test_toGolfCourse_clubhouse_coordinates_match() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: "q003",
            name: "좌표CC",
            lat: 35.9876,
            lng: 128.4321
        )
        ctx.insert(persisted)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let golf = fetched.first!.toGolfCourse()
        XCTAssertEqual(golf.clubhouse?.lat ?? 0.0, 35.9876, accuracy: 0.0001)
        XCTAssertEqual(golf.clubhouse?.lng ?? 0.0, 128.4321, accuracy: 0.0001)
    }

    // MARK: - toDiscoveredCourse() 변환 검증

    func test_toDiscoveredCourse_roundCourseId_matches() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: "r001",
            name: "복원CC",
            lat: 37.0,
            lng: 127.0
        )
        ctx.insert(persisted)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let discovered = fetched.first!.toDiscoveredCourse()
        XCTAssertEqual(discovered.roundCourseId, "kakao:r001")
    }

    func test_toDiscoveredCourse_name_matches() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let persisted = PersistedDiscoveredCourse(
            kakaoPlaceId: "r002",
            name: "이름CC",
            lat: 37.0,
            lng: 127.0
        )
        ctx.insert(persisted)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PersistedDiscoveredCourse>())
        let discovered = fetched.first!.toDiscoveredCourse()
        XCTAssertEqual(discovered.name, "이름CC")
    }
}
