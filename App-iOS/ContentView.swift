import SwiftUI
import SwiftData
import CoreLocation
import UIKit
import Shared

// MARK: - ContentView
// 앱 루트 뷰. 라운드 활성 여부에 따라 HomeView ↔ ActiveRoundView ↔ RoundSummaryView 전환.
// F6: 앱 시작 시 진행 중 라운드 자동 복구 (RoundViewModel.resumeIfNeeded)
// F1: 앱 시작 시 위치 권한 요청 + 거부 상태면 설정 이동 안내 alert
// Splash: 앱 cold start + idle 30분 이상 background 후 재진입 시 1.5초 LaunchSplash 표시 → 홈

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var roundViewModel: RoundViewModel?
    @State private var finishedRound: Round?
    @State private var showLocationDeniedAlert: Bool = false
    @State private var showSplash: Bool = true
    @State private var lastBackgroundedAt: Date?
    @State private var resetToHomeNonce: Int = 0  // 모달 강제 dismiss 트리거

    /// idle 임계값 — 이 시간 이상 background에 있다가 돌아오면 splash + 홈 reset
    private let idleThreshold: TimeInterval = 30 * 60  // 30분

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()

            Group {
                if let roundVM = roundViewModel, roundVM.isRoundActive {
                    ActiveRoundView(roundVM: roundVM)
                        .transition(.opacity)
                } else if let finished = finishedRound {
                    RoundSummaryView(round: finished, onDismiss: {
                        finishedRound = nil
                        roundViewModel = nil
                    })
                    .transition(.opacity)
                } else {
                    HomeView(roundViewModel: $roundViewModel, onRoundFinished: { round in
                        finishedRound = round
                    })
                    .id(resetToHomeNonce)  // nonce 변경 시 HomeView 강제 재생성 → 모달도 dismiss
                    .transition(.opacity)
                }
            }

            // Splash overlay — 최상단
            if showSplash {
                splashOverlay
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roundViewModel?.isRoundActive)
        .animation(.easeInOut(duration: 0.2), value: finishedRound?.id)
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .onChange(of: roundViewModel?.isRoundActive) { _, isActive in
            if let round = roundViewModel?.currentRound, isActive == false {
                finishedRound = round
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .task {
            // B: WCSession 사전 활성화 (lazy init trigger)
            await MainActor.run {
                WCBroker.shared.warmUp()
            }
            _ = WCRoundBridge.shared

            // F6: 앱 시작 시 미완료 라운드 복구
            if roundViewModel == nil {
                let vm = RoundViewModel(modelContext: modelContext)
                vm.attachWorkoutCoordinator()
                WCRoundBridge.shared.attach(to: vm)
                vm.resumeIfNeeded()
                if vm.isRoundActive {
                    roundViewModel = vm
                    vm.broadcastCurrentSnapshot()
                }
            }

            // Splash 자동 dismiss (cold start 1.5초)
            await dismissSplashAfterDelay()

            // F1: 위치 권한 부트스트랩 (splash dismiss 이후에 alert 표시되도록)
            await bootstrapLocationPermission()
        }
        .alert("위치 권한이 필요해요", isPresented: $showLocationDeniedAlert) {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("나중에", role: .cancel) { }
        } message: {
            Text("가까운 골프장을 자동으로 찾으려면 위치 권한이 필요합니다.\n설정에서 ‘앱이 사용 중일 때 허용’으로 변경해 주세요.")
        }
    }

    // MARK: - Splash overlay

    private var splashOverlay: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
            Image("LaunchSplash")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }

    private func dismissSplashAfterDelay() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await MainActor.run {
            showSplash = false
        }
    }

    // MARK: - Scene phase 핸들러

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lastBackgroundedAt = .now
            AppLogger.app.debug("Scene background — \(lastBackgroundedAt!)")

        case .active:
            // background 들렀다 돌아온 경우만 처리 (cold start는 .task 흐름 사용)
            guard let backgroundedAt = lastBackgroundedAt else { return }
            let elapsed = Date().timeIntervalSince(backgroundedAt)
            lastBackgroundedAt = nil
            AppLogger.app.info("Scene active 복귀 — background \(Int(elapsed))s")
            if elapsed >= idleThreshold {
                // idle threshold 초과 — splash + 홈 reset
                resetToHomeIfIdle()
            }

        default:
            break
        }
    }

    private func resetToHomeIfIdle() {
        // 진행 중 라운드는 유지 (resumeIfNeeded로 다시 활성). 모달만 dismiss + splash 잠시.
        AppLogger.app.info("Idle threshold 초과 — splash + 홈 reset")
        showSplash = true
        resetToHomeNonce &+= 1  // HomeView 강제 재생성 → 안에 떠 있던 NewRoundView/Settings 등 모달 dismiss
        Task {
            await dismissSplashAfterDelay()
        }
    }

    /// 앱 첫 진입 시 위치 권한 부트스트랩.
    /// - .notDetermined → 시스템 다이얼로그 표시
    /// - .denied/.restricted → 설정 이동 안내 alert
    private func bootstrapLocationPermission() async {
        let status = LocationService.shared.authorizationStatus
        switch status {
        case .notDetermined:
            _ = await LocationService.shared.requestAuthorization()
        case .denied, .restricted:
            showLocationDeniedAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Round.self, Player.self, HoleScore.self, RoundPhoto.self], inMemory: true)
}
