import Foundation
import SwiftData

@Model
public final class Round {
    public var id: UUID
    public var date: Date
    public var courseId: String
    public var courseName: String
    public var courseSubName: String?
    @Relationship(deleteRule: .cascade) public var players: [Player]
    @Relationship(deleteRule: .cascade) public var holes: [HoleScore]
    @Relationship(deleteRule: .cascade) public var photos: [RoundPhoto]
    public var isFinished: Bool
    public var startedAt: Date
    public var finishedAt: Date?
    public var sharedShortId: String?
    public var sharedURL: String?
    public var sharedExpiresAt: Date?
    public var sharedEditToken: String?
    public var sharedOptionsData: Data?  // ShareOptions을 Codable → Data로 저장

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        courseId: String,
        courseName: String,
        courseSubName: String? = nil,
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
