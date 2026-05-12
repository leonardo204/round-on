import SwiftUI
import SwiftData
import Shared

// MARK: - ContentView
// 앱 루트 뷰. 라운드 활성 여부에 따라 HomeView ↔ ActiveRoundView 전환.
// F6: 앱 시작 시 진행 중 라운드 자동 복구 (RoundViewModel.resumeIfNeeded)

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var roundViewModel: RoundViewModel?

    var body: some View {
        Group {
            if let roundVM = roundViewModel, roundVM.isRoundActive {
                // 라운드 진행 중
                ActiveRoundView(roundVM: roundVM)
                    .transition(.opacity)
            } else {
                // 홈 화면
                HomeView(roundViewModel: $roundViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roundViewModel?.isRoundActive)
        .task {
            // F6: 앱 시작 시 미완료 라운드 복구
            if roundViewModel == nil {
                let vm = RoundViewModel(modelContext: modelContext)
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
