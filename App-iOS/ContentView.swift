import SwiftUI
import SwiftData
import Shared

// MARK: - ContentView
// 앱 루트 뷰. 라운드 활성 여부에 따라 HomeView ↔ ActiveRoundView ↔ RoundSummaryView 전환.
// F6: 앱 시작 시 진행 중 라운드 자동 복구 (RoundViewModel.resumeIfNeeded)
// 라우팅: Active 종료 → Summary → 뒤로 가면 Home

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var roundViewModel: RoundViewModel?
    @State private var finishedRound: Round?   // Summary 표시용

    var body: some View {
        Group {
            if let roundVM = roundViewModel, roundVM.isRoundActive {
                // 라운드 진행 중
                ActiveRoundView(roundVM: roundVM)
                    .transition(.opacity)
            } else if let finished = finishedRound {
                // 라운드 방금 완료 → Summary 표시
                RoundSummaryView(round: finished, onDismiss: {
                    finishedRound = nil
                    roundViewModel = nil
                })
                .transition(.opacity)
            } else {
                // 홈 화면
                HomeView(roundViewModel: $roundViewModel, onRoundFinished: { round in
                    finishedRound = round
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roundViewModel?.isRoundActive)
        .animation(.easeInOut(duration: 0.2), value: finishedRound?.id)
        .onChange(of: roundViewModel?.isRoundActive) { _, isActive in
            // 라운드 종료 감지 → Summary로 전환
            if let round = roundViewModel?.currentRound, isActive == false {
                finishedRound = round
            }
        }
        .task {
            // F6: 앱 시작 시 미완료 라운드 복구
            if roundViewModel == nil {
                let vm = RoundViewModel(modelContext: modelContext)
                vm.attachWorkoutCoordinator()
                vm.resumeIfNeeded()
                if vm.isRoundActive {
                    roundViewModel = vm
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Round.self, Player.self, HoleScore.self, RoundPhoto.self], inMemory: true)
}
