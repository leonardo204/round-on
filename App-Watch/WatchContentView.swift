import SwiftUI
import SwiftData
import Shared

// MARK: - WatchContentView
// Watch 루트 뷰. 라운드 활성 여부 → WatchScoreInputView ↔ WatchHoleSwipeContainer 진입

struct WatchContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var roundVM: RoundViewModel?
    @State private var showEndMenu = false

    /// 라운드 활성 여부 파생값 — always-on 운동 세션 start/end 훅의 단일 트리거
    private var isRoundActive: Bool {
        roundVM?.isRoundActive ?? false
    }

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

            // 앱 시작 시 이미 라운드가 복원/활성 상태면(onChange 미발화 케이스)
            // always-on 세션을 명시적으로 시작 — 매니저 isActive 가드로 중복 방지
            if isRoundActive {
                await WatchWorkoutManager.shared.startWorkout()
            }
        }
        // 라운드 활성↔비활성 전이에 1:1로 always-on 운동 세션 start/end.
        // 매니저 내부 isActive 가드가 중복 start/누락 방지를 보장한다.
        .onChange(of: isRoundActive) { _, active in
            Task { @MainActor in
                if active {
                    await WatchWorkoutManager.shared.startWorkout()
                } else {
                    await WatchWorkoutManager.shared.endWorkout()
                }
            }
        }
        // standby/잠금 복귀 시 scenePhase .active → resumeIfNeeded (idempotent)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { @MainActor in
                if let vm = roundVM {
                    // 이미 vm 존재 → 동일 라운드면 무동작 (idempotent)
                    vm.resumeIfNeeded()
                    if vm.isRoundActive && roundVM == nil {
                        roundVM = vm
                    }
                } else {
                    // vm 없음 → 새로 생성 후 복원 시도
                    let vm = RoundViewModel(modelContext: modelContext)
                    WCRoundBridge.shared.attach(to: vm)
                    vm.resumeIfNeeded()
                    if vm.isRoundActive {
                        roundVM = vm
                    }
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
