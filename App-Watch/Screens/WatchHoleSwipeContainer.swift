import SwiftUI
import Shared

// MARK: - WatchHoleSwipeContainer
// watch-3.2~3.4: TabView .page 좌우 스와이프 (홀 이동)
// + .verticalPage 상하 스와이프 (플레이어 전환)
// 12-SCREENS watch-3.2~3.4

struct WatchHoleSwipeContainer: View {

    // MARK: Props

    @Bindable var roundVM: RoundViewModel
    @State private var showPenalty = false

    // MARK: Body

    var body: some View {
        guard let holeVM = roundVM.holeViewModel,
              let playerVM = roundVM.playerListViewModel else {
            return AnyView(Text("라운드 없음").foregroundStyle(.secondary))
        }

        return AnyView(
            TabView(selection: Binding(
                get: { holeVM.currentHoleIndex },
                set: { idx in
                    let prev = holeVM.currentHoleIndex
                    holeVM.goToHole(index: idx)
                    if idx != prev {
                        Task { await HapticEngine.shared.play(.holeManualChange) }
                    }
                }
            )) {
                // 각 홀별 페이지
                ForEach(0..<holeVM.totalHoles, id: \.self) { holeIdx in
                    holePageView(
                        holeNumber: holeIdx + 1,
                        holeVM: holeVM,
                        playerVM: playerVM
                    )
                    .tag(holeIdx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        )
    }

    // MARK: 홀 페이지 (상하 플레이어 스와이프 포함)

    private func holePageView(
        holeNumber: Int,
        holeVM: HoleViewModel,
        playerVM: PlayerListViewModel
    ) -> some View {
        // 플레이어별 상하 스와이프 (verticalPage)
        TabView(selection: Binding(
            get: { playerVM.activePlayerIndex },
            set: { idx in
                let prev = playerVM.activePlayerIndex
                playerVM.activate(player: playerVM.activePlayers[idx])
                if idx != prev {
                    Task { await HapticEngine.shared.play(.playerSwitch) }
                }
            }
        )) {
            ForEach(Array(playerVM.activePlayers.enumerated()), id: \.offset) { idx, player in
                playerHoleView(
                    player: player,
                    holeNumber: holeNumber,
                    holeVM: holeVM
                )
                .tag(idx)
            }
        }
        .tabViewStyle(.verticalPage(transitionStyle: .blur))
    }

    // MARK: 플레이어 × 홀 뷰

    private func playerHoleView(
        player: Player,
        holeNumber: Int,
        holeVM: HoleViewModel
    ) -> some View {
        VStack(spacing: 4) {
            // 홀 + 플레이어 헤더
            HStack {
                Text("\(holeNumber)H")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(player.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)

            // ShotButton
            if let scoreVM = roundVM.scoreCardViewModel {
                let count = scoreVM.count(holeNumber: holeNumber, playerId: player.id)
                let par = scoreVM.parByHole[holeNumber] ?? 4

                ShotButton(
                    count: count,
                    par: par,
                    onIncrement: {
                        roundVM.increment(holeNumber: holeNumber, playerId: player.id)
                        holeVM.goToHole(index: holeNumber - 1)
                        Task { await HapticEngine.shared.play(.shotIncrement) }
                    },
                    onDecrement: {
                        roundVM.decrement(holeNumber: holeNumber, playerId: player.id)
                        Task { await HapticEngine.shared.play(.shotDecrement) }
                    }
                )

                // 벌타 버튼 (하단 컴팩트)
                HStack(spacing: 4) {
                    WatchPenaltyButton(variant: .ob) {
                        roundVM.tapOB(holeNumber: holeNumber, playerId: player.id)
                        Task { await HapticEngine.shared.play(.penaltyOB) }
                    }
                    WatchPenaltyButton(variant: .hazard) {
                        roundVM.tapHazard(holeNumber: holeNumber, playerId: player.id)
                        Task { await HapticEngine.shared.play(.penaltyHazard) }
                    }
                    WatchPenaltyButton(variant: .ok) {
                        roundVM.tapOK(holeNumber: holeNumber, playerId: player.id)
                        Task { await HapticEngine.shared.play(.penaltyOK) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}
