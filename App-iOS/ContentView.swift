import SwiftUI
import SwiftData
import CoreLocation
import UIKit
import Shared

// MARK: - ContentView
// 앱 루트 뷰. 라운드 활성 여부에 따라 HomeView ↔ ActiveRoundView ↔ RoundSummaryView 전환.
// F6: 앱 시작 시 진행 중 라운드 자동 복구 (RoundViewModel.resumeIfNeeded)
// F1: 앱 시작 시 위치 권한 요청 + 거부 상태면 설정 이동 안내 alert

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var roundViewModel: RoundViewModel?
    @State private var finishedRound: Round?   // Summary 표시용
    @State private var showLocationDeniedAlert: Bool = false

    var body: some View {
        ZStack {
            // 시스템 적응형 배경 (라이트/다크 자동). statusbar/home indicator 영역까지 통일.
            Color(.systemGroupedBackground).ignoresSafeArea()

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
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roundViewModel?.isRoundActive)
        .animation(.easeInOut(duration: 0.2), value: finishedRound?.id)
        .onChange(of: roundViewModel?.isRoundActive) { _, isActive in
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
            // F1: 앱 시작 시 위치 권한 부트스트랩
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
