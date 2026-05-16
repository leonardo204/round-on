import Foundation
import Shared

// MARK: - WCRoundBridge (iOS)
// SyncCoordinator delegate 구현 + RoundViewModel 연결 (B — 양방향 WC sync)
// - iOS RoundViewModel에 broadcast hooks 설정 (deviceId="iPhone")
// - SyncCoordinator 수신 이벤트를 RoundViewModel.applyRemote* 으로 라우팅
//
// 사용: RoundViewModel 생성 직후 WCRoundBridge.shared.attach(to: vm)

public final class WCRoundBridge: NSObject, SyncCoordinatorDelegate, @unchecked Sendable {

    public static let shared = WCRoundBridge()

    /// 현재 attach된 RoundViewModel — weak으로 보유하여 라이프사이클 leak 방지
    private weak var roundVM: RoundViewModel?

    private static let myDeviceId = "iPhone"

    private override init() {
        super.init()
        Task { await SyncCoordinator.shared.setDelegate(self) }
    }

    /// RoundViewModel에 양방향 sync hook 설치
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
        vm.onBroadcastSnapshot = { snapshot in
            Task { @MainActor in WCBroker.shared.send(roundSnapshot: snapshot) }
        }
        vm.onBroadcastRoundEnd = { end in
            Task { @MainActor in WCBroker.shared.send(roundEnd: end) }
        }
        AppLogger.round.info("WCRoundBridge attached (iPhone)")
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

    public func didReceiveRoundSnapshot(_ snapshot: RoundSnapshot) async {
        // iPhone은 라운드 source-of-truth — Watch가 보낸 snapshot은 무시 (iPhone에서 직접 startRound로 시작)
        AppLogger.round.debug("iPhone: 수신 RoundSnapshot 무시 (source-of-truth)")
    }

    public func didReceiveRoundEnd(_ end: RoundEnd) async {
        await MainActor.run { [weak self] in
            self?.roundVM?.applyRemoteRoundEnd(end)
        }
    }
}
