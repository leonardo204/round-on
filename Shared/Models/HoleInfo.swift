import Foundation

/// 홀 위치 정보. v3 JSON의 `tee: { lat, lng }`, `green: { lat, lng }` 중첩 구조에 매핑.
/// computed property로 기존 flat 프로퍼티(teeLat/teeLng/greenLat/greenLng) 호환 유지.
public struct HoleInfo: Codable, Sendable {
    public var number: Int
    /// par 값. 데이터 미보유 시 nil (일부 코스에서 par가 null로 기록됨).
    public var par: Int?
    /// tee 좌표. 데이터 미보유 시 nil.
    public var tee: Coordinate?
    /// green 좌표. 데이터 미보유 시 nil.
    public var green: Coordinate?

    // MARK: computed (호출자 호환)

    public var teeLat: Double { tee?.lat ?? 0.0 }
    public var teeLng: Double { tee?.lng ?? 0.0 }
    public var greenLat: Double { green?.lat ?? 0.0 }
    public var greenLng: Double { green?.lng ?? 0.0 }

    // MARK: Memberwise init

    public init(number: Int, par: Int? = nil,
                tee: Coordinate? = nil, green: Coordinate? = nil) {
        self.number = number
        self.par = par
        self.tee = tee
        self.green = green
    }

    /// 기존 flat 시그니처 호환 init (테스트/미리보기에서 직접 좌표 지정 시 사용).
    public init(number: Int, par: Int,
                teeLat: Double, teeLng: Double,
                greenLat: Double, greenLng: Double) {
        self.number = number
        self.par = par
        self.tee = Coordinate(lat: teeLat, lng: teeLng)
        self.green = Coordinate(lat: greenLat, lng: greenLng)
    }
}

// MARK: - Coordinate

/// 위경도 좌표 쌍.
public struct Coordinate: Codable, Sendable, Hashable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}
