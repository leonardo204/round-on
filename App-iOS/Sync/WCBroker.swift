import Foundation
import WatchConnectivity
import Shared

// MARK: - WCBroker (iOS)
// WCSessionDelegate 구현 + sendMessage/transferUserInfo 분기 (22-STATE §5)
// foreground: sendMessage, background: transferUserInfo

@MainActor
public final class WCBroker: NSObject {

    // MARK: Shared instance

    public static let shared = WCBroker()

    // MARK: Private state

    private var session: WCSession?

    // MARK: Init

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        self.session = s
    }

    // MARK: Public API — 송신

    /// ShotEvent 전송 (foreground: sendMessage, background: transferUserInfo)
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
    public func send(roundSnapshot snapshot: RoundSnapshot) {
        guard let session = session, session.isPaired else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }
        let dict: [String: Any] = [
            WCMessageKey.messageType: WCMessageKey.roundSnapshot,
            WCMessageKey.payload: data
        ]

        try? session.updateApplicationContext(dict)
    }

    // MARK: Private — 수신 처리

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

        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WCBroker: WCSessionDelegate {

    public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        // 활성화 완료 — 추가 처리 없음
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // 세션 재활성화 (iPhone 멀티 Watch 지원)
        session.activate()
    }

    // MARK: Foreground 수신

    public func session(_ session: WCSession,
                        didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    public func session(_ session: WCSession,
                        didReceiveMessage message: [String: Any],
                        replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler([:])
    }

    // MARK: Background 수신 (transferUserInfo)

    public func session(_ session: WCSession,
                        didReceiveUserInfo userInfo: [String: Any]) {
        handleMessage(userInfo)
    }

    // MARK: ApplicationContext (RoundSnapshot)

    public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String: Any]) {
        handleMessage(applicationContext)
    }
}
