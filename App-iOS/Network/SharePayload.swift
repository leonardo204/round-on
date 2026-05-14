import Foundation
import Shared

// MARK: - SharePayload
// 30-API §9.3 와이어 직렬화 스키마
// SwiftData Round → JSON 직렬화 구조체 (Codable)
// 익명 모드 시 플레이어 이름 A/B/C/D 치환

// MARK: - 공유 요청 페이로드

public struct CreateShareRequest: Codable, Sendable {
    public let deviceToken: String
    public let round: RoundPayload
    public let options: ShareOptionsPayload

    public init(deviceToken: String, round: RoundPayload, options: ShareOptionsPayload) {
        self.deviceToken = deviceToken
        self.round = round
        self.options = options
    }
}

public struct UpdateShareRequest: Codable, Sendable {
    public let round: RoundPayload?
    public let options: ShareOptionsPayload?

    public init(round: RoundPayload? = nil, options: ShareOptionsPayload? = nil) {
        self.round = round
        self.options = options
    }
}

// MARK: - 공유 응답 페이로드

public struct CreateShareResponse: Codable, Sendable {
    public let shortId: String
    public let url: String
    public let editToken: String
    public let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case shortId, url, editToken, expiresAt
    }
}

public struct UpdateShareResponse: Codable, Sendable {
    public let shortId: String
    public let url: String
    public let expiresAt: Date
}

public struct UploadPhotoResponse: Codable, Sendable {
    public let photoId: String
    public let remoteURL: String
}

// MARK: - 라운드 페이로드

public struct RoundPayload: Codable, Sendable {
    public let id: String
    public let courseName: String
    public let courseSubName: String?
    public let date: Date
    public let finishedAt: Date?
    public let players: [PlayerPayload]
    public let holes: [HolePayload]

    public init(from round: Round, nameVisibility: NameVisibility) {
        self.id = round.id.uuidString
        self.courseName = round.courseName
        // 옵션 A: 클라이언트 합성 — Worker 코드 변경 없이 displaySubLabel 값으로 전송
        // displaySubLabel: "동코스 / 남코스" 또는 단일 코스명 또는 nil
        self.courseSubName = round.displaySubLabel
        self.date = round.date
        self.finishedAt = round.finishedAt

        // 익명 모드: A/B/C/D 치환 (spec_3.md:131)
        let sortedPlayers = round.players.sorted { $0.order < $1.order }
        let anonymousNames = ["A", "B", "C", "D"]
        self.players = sortedPlayers.enumerated().map { idx, player in
            let displayName = nameVisibility == .anonymous
                ? (idx < anonymousNames.count ? anonymousNames[idx] : "플레이어\(idx+1)")
                : player.name
            return PlayerPayload(id: player.id.uuidString, name: displayName, order: player.order)
        }

        self.holes = round.holes
            .sorted { $0.holeNumber < $1.holeNumber }
            .map { HolePayload(from: $0) }
    }
}

public struct PlayerPayload: Codable, Sendable {
    public let id: String
    public let name: String
    public let order: Int
}

public struct HolePayload: Codable, Sendable {
    public let holeNumber: Int
    public let par: Int
    public let scores: [ScoreEntryPayload]
    public let obCounts: [ScoreEntryPayload]
    public let hazardCounts: [ScoreEntryPayload]

    public init(from holeScore: HoleScore) {
        self.holeNumber = holeScore.holeNumber
        self.par = holeScore.par
        self.scores = holeScore.counts.map { ScoreEntryPayload(playerId: $0.playerId.uuidString, value: $0.value) }
        self.obCounts = holeScore.obCount.map { ScoreEntryPayload(playerId: $0.playerId.uuidString, value: $0.value) }
        self.hazardCounts = holeScore.hazardCount.map { ScoreEntryPayload(playerId: $0.playerId.uuidString, value: $0.value) }
    }
}

public struct ScoreEntryPayload: Codable, Sendable {
    public let playerId: String
    public let value: Int
}

// MARK: - 옵션 페이로드

public struct ShareOptionsPayload: Codable, Sendable {
    public let nameVisibility: String   // "real" | "anonymous"
    public let accessControl: String    // "public" | "pin"
    public let pin: String?             // accessControl == "pin" 일 때만

    public init(from options: ShareOptions) {
        self.nameVisibility = options.nameVisibility.rawValue
        switch options.accessControl {
        case .public:
            self.accessControl = "public"
            self.pin = nil
        case .pin(let pinValue):
            self.accessControl = "pin"
            self.pin = pinValue
        }
    }
}

// MARK: - API 에러 응답

public struct APIErrorResponse: Codable, Sendable {
    public let error: String
    public let code: String?
}
