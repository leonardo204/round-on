import Foundation

// MARK: - GolfCourse

/// 골프장 정보. 20-ARCHITECTURE §6 옵션 A 결정에 따라 SwiftData @Model 아닌 Codable struct.
/// 번들 JSON에서 인메모리 로드. v3 스키마 기준 (2026-05-12).
public struct GolfCourse: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// 역사적 호환용. v3 JSON에는 없으나 Optional이므로 nil 디코드 허용.
    public let subName: String?
    public let region: String
    public let address: String?
    public let phone: String?
    /// v3 JSON의 `clubhouse: { lat, lng }` 중첩 객체에 매핑.
    public let clubhouse: Clubhouse?
    /// 36/27/18/9 중 하나. nil이면 라운드 생성 시 사용자 입력 프롬프트.
    public let holesCount: Int?
    /// "회원제"/"대중제"/"스크린" 등.
    public let courseType: String?
    public let kakaoPlaceUrl: String?
    /// 27/36홀 코스의 동/서/남/북 라벨 (현재 v3 JSON에서는 모두 빈 배열).
    public let subCourses: [SubCourse]?
    /// 상위 홀 목록 (subCourses 미분리 상태에서 사용).
    public let holes: [HoleInfo]
    /// dataQuality 기반 F3 GPS 자동 감지 분기 처리용. CLAUDE.md §PROJECT 참조.
    public let dataQuality: DataQuality
    /// 데이터 출처 추적 (예: ["mcst", "mois", "osm"]).
    public let sources: [String]?

    // MARK: computed (호출자 호환)

    /// `clubhouse.lat` 래퍼. 기존 호출자 코드 호환성 유지.
    public var clubhouseLat: Double { clubhouse?.lat ?? 0.0 }
    /// `clubhouse.lng` 래퍼. 기존 호출자 코드 호환성 유지.
    public var clubhouseLng: Double { clubhouse?.lng ?? 0.0 }

    // MARK: CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id, name, subName, region, address, phone
        case clubhouse
        case holesCount, courseType
        case kakaoPlaceUrl
        case subCourses               // v3 enrich_subcourses.py 산출 키와 동일
        case holes, dataQuality, sources
    }

    // MARK: Memberwise init (테스트 + 미리보기 전용)

    public init(
        id: String,
        name: String,
        subName: String? = nil,
        region: String,
        address: String? = nil,
        phone: String? = nil,
        clubhouse: Clubhouse? = nil,
        holesCount: Int? = nil,
        courseType: String? = nil,
        kakaoPlaceUrl: String? = nil,
        subCourses: [SubCourse]? = nil,
        holes: [HoleInfo] = [],
        dataQuality: DataQuality = .unknown,
        sources: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.subName = subName
        self.region = region
        self.address = address
        self.phone = phone
        self.clubhouse = clubhouse
        self.holesCount = holesCount
        self.courseType = courseType
        self.kakaoPlaceUrl = kakaoPlaceUrl
        self.subCourses = subCourses
        self.holes = holes
        self.dataQuality = dataQuality
        self.sources = sources
    }
}

// MARK: - Clubhouse

/// 클럽하우스 좌표. v3 JSON `clubhouse: { lat, lng }` 중첩 객체.
public struct Clubhouse: Codable, Sendable, Hashable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

// MARK: - SubCourse

/// 27/36홀 코스의 코스 구분 (동/서/남/북 등).
public struct SubCourse: Codable, Sendable, Identifiable {
    public let name: String          // "동코스", "서코스", "전반", "후반"
    /// 홀별 상세. 데이터 보강 전이면 nil 또는 빈 배열. JSON에 키가 없으면 nil로 디코드됨.
    public let holes: [HoleInfo]?

    public var id: String { name }

    public init(name: String, holes: [HoleInfo]? = nil) {
        self.name = name
        self.holes = holes
    }
}

// MARK: - DataQuality

/// 데이터 품질 등급. F3 GPS 자동 감지 활성 여부 결정에 사용.
/// - complete : 홀별 tee/green 좌표 완비 → GPS 자동 감지 가능
/// - partial  : 일부 홀 좌표 보유
/// - minimal  : 클럽하우스 + 일부 메타데이터
/// - low      : 클럽하우스 좌표만 (v3 전체의 약 98%)
/// - unknown  : 파싱 실패 fallback
public enum DataQuality: String, Codable, Sendable {
    case complete
    case partial
    case minimal
    case low
    case unknown

    // 알 수 없는 rawValue → .unknown으로 안전 fallback
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = DataQuality(rawValue: raw) ?? .unknown
    }
}
