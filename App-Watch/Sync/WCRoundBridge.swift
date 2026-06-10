import Foundation
import Shared

// MARK: - WCRoundBridge (watchOS)
// SyncCoordinator delegate 구현 + RoundViewModel 연결 (B — 양방향 WC sync)
// - Watch RoundViewModel에 broadcast hooks 설정 (deviceId="Watch")
// - iPhone에서 보낸 RoundSnapshot 수신 시 onSnapshotReceived 콜백
//   → WatchContentView가 in-memory Round 생성 + RoundViewModel 활성

public final class WCRoundBridge: NSObject, SyncCoordinatorDelegate, @unchecked Sendable {

    public static let shared = WCRoundBridge()

    private weak var roundVM: RoundViewModel?
    private static let myDeviceId = "Watch"

    /// 라운드 시작 콜백 — WatchContentView가 설정. Watch는 ModelContainer가 필요해서 View에서 처리.
    public var onSnapshotReceived: ((@Sendable (RoundSnapshot) -> Void))?

    private override init() {
        super.init()
        Task { await SyncCoordinator.shared.setDelegate(self) }
    }

    /// RoundViewModel attach (View가 vm 만든 후 호출)
    @MainActor
    public func attach(to vm: RoundViewModel) {
        self.roundVM = vm
        vm.deviceId = Self.myDeviceId
        vm.onBroadcastShot = { event in
            Task { @MainActor in WCBroker.shared.send(shotEvent: event) }
        }
        vm.onBroadcastHole = { change in
            Task { @MainActor in WCBroker.shared.send(holeChange: change) }
        }
        vm.onBroadcastPlayerSwitch = { switchEvent in
            Task { @MainActor in WCBroker.shared.send(playerSwitch: switchEvent) }
        }
        vm.onBroadcastRoundEnd = { end in
            Task { @MainActor in WCBroker.shared.send(roundEnd: end) }
        }
        // Watch에서 RoundSnapshot 송출은 사용 안 함 (iPhone이 source-of-truth)
        AppLogger.round.info("WCRoundBridge attached (Watch)")
    }

    // MARK: - SyncCoordinatorDelegate

    public func didReceiveShotEvent(_ event: ShotEvent) async {
        await MainActor.run { [weak self] in
            self?.roundVM?.applyRemoteShot(event)
        }
    }

    public func didReceiveHoleChange(_ change: HoleChange) async {
        await MainActor.run { [weak self] in
            self?.roundVM?.applyRemoteHoleChange(change)
        }
    }

    public func didReceivePlayerSwitch(_ switch_: PlayerSwitch) async {
        await MainActor.run { [weak self] in
            self?.roundVM?.applyRemotePlayerSwitch(switch_)
        }
    }

    public func didReceiveRoundEnd(_ end: RoundEnd) async {
        await MainActor.run { [weak self] in
            self?.roundVM?.applyRemoteRoundEnd(end)
        }
        // 좀비 즉시 종료 방어 4: iPhone 종료 신호 수신 시 onChange/foreground 복귀를
        // 기다리지 않고 always-on 운동 세션을 즉시 종료. WC 메시지는 백그라운드에서도
        // 수신되므로 Watch가 백그라운드여도 동작. endWorkout()의 isActive 가드가
        // 중복 호출을 no-op으로 흡수하므로 기존 방어 로직과 충돌 없이 안전.
        AppLogger.round.info("WCRoundBridge didReceiveRoundEnd — endWorkout 직접 호출 (즉시 종료)")
        await WatchWorkoutManager.shared.endWorkout()
    }

    public func didReceiveRoundSnapshot(_ snapshot: RoundSnapshot) async {
        // 이미 attach된 vm이 있으면 par/active만 동기화
        if let vm = await roundVM, await vm.isRoundActive {
            await MainActor.run { [weak self] in
                self?.roundVM?.applyRemoteSnapshot(snapshot)
            }
            return
        }
        // 신규 라운드 — View가 ModelContainer 통해 처리
        let cb = onSnapshotReceived
        await MainActor.run {
            cb?(snapshot)
        }
    }
}
