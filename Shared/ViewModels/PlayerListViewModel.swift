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
        activePlayerIndex = (activePlayerIndex + 1) % players.count
    }

    /// 이전 플레이어로 전환 (순환)
    public func previousPlayer() {
        guard !players.isEmpty else { return }
        activePlayerIndex = (activePlayerIndex - 1 + players.count) % players.count
    }

    /// 특정 플레이어를 활성화
    public func activate(player: Player) {
        if let idx = players.firstIndex(where: { $0.id == player.id }) {
            activePlayerIndex = idx
        }
    }
}
