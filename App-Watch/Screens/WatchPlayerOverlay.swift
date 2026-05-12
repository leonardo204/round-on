import SwiftUI
import Shared

// MARK: - WatchPlayerOverlay
// watch-3.5: 동반자 전환 오버레이 (12-SCREENS watch-3.5)
// 플레이어 목록 + 현재 활성 하이라이트

struct WatchPlayerOverlay: View {

    // MARK: Props

    @Bindable var roundVM: RoundViewModel
    let onDismiss: () -> Void

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if let playerVM = roundVM.playerListViewModel {
                    List(Array(playerVM.activePlayers.enumerated()), id: \.offset) { idx, player in
                        Button {
                            playerVM.activate(player: player)
                            Task { await HapticEngine.shared.play(.playerSwitch) }
                            onDismiss()
                        } label: {
                            HStack {
                                Text(player.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(idx == playerVM.activePlayerIndex ? Color.green : .primary)
                                Spacer()
                                if idx == playerVM.activePlayerIndex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }
                    }
                } else {
                    Text("플레이어 없음")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("플레이어 선택")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
