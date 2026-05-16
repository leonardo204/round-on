import Foundation
import SwiftData

@Model
public final class Round {
    // MARK: - CloudKit 호환 속성 (모두 default 값 제공)
    public var id: UUID = UUID()
    public var date: Date = Date.now
    public var courseId: String = ""
    public var courseName: String = ""

    /// Deprecated: frontCourseName / backCourseName을 사용하세요.
    /// 기존 데이터 마이그레이션을 위해 Optional로 유지합니다.
    @available(*, deprecated, message: "Use frontCourseName/backCourseName")
    public var courseSubName: String?

    /// 전반 9홀 코스 라벨 (예: "동코스"). 미설정 시 "전반" 폴백.
    /// SwiftData Optional 추가 — 라이트웨이트 마이그레이션 안전.
    public var frontCourseName: String?

    /// 후반 9홀 코스 라벨 (예: "남코스"). 9홀 라운드이거나 미선택 시 nil.
    /// SwiftData Optional 추가 — 라이트웨이트 마이그레이션 안전.
    public var backCourseName: String?

    // MARK: - CloudKit 호환 관계 (Optional + inverse)
    @Relationship(deleteRule: .cascade, inverse: \Player.round)
    public var players: [Player]? = []

    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    public var holes: [HoleScore]? = []

    @Relationship(deleteRule: .cascade, inverse: \RoundPhoto.round)
    public var photos: [RoundPhoto]? = []

    public var isFinished: Bool = false
    public var startedAt: Date = Date.now
    public var finishedAt: Date?
    public var sharedShortId: String?
    public var sharedURL: String?
    public var sharedExpiresAt: Date?

    /// Deprecated: editToken은 Keychain(KeychainStore)에 저장됩니다 (C2, 33-SECURITY §3.4).
    /// 기존 데이터 마이그레이션을 위해 Optional로 유지하며, 마이그레이션 완료 후 nil로 처리됩니다.
    /// 새 코드에서는 `KeychainStore.shared.editToken(for: sharedShortId)` 를 사용하세요.
    @available(*, deprecated, renamed: "KeychainStore.shared.editToken(for:)")
    public var sharedEditToken: String?

    public var sharedOptionsData: Data?  // ShareOptions을 Codable → Data로 저장

    // MARK: - Optional 관계 편의 접근자 (non-optional 호출자 편의)
    /// players Optional fallback — 코드 전반에서 `round.playerList` 사용
    public var playerList: [Player] { players ?? [] }
    /// holes Optional fallback
    public var holeList: [HoleScore] { holes ?? [] }
    /// photos Optional fallback
    public var photoList: [RoundPhoto] { photos ?? [] }

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        courseId: String = "",
        courseName: String = "",
        courseSubName: String? = nil,
        frontCourseName: String? = nil,
        backCourseName: String? = nil,
        players: [Player] = [],
        holes: [HoleScore] = [],
        photos: [RoundPhoto] = [],
        isFinished: Bool = false,
        startedAt: Date = .now,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.courseId = courseId
        self.courseName = courseName
        self.courseSubName = courseSubName
        self.frontCourseName = frontCourseName
        self.backCourseName = backCourseName
        self.players = players
        self.holes = holes
        self.photos = photos
        self.isFinished = isFinished
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var sharedOptions: ShareOptions? {
        get {
            guard let data = sharedOptionsData else { return nil }
            return try? JSONDecoder().decode(ShareOptions.self, from: data)
        }
        set {
            sharedOptionsData = try? JSONEncoder().encode(newValue)
        }
    }
}
