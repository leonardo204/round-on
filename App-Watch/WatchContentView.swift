import SwiftUI
import SwiftData
import Shared

// MARK: - WatchContentView
// Watch 루트 뷰. 라운드 활성 여부 → WatchScoreInputView ↔ WatchHoleSwipeContainer 진입

struct WatchContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var roundVM: RoundViewModel?
    @State private var showEndMenu = false
    @State private var showPlayerOverlay = false

    var body: some View {
        Group {
            if let roundVM = roundVM, roundVM.isRoundActive {
                // 라운드 진행 중: 홀 스와이프 컨테이너
                ZStack(alignment: .bottom) {
                    WatchHoleSwipeContainer(roundVM: roundVM)

                    // 메뉴 버튼 (하단)
                    HStack(spacing: 8) {
                        // 플레이어 전환
                        Button {
                            showPlayerOverlay = true
                        } label: {
                            Image(systemName: "person.2")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.green)
                        }
                        .frame(width: 28, height: 28)
                        .buttonStyle(.plain)
                        .accessibilityLabel("플레이어 전환")

                        Spacer()

                        // 종료 메뉴
                        Button {
                            showEndMenu = true
                        } label: {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        .frame(width: 28, height: 28)
                        .buttonStyle(.plain)
                        .accessibilityLabel("라운드 종료 메뉴")
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)
                }
                .sheet(isPresented: $showEndMenu) {
                    WatchRoundEndMenu(roundVM: roundVM)
                }
                .sheet(isPresented: $showPlayerOverlay) {
                    WatchPlayerOverlay(roundVM: roundVM, onDismiss: {
                        showPlayerOverlay = false
                    })
                }
            } else {
                // 진행 중 라운드 없음
                VStack(spacing: 8) {
                    Image(systemName: "flag.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.green)
                    Text("라운드온")
                        .font(.system(size: 16, weight: .semibold))
                    Text("iPhone에서\n라운드를 시작하세요")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .task {
            if roundVM == nil {
                let vm = RoundViewModel(modelContext: modelContext)
                vm.resumeIfNeeded()
                if vm.isRoundActive {
                    roundVM = vm
                }
            }
        }
    }
}
