import Foundation
import WatchConnectivity
import Shared

// MARK: - WCBroker (iOS)
// WCSessionDelegate 구현 + sendMessage/transferUserInfo 분기 (22-STATE §5)
// foreground: sendMessage, background: transferUserInfo
// Swift 6 strict concurrency: WCSessionDelegate 메서드를 nonisolated로 마킹 후
//   내부에서 Task { @MainActor in ... } 으로 메인 액터 디스패치

public final class WCBroker: NSObject {

    // MARK: Shared instance

    @MainActor public static let shared = WCBroker()

    // MARK: Private state (메인 액터에서만 접근)

    @MainActor private var session: WCSession?

    // MARK: Init

    @MainActor
    override private init() {
        super.init()
        guard WCSession.isSupported() else {
            AppLogger.round.error("WCSession not supported on this device")
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        self.session = s
        AppLogger.round.info("WCBroker(iPhone) init — WCSession activate 시작 (현재 state=\(s.activationState.rawValue))")
    }

    /// 명시적 warm-up — app 시작 시 호출하여 lazy init 트리거
    @MainActor
    public func warmUp() {
        // shared 접근만으로 init 발동
        _ = self
    }

    // MARK: Public API — 송신

    /// ShotEvent 전송 (foreground: sendMessage, background: transferUserInfo)
    @MainActor
    public func send(shotEvent event: ShotEvent) {
        guard let session = session, session.isPaired else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(event) else { return }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.shotEvent,
            WCMessageKey.payload: data
        ]

        if session.isReachable {
            // Foreground: 즉시 전송
            session.sendMessage(dict, replyHandler: nil, errorHandler: { [weak self] error in
                // sendMessage 실패 시 transferUserInfo fallback
                Task { @MainActor [weak self] in
                    self?.session?.transferUserInfo(dict)
                }
            })
        } else {
            // Background: FIFO 큐잉
            session.transferUserInfo(dict)
        }
    }

    /// HoleChange 전송
    @MainActor
    public func send(holeChange change: HoleChange) {
        guard let session = session, session.isPaired else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(change) else { return }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.holeChange,
            WCMessageKey.payload: data
        ]

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(dict)
        }
    }

    /// PlayerSwitch 전송
    @MainActor
    public func send(playerSwitch switch_: PlayerSwitch) {
        guard let session = session, session.isPaired else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(switch_) else { return }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.playerSwitch,
            WCMessageKey.payload: data
        ]

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(dict)
        }
    }

    /// RoundSnapshot 전송 (updateApplicationContext — 라운드 시작 시)
    @MainActor
    public func send(roundSnapshot snapshot: RoundSnapshot) {
        guard let session = session else {
            AppLogger.round.error("send(roundSnapshot): WCSession 없음")
            return
        }
        guard session.isPaired else {
            AppLogger.round.error("send(roundSnapshot): Watch 페어 안 됨 (isPaired=false). iPhone Watch 앱에서 페어 확인 필요")
            return
        }
        guard session.activationState == .activated else {
            AppLogger.round.warning("send(roundSnapshot): WCSession 미활성 (state=\(session.activationState.rawValue)) — 활성화 후 재전송 시도")
            // activate 완료 후 재전송 (delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.send(roundSnapshot: snapshot)
            }
            return
        }
        if !session.isWatchAppInstalled {
            AppLogger.round.warning("send(roundSnapshot): Watch app 미설치 — 그래도 send 시도")
        }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else {
            AppLogger.round.error("send(roundSnapshot): JSON encode 실패")
            return
        }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.roundSnapshot,
            WCMessageKey.payload: data
        ]

        do {
            try session.updateApplicationContext(dict)
            AppLogger.round.info("send(roundSnapshot) OK — roundId=\(snapshot.roundId), \(snapshot.players.count)명, hole=\(snapshot.activeHoleNumber), pars=\(snapshot.parArray.count)")
        } catch {
            AppLogger.round.error("send(roundSnapshot) 실패: \(error.localizedDescription)")
        }
    }

    /// RoundEnd 전송 (라운드 종료/폐기 통지)
    @MainActor
    public func send(roundEnd end: RoundEnd) {
        guard let session = session, session.isPaired else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(end) else { return }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.roundEnd,
            WCMessageKey.payload: data
        ]

        // sendMessage (foreground) — 실패 시 transferUserInfo fallback (background 보장 + 빈 applicationContext로 cleanup)
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.session?.transferUserInfo(dict)
                }
            })
        } else {
            session.transferUserInfo(dict)
        }
        AppLogger.round.info("send(roundEnd) — roundId=\(end.roundId), reason=\(end.reason.rawValue)")
    }

    // MARK: Private — 수신 처리

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        guard let typeStr = message[WCMessageKey.messageType] as? String,
              let payloadData = message[WCMessageKey.payload] as? Data else { return }

        let decoder = JSONDecoder()

        switch typeStr {
        case WCMessageKey.shotEvent:
            guard let event = try? decoder.decode(ShotEvent.self, from: payloadData) else { return }
            Task { await SyncCoordinator.shared.receive(shotEvent: event) }

        case WCMessageKey.holeChange:
            guard let change = try? decoder.decode(HoleChange.self, from: payloadData) else { return }
            Task { await SyncCoordinator.shared.receive(holeChange: change) }

        case WCMessageKey.playerSwitch:
            guard let switch_ = try? decoder.decode(PlayerSwitch.self, from: payloadData) else { return }
            Task { await SyncCoordinator.shared.receive(playerSwitch: switch_) }

        case WCMessageKey.roundSnapshot:
            guard let snapshot = try? decoder.decode(RoundSnapshot.self, from: payloadData) else { return }
            Task { await SyncCoordinator.shared.receive(roundSnapshot: snapshot) }

        case WCMessageKey.roundEnd:
            guard let end = try? decoder.decode(RoundEnd.self, from: payloadData) else { return }
            Task { await SyncCoordinator.shared.receive(roundEnd: end) }

        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WCBroker: WCSessionDelegate {

    // WCSessionDelegate 프로토콜은 nonisolated 요구사항이므로 모든 delegate 메서드를
    // nonisolated로 마킹하고 내부에서 Task { @MainActor in ... } 으로 디스패치한다.
    // Swift 6 strict concurrency 호환 (Task A — WCBroker actor isolation 경고 해소)

    nonisolated public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        // 활성화 완료 — 추가 처리 없음
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // 세션 재활성화 (iPhone 멀티 Watch 지원)
        session.activate()
    }

    // MARK: Foreground 수신

    nonisolated public func session(_ session: WCSession,
                        didReceiveMessage message: [String: Any]) {
        let captured = message
        Task { @MainActor [weak self] in
            self?.handleMessage(captured)
        }
    }

    nonisolated public func session(_ session: WCSession,
                        didReceiveMessage message: [String: Any],
                        replyHandler: @escaping ([String: Any]) -> Void) {
        let captured = message
        Task { @MainActor [weak self] in
            self?.handleMessage(captured)
        }
        replyHandler([:])
    }

    // MARK: Background 수신 (transferUserInfo)

    nonisolated public func session(_ session: WCSession,
                        didReceiveUserInfo userInfo: [String: Any]) {
        let captured = userInfo
        Task { @MainActor [weak self] in
            self?.handleMessage(captured)
        }
    }

    // MARK: ApplicationContext (RoundSnapshot)

    nonisolated public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String: Any]) {
        AppLogger.round.info("iPhone: didReceiveApplicationContext (Watch→iPhone)")
        let captured = applicationContext
        Task { @MainActor [weak self] in
            self?.handleMessage(captured)
        }
    }
}
