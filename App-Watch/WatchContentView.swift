import SwiftUI
import SwiftData
import Shared

// MARK: - WatchContentView
// Watch 루트 뷰. 라운드 활성 여부 → WatchScoreInputView ↔ WatchHoleSwipeContainer 진입

struct WatchContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var roundVM: RoundViewModel?
    @State private var showEndMenu = false

    var body: some View {
        Group {
            if let roundVM = roundVM, roundVM.isRoundActive {
                // 라운드 진행 중: 홀 스와이프 컨테이너 + 우하단 종료 버튼만
                // (Watch는 '나' 전용 입력 — 플레이어 전환 버튼 제거)
                ZStack(alignment: .bottomTrailing) {
                    WatchHoleSwipeContainer(roundVM: roundVM)

                    Button {
                        showEndMenu = true
                    } label: {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                    .frame(width: 28, height: 28)
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .padding(.bottom, 2)
                    .accessibilityLabel("라운드 종료 메뉴")
                }
                .sheet(isPresented: $showEndMenu) {
                    WatchRoundEndMenu(roundVM: roundVM)
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
            // B: WCSession 사전 활성화 (lazy init trigger)
            WCBroker.shared.warmUp()
            _ = WCRoundBridge.shared  // SyncCoordinator delegate 등록

            // RoundSnapshot 수신 콜백 등록
            WCRoundBridge.shared.onSnapshotReceived = { snapshot in
                Task { @MainActor in
                    activateFromRemote(snapshot: snapshot)
                }
            }

            if roundVM == nil {
                let vm = RoundViewModel(modelContext: modelContext)
                WCRoundBridge.shared.attach(to: vm)
                vm.resumeIfNeeded()
                if vm.isRoundActive {
                    roundVM = vm
                }
            }
        }
    }

    /// 원격(iPhone) RoundSnapshot 수신 시 호출 — Watch in-memory에 Round 활성
    @MainActor
    private func activateFromRemote(snapshot: RoundSnapshot) {
        let vm = roundVM ?? RoundViewModel(modelContext: modelContext)
        WCRoundBridge.shared.attach(to: vm)
        vm.applyRemoteSnapshot(snapshot)
        roundVM = vm
    }
}
