import SwiftUI
import Shared

// MARK: - WatchRoundEndMenu
// watch-3.6 → 3.7: 라운드 종료 확인 (12-SCREENS watch-3.6~3.7)

struct WatchRoundEndMenu: View {

    // MARK: Props

    @Bindable var roundVM: RoundViewModel
    @State private var showConfirm = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                // 종료 버튼
                Button {
                    showConfirm = true
                } label: {
                    Label("라운드 종료", systemImage: "flag.checkered")
                        .foregroundStyle(.red)
                }

                // 사용자 통제: always-on(화면 항상 켜짐)만 끄기 — 라운드는 유지.
                // 운동 세션이 살아있을 때만 노출 (배터리 절약 옵션).
                if WatchWorkoutManager.shared.isActive {
                    Section {
                        Button {
                            Task { await WatchWorkoutManager.shared.endWorkout() }
                        } label: {
                            Label("화면 항상 켜기 끄기", systemImage: "sun.max.slash")
                        }
                    } footer: {
                        Text("라운드는 계속됩니다. 배터리 절약을 위해 화면 항상 켜기만 끕니다.")
                            .font(.system(size: 11))
                    }
                }

                // 요약 정보
                if let scoreVM = roundVM.scoreCardViewModel,
                   let round = roundVM.currentRound {
                    Section("요약") {
                        HStack {
                            Text(round.courseName)
                                .font(.system(size: 13))
                            Spacer()
                        }
                        ForEach(scoreVM.players) { player in
                            let total = scoreVM.totalByPlayer[player.id] ?? 0
                            HStack {
                                Text(player.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Spacer()
                                Text(total > 0 ? "\(total)" : "-")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("메뉴")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("라운드를 종료할까요?", isPresented: $showConfirm) {
                Button("종료", role: .destructive) {
                    roundVM.finishRound()
                    // 방어 3: onChange(of: isRoundActive)에만 의존하지 않고
                    // 명시적으로 always-on 세션을 종료 (좀비 세션 방지).
                    // endWorkout의 isActive 가드가 중복 호출을 안전하게 흡수한다.
                    Task {
                        await WatchWorkoutManager.shared.endWorkout()
                        await HapticEngine.shared.play(.roundEnd)
                    }
                }
                Button("취소", role: .cancel) {}
            }
        }
    }
}
