import Foundation

/// 골프장 정보. 20-ARCHITECTURE §6 옵션 A 결정에 따라 SwiftData @Model 아닌 Codable struct.
/// 번들 JSON에서 인메모리 로드.
public struct GolfCourse: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let subName: String?
    public let region: String
    public let clubhouseLat: Double
    public let clubhouseLng: Double
    public let holes: [HoleInfo]
    public let dataQuality: DataQuality  // CLAUDE.md §PROJECT 분기 처리용

    public init(id: String, name: String, subName: String? = nil, region: String,
                clubhouseLat: Double, clubhouseLng: Double,
                holes: [HoleInfo] = [], dataQuality: DataQuality = .unknown) {
        self.id = id
        self.name = name
        self.subName = subName
        self.region = region
        self.clubhouseLat = clubhouseLat
        self.clubhouseLng = clubhouseLng
        self.holes = holes
        self.dataQuality = dataQuality
    }
}

public enum DataQuality: String, Codable, Sendable {
    case low
    case medium
    case high
    case unknown
}
