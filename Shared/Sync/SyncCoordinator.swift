import Foundation

// MARK: - SyncCoordinator actor
// WatchConnectivity 이벤트 직렬화 + dedupe + delta-merge (22-STATE §6)
// 20-ARCHITECTURE §9 — Shared 타깃 배치

// MARK: - SyncCoordinatorDelegate

/// 수신 이벤트를 ViewModel로 라우팅하기 위한 델리게이트
public protocol SyncCoordinatorDelegate: AnyObject, Sendable {
    func didReceiveShotEvent(_ event: ShotEvent) async
    func didReceiveHoleChange(_ change: HoleChange) async
    func didReceivePlayerSwitch(_ switch_: PlayerSwitch) async
    func didReceiveRoundSnapshot(_ snapshot: RoundSnapshot) async
}

// MARK: - SyncCoordinator

public actor SyncCoordinator {

    // MARK: Shared instance

    public static let shared = SyncCoordinator()

    private init() {}

    // MARK: State

    /// 적용된 ShotEvent eventId 집합 (dedupe)
    private var appliedEventIds: Set<UUID> = []

    /// 델리게이트 (weak-like — actor 격리 내 보유)
    private weak var delegate: (any SyncCoordinatorDelegate)?

    // MARK: Public API

    public func setDelegate(_ delegate: some SyncCoordinatorDelegate) {
        self.delegate = delegate
    }

    /// WCBroker에서 호출 — 수신 ShotEvent 처리
    public func receive(shotEvent event: ShotEvent) async {
        // dedupe: 이미 처리한 eventId 무시 (22-STATE §6.1)
        guard !appliedEventIds.contains(event.eventId) else { return }
        appliedEventIds.insert(event.eventId)

        await delegate?.didReceiveShotEvent(event)
    }

    /// WCBroker에서 호출 — 수신 HoleChange 처리
    public func receive(holeChange change: HoleChange) async {
        await delegate?.didReceiveHoleChange(change)
    }

    /// WCBroker에서 호출 — 수신 PlayerSwitch 처리
    public func receive(playerSwitch switch_: PlayerSwitch) async {
        await delegate?.didReceivePlayerSwitch(switch_)
    }

    /// WCBroker에서 호출 — 수신 RoundSnapshot 처리
    public func receive(roundSnapshot snapshot: RoundSnapshot) async {
        await delegate?.didReceiveRoundSnapshot(snapshot)
    }

    /// 브로드캐스트 — WCBroker로 ShotEvent 전송 요청
    /// WCBroker는 플랫폼별로 각각 구현 (App-iOS / App-Watch)
    public func broadcastShot(
        _ event: ShotEvent,
        via broadcast: @Sendable (ShotEvent) async -> Void
    ) async {
        await broadcast(event)
    }

    // MARK: Counter management

    /// 다음 perDeviceCounter 값 생성
    public func nextCounter() async -> UInt64 {
        await PerDeviceCounter.shared.next()
    }

    // MARK: Debug / Test helpers

    /// 테스트용 — appliedEventIds 초기화
    public func resetForTesting() {
        appliedEventIds.removeAll()
    }

    /// 테스트용 — 현재 적용된 eventId 수 확인
    public var appliedEventCount: Int {
        appliedEventIds.count
    }
}

// MARK: - ShotEvent delta 계산 헬퍼

public extension ShotEvent {
    /// 타수 변화량 (22-STATE §6 delta-merge)
    var countDelta: Int {
        switch type {
        case .increment: return 1
        case .decrement: return -1
        case .ob:        return 2   // 1벌타 + 1샷 재타
        case .hazard:    return 1
        case .ok:        return 1
        }
    }

    /// OB 카운터 변화량
    var obDelta: Int {
        type == .ob ? 1 : 0
    }

    /// 해저드 카운터 변화량
    var hazardDelta: Int {
        type == .hazard ? 1 : 0
    }
}
