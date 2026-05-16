import Foundation

// MARK: - WCMessages
// WatchConnectivity 메시지 페이로드 Codable 4종 (22-STATE §5)

// MARK: ShotType

public enum ShotType: String, Codable, Sendable {
    case increment   // +1
    case decrement   // -1
    case ob          // OB +2
    case hazard      // 해저드 +1
    case ok          // OK / 컨시드 +1
}

// MARK: ChangeTrigger

public enum ChangeTrigger: String, Codable, Sendable {
    case manualSwipe  // 수동 스와이프 (홀 단위 자동 감지 미제공 — F3는 골프장+서브코스 단위만)
}

// MARK: ShotEvent
// 카운터 변경 이벤트 (즉시 sendMessage + 백그라운드 transferUserInfo fallback)

public struct ShotEvent: Codable, Sendable {
    public let eventId: UUID            // dedupe 키
    public let type: ShotType
    public let playerId: UUID
    public let holeNumber: Int          // 1-18
    public let timestamp: Date          // 충돌 해결용
    public let deviceId: String         // "iPhone" / "Watch"
    public let perDeviceCounter: UInt64 // 디바이스별 단조 증가 카운터

    public init(
        eventId: UUID = UUID(),
        type: ShotType,
        playerId: UUID,
        holeNumber: Int,
        timestamp: Date = .now,
        deviceId: String,
        perDeviceCounter: UInt64
    ) {
        self.eventId = eventId
        self.type = type
        self.playerId = playerId
        self.holeNumber = holeNumber
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.perDeviceCounter = perDeviceCounter
    }
}

// MARK: HoleChange
// 홀 이동 이벤트

public struct HoleChange: Codable, Sendable {
    public let newHoleNumber: Int
    public let trigger: ChangeTrigger
    /// 진행 중인 홀의 서브코스 라벨.
    /// 발신 시 holeNumber 기반으로 front/back 분기:
    ///   let label = newHoleNumber <= 9 ? round.frontCourseName : round.backCourseName
    ///   subCourseName: label ?? round.displaySubLabel
    /// (현재 발신 코드가 stub 상태이므로, 실 구현 시 위 분기 적용 필요)
    public let subCourseName: String?
    public let timestamp: Date
    public let deviceId: String
    public let perDeviceCounter: UInt64

    public init(
        newHoleNumber: Int,
        trigger: ChangeTrigger = .manualSwipe,
        subCourseName: String? = nil,
        timestamp: Date = .now,
        deviceId: String,
        perDeviceCounter: UInt64
    ) {
        self.newHoleNumber = newHoleNumber
        self.trigger = trigger
        self.subCourseName = subCourseName
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.perDeviceCounter = perDeviceCounter
    }
}

// MARK: PlayerSwitch
// 동반자 전환 이벤트

public struct PlayerSwitch: Codable, Sendable {
    public let newPlayerIndex: Int
    public let timestamp: Date
    public let deviceId: String
    public let perDeviceCounter: UInt64

    public init(
        newPlayerIndex: Int,
        timestamp: Date = .now,
        deviceId: String,
        perDeviceCounter: UInt64
    ) {
        self.newPlayerIndex = newPlayerIndex
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.perDeviceCounter = perDeviceCounter
    }
}

// MARK: RoundSnapshot
// 라운드 시작 스냅샷 (updateApplicationContext)

public struct RoundSnapshot: Codable, Sendable {
    public let roundId: UUID
    public let courseId: String
    public let players: [PlayerSnapshot]
    public let activeHoleNumber: Int
    public let activePlayerIndex: Int
    public let parArray: [Int]          // 홀별 par 배열

    public init(
        roundId: UUID,
        courseId: String,
        players: [PlayerSnapshot],
        activeHoleNumber: Int,
        activePlayerIndex: Int,
        parArray: [Int]
    ) {
        self.roundId = roundId
        self.courseId = courseId
        self.players = players
        self.activeHoleNumber = activeHoleNumber
        self.activePlayerIndex = activePlayerIndex
        self.parArray = parArray
    }
}

// MARK: PlayerSnapshot
// WC 전송용 플레이어 경량 모델 (SwiftData @Model은 Codable 아님)

public struct PlayerSnapshot: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let isOwner: Bool
    public let order: Int

    public init(id: UUID, name: String, isOwner: Bool, order: Int) {
        self.id = id
        self.name = name
        self.isOwner = isOwner
        self.order = order
    }
}

// MARK: RoundEnd
// 라운드 종료(저장 또는 폐기) 통지 — 상대 디바이스가 deactivate되도록

public struct RoundEnd: Codable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case finished   // 저장하고 종료
        case discarded  // 폐기
    }

    public let roundId: UUID
    public let reason: Reason
    public let deviceId: String
    public let timestamp: Date

    public init(roundId: UUID, reason: Reason, deviceId: String, timestamp: Date = .now) {
        self.roundId = roundId
        self.reason = reason
        self.deviceId = deviceId
        self.timestamp = timestamp
    }
}

// MARK: WCMessageKey
// WC 딕셔너리 키 상수

public enum WCMessageKey {
    public static let messageType = "messageType"
    public static let payload = "payload"
    public static let shotEvent = "shotEvent"
    public static let holeChange = "holeChange"
    public static let playerSwitch = "playerSwitch"
    public static let roundSnapshot = "roundSnapshot"
    public static let roundEnd = "roundEnd"
}
