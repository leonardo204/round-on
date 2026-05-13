import XCTest
@testable import Shared

// MARK: - HaversineTests
// Shared/Geo/Haversine.swift haversineKm() 검증

final class HaversineTests: XCTestCase {

    // MARK: - 동일 좌표 → 0km

    func test_sameCoord_returnsZero() {
        let dist = haversineKm(lat1: 37.5, lng1: 127.0, lat2: 37.5, lng2: 127.0)
        XCTAssertEqual(dist, 0.0, accuracy: 0.001, "동일 좌표는 거리가 0이어야 해요")
    }

    // MARK: - 서울 ↔ 부산 약 325km

    func test_seoulToBusan_approximately325km() {
        // 서울시청: 37.5665, 126.9780
        // 부산시청: 35.1796, 129.0756
        let dist = haversineKm(
            lat1: 37.5665, lng1: 126.9780,
            lat2: 35.1796, lng2: 129.0756
        )
        // 실제 직선 거리 약 325~330km
        XCTAssertGreaterThan(dist, 300, "서울-부산 거리는 300km 이상이어야 해요")
        XCTAssertLessThan(dist, 360, "서울-부산 거리는 360km 미만이어야 해요")
    }

    // MARK: - 대칭성 검증 (A→B == B→A)

    func test_symmetry() {
        let a = haversineKm(lat1: 37.5, lng1: 127.0, lat2: 36.0, lng2: 128.0)
        let b = haversineKm(lat1: 36.0, lng1: 128.0, lat2: 37.5, lng2: 127.0)
        XCTAssertEqual(a, b, accuracy: 0.001, "haversine 거리는 대칭이어야 해요")
    }

    // MARK: - 골프장 근처 (3km 이내)

    func test_nearCourse_within3km() {
        // 한양CC 클럽하우스 예시 좌표 (가상)
        let courseCoord = (lat: 37.4, lng: 127.1)
        // 2km 떨어진 위치 (위도 0.018도 ≈ 2km)
        let nearbyCoord = (lat: 37.4 + 0.018, lng: 127.1)
        let dist = haversineKm(
            lat1: nearbyCoord.lat, lng1: nearbyCoord.lng,
            lat2: courseCoord.lat, lng2: courseCoord.lng
        )
        XCTAssertLessThan(dist, 3.0, "2km 인근은 3km 이내여야 해요")
    }

    // MARK: - 골프장 멀리 (3km 초과)

    func test_farCourse_beyond3km() {
        let courseCoord = (lat: 37.4, lng: 127.1)
        // 5km 떨어진 위치 (위도 0.045도 ≈ 5km)
        let farCoord = (lat: 37.4 + 0.045, lng: 127.1)
        let dist = haversineKm(
            lat1: farCoord.lat, lng1: farCoord.lng,
            lat2: courseCoord.lat, lng2: courseCoord.lng
        )
        XCTAssertGreaterThan(dist, 3.0, "5km 위치는 3km를 초과해야 해요")
    }
}
