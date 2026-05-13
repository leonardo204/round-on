import Foundation

// MARK: - Haversine 거리 계산
// F3 GPS 자동 감지 — 골프장 단위 매칭에 사용 (Ref-docs/specs/01-SPEC.md §F3)
// haversine 공식: 구면삼각법 기반 위도/경도 → km 거리

/// 두 좌표 간 haversine 거리(km)를 반환하는 순수 함수.
///
/// - Parameters:
///   - lat1: 첫 번째 위도 (도, WGS84)
///   - lng1: 첫 번째 경도 (도, WGS84)
///   - lat2: 두 번째 위도 (도, WGS84)
///   - lng2: 두 번째 경도 (도, WGS84)
/// - Returns: 두 지점 간 거리 (km)
public func haversineKm(
    lat1: Double, lng1: Double,
    lat2: Double, lng2: Double
) -> Double {
    let earthRadiusKm = 6371.0

    let dLat = (lat2 - lat1).degreesToRadians
    let dLng = (lng2 - lng1).degreesToRadians

    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1.degreesToRadians) * cos(lat2.degreesToRadians)
        * sin(dLng / 2) * sin(dLng / 2)

    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadiusKm * c
}

// MARK: - Double 확장

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
