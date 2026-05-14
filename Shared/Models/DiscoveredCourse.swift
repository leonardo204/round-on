import Foundation

// MARK: - DiscoveredCourse

/// 카카오 로컬 API에서 발견된 골프장 (DB 미등록 임시 표현).
/// 검색 결과 및 자동 매칭 fallback에 사용되며, 라운드 시작 시
/// PersistedDiscoveredCourse로 영구 캐싱된다.
public struct DiscoveredCourse: Codable, Sendable, Identifiable, Hashable {
    /// 카카오 Place ID (카카오 로컬 API 반환값)
    public let kakaoPlaceId: String
    /// 골프장 이름
    public let name: String
    /// 도로명/지번 주소
    public let address: String?
    /// 전화번호
    public let phone: String?
    /// 클럽하우스 위도
    public let lat: Double
    /// 클럽하우스 경도
    public let lng: Double
    /// 카카오 장소 URL (선택)
    public let placeUrl: String?
    /// 사용자 위치로부터의 거리 (km). 검색 시 계산되어 채워짐. 정렬용.
    public var distanceKm: Double?

    public var id: String { kakaoPlaceId }

    /// `Round.courseId`에 저장할 안정 ID.
    /// "kakao:{id}" 형식으로 로컬 GolfCourse ID와 구분된다.
    public var roundCourseId: String { "kakao:\(kakaoPlaceId)" }

    public init(
        kakaoPlaceId: String,
        name: String,
        address: String? = nil,
        phone: String? = nil,
        lat: Double,
        lng: Double,
        placeUrl: String? = nil,
        distanceKm: Double? = nil
    ) {
        self.kakaoPlaceId = kakaoPlaceId
        self.name = name
        self.address = address
        self.phone = phone
        self.lat = lat
        self.lng = lng
        self.placeUrl = placeUrl
        self.distanceKm = distanceKm
    }

    /// 임시 GolfCourse로 변환 (영구 저장 전 라운드 진행용).
    /// dataQuality는 .unknown — 홀 정보 없음.
    public func asGolfCourse() -> GolfCourse {
        GolfCourse(
            id: roundCourseId,
            name: name,
            region: "",
            address: address,
            phone: phone,
            clubhouse: Clubhouse(lat: lat, lng: lng),
            holesCount: nil,
            courseType: nil,
            kakaoPlaceUrl: placeUrl,
            subCourses: nil,
            holes: [],
            dataQuality: .unknown,
            sources: ["kakao_discovery"]
        )
    }
}
