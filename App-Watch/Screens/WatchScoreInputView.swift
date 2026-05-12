import SwiftUI
import Shared

// MARK: - WatchScoreInputView
// watch-3.1 메인 타수 입력 화면 (12-SCREENS watch-3.1)
// ShotButton 중앙 + 홀 번호 상단 + 플레이어 이름 하단

struct WatchScoreInputView: View {

    // MARK: Props

    @Bindable var roundVM: RoundViewModel

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                // 상단: 홀 정보
                holeHeader

                Spacer()

                // 중앙: ShotButton (타수 입력 메인)
                if let holeVM = roundVM.holeViewModel,
                   let scoreVM = roundVM.scoreCardViewModel,
                   let playerVM = roundVM.playerListViewModel,
                   let activePlayer = playerVM.activePlayer {

                    let count = scoreVM.count(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                    let par = scoreVM.parByHole[holeVM.currentHoleNumber] ?? 4

                    ShotButton(
                        count: count,
                        par: par,
                        onIncrement: {
                            roundVM.increment(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                            Task { await HapticEngine.shared.play(.shotIncrement) }
                        },
                        onDecrement: {
                            roundVM.decrement(holeNumber: holeVM.currentHoleNumber, playerId: activePlayer.id)
                            Task { await HapticEngine.shared.play(.shotDecrement) }
                        }
                    )
                } else {
                    // 라운드 없음 fallback
                    Text("라운드 없음")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 하단: 활성 플레이어
                playerFooter
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: Sub Views

    private var holeHeader: some View {
        HStack {
            if let holeVM = roundVM.holeViewModel {
                Text("\(holeVM.currentHoleNumber)번 홀")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(holeVM.currentHoleNumber)/\(holeVM.totalHoles)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var playerFooter: some View {
        Group {
            if let playerVM = roundVM.playerListViewModel,
               let activePlayer = playerVM.activePlayer {
                Text(activePlayer.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }
        }
    }
}
