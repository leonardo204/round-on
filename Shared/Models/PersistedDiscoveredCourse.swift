import Foundation
import SwiftData

// MARK: - PersistedDiscoveredCourse

/// 사용자가 라운드를 한 번 이상 진행한 카카오 발견 골프장의 영구 캐시.
/// 다음 자동 매칭/검색에서 로컬 GolfCourse처럼 활용됨.
///
/// SwiftData 신규 모델 — 기존 스키마에 추가만, 라이트웨이트 마이그레이션 안전.
@Model
public final class PersistedDiscoveredCourse {
    /// 카카오 Place ID
    /// CloudKit 미지원으로 @Attribute(.unique) 제거 — insert 전 중복 조회로 대체 (NewRoundView)
    public var kakaoPlaceId: String = ""
    /// 골프장 이름
    public var name: String = ""
    /// 도로명/지번 주소
    public var address: String?
    /// 전화번호
    public var phone: String?
    /// 클럽하우스 위도
    public var lat: Double = 0.0
    /// 클럽하우스 경도
    public var lng: Double = 0.0
    /// 카카오 장소 URL
    public var placeUrl: String?
    /// 최초 사용 일시 (첫 라운드 시작 시점)
    public var firstUsedAt: Date = Date.now

    public init(
        kakaoPlaceId: String,
        name: String,
        address: String? = nil,
        phone: String? = nil,
        lat: Double,
        lng: Double,
        placeUrl: String? = nil,
        firstUsedAt: Date = .now
    ) {
        self.kakaoPlaceId = kakaoPlaceId
        self.name = name
        self.address = address
        self.phone = phone
        self.lat = lat
        self.lng = lng
        self.placeUrl = placeUrl
        self.firstUsedAt = firstUsedAt
    }

    /// GolfCourse 값 타입으로 변환 (CourseRepository 병합 및 매칭용).
    public func toGolfCourse() -> GolfCourse {
        GolfCourse(
            id: "kakao:\(kakaoPlaceId)",
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
            sources: ["kakao_persisted"]
        )
    }

    /// DiscoveredCourse 값 타입으로 변환.
    public func toDiscoveredCourse() -> DiscoveredCourse {
        DiscoveredCourse(
            kakaoPlaceId: kakaoPlaceId,
            name: name,
            address: address,
            phone: phone,
            lat: lat,
            lng: lng,
            placeUrl: placeUrl
        )
    }
}
