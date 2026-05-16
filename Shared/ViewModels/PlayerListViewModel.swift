import Foundation
import Observation

// MARK: - PlayerListViewModel
// 동반자 전환 상태 관리 (22-STATE_MANAGEMENT §3)
// F5: 상/하 스와이프로 본인 ↔ 동반자 전환

@Observable
@MainActor
public final class PlayerListViewModel {

    // MARK: State

    public private(set) var players: [Player]
    public var activePlayerIndex: Int = 0

    /// 활성 플레이어 변경 시 호출 — RoundViewModel이 WC sync 송출에 활용
    /// 인자: (새 activePlayerIndex)
    public var onActivePlayerChanged: ((Int) -> Void)?

    // MARK: Computed

    public var activePlayer: Player? {
        guard players.indices.contains(activePlayerIndex) else { return nil }
        return players[activePlayerIndex]
    }

    public var activePlayers: [Player] { players }

    // MARK: Init

    public init(players: [Player]) {
        self.players = players.sorted { $0.order < $1.order }
    }

    // MARK: Navigation

    /// 다음 플레이어로 전환 (순환)
    public func nextPlayer() {
        guard !players.isEmpty else { return }
        let before = activePlayerIndex
        activePlayerIndex = (activePlayerIndex + 1) % players.count
        if before != activePlayerIndex { onActivePlayerChanged?(activePlayerIndex) }
    }

    /// 이전 플레이어로 전환 (순환)
    public func previousPlayer() {
        guard !players.isEmpty else { return }
        let before = activePlayerIndex
        activePlayerIndex = (activePlayerIndex - 1 + players.count) % players.count
        if before != activePlayerIndex { onActivePlayerChanged?(activePlayerIndex) }
    }

    /// 특정 플레이어를 활성화. silent=true 시 callback 억제 (원격 수신 적용 시).
    public func activate(player: Player, silent: Bool = false) {
        if let idx = players.firstIndex(where: { $0.id == player.id }) {
            let before = activePlayerIndex
            activePlayerIndex = idx
            if before != idx && !silent {
                onActivePlayerChanged?(idx)
            }
        }
    }
}
