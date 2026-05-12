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
                    Task { await HapticEngine.shared.play(.roundEnd) }
                }
                Button("취소", role: .cancel) {}
            }
        }
    }
}
