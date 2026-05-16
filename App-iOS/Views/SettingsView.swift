import SwiftUI
import CoreLocation
import UIKit
import Shared

// MARK: - SettingsView
// 설정 화면: 위치 권한 상태 + 앱 버전 정보 (확장 예정)

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined

    // 벌타 기본값 (PenaltySettings.Key와 일치)
    @AppStorage(PenaltySettings.Key.obDelta) private var obDelta: Int = PenaltySettings.Default.obDelta
    @AppStorage(PenaltySettings.Key.hazardDelta) private var hazardDelta: Int = PenaltySettings.Default.hazardDelta
    @AppStorage(PenaltySettings.Key.okDelta) private var okDelta: Int = PenaltySettings.Default.okDelta

    var body: some View {
        List {
            Section("권한") {
                locationRow
            }

            Section {
                penaltyStepperRow(label: "OB", icon: "flag", hint: "아웃 오브 바운즈 · 타수 자동 추가", value: $obDelta)
                penaltyStepperRow(label: "해저드", icon: "drop.fill", hint: "워터·벙커 등 · 타수 자동 추가", value: $hazardDelta)
                penaltyStepperRow(label: "컨시드 (OK)", icon: "checkmark.circle.fill", hint: "기브 · 마지막 한 타 인정", value: $okDelta)
            } header: {
                Text("벌타 기본값")
            } footer: {
                Text("홀 입력 모드의 OB / 해저드 / 컨시드 버튼이 추가하는 타수입니다.")
            }

            Section("정보") {
                LabeledContent("앱 버전", value: appVersionText)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refreshLocationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshLocationStatus()
            }
        }
    }

    // MARK: - Penalty stepper row

    private func penaltyStepperRow(label: String, icon: String, hint: String, value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body)
                Text(hint).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Text("+\(value.wrappedValue)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
                Stepper("", value: value, in: PenaltySettings.validRange)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(label) 기본 타수")
        .accessibilityValue("\(value.wrappedValue)타 추가")
    }

    // MARK: - Location row

    private var locationRow: some View {
        HStack(spacing: 12) {
            Image(systemName: locationIconName)
                .font(.system(size: 17))
                .foregroundStyle(locationIconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("위치")
                    .font(.body)
                Text(locationStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isLocationAuthorized {
                Button(locationActionLabel) {
                    handleLocationAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentGreen)
            }
        }
        .padding(.vertical, 4)
    }

    private var isLocationAuthorized: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    private var locationIconName: String {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "location.fill"
        case .denied, .restricted: return "location.slash"
        default: return "location"
        }
    }

    private var locationIconColor: Color {
        isLocationAuthorized ? .accentGreen : .secondary
    }

    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedAlways: return "항상 허용됨"
        case .authorizedWhenInUse: return "앱 사용 중 허용됨"
        case .denied: return "거부됨 — 설정에서 변경하세요"
        case .restricted: return "제한됨 — 시스템 제약"
        case .notDetermined: return "권한 요청 전"
        @unknown default: return "알 수 없음"
        }
    }

    private var locationActionLabel: String {
        locationStatus == .notDetermined ? "허용" : "설정 열기"
    }

    private func handleLocationAction() {
        switch locationStatus {
        case .notDetermined:
            Task {
                _ = await LocationService.shared.requestAuthorization()
                refreshLocationStatus()
            }
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private func refreshLocationStatus() {
        locationStatus = LocationService.shared.authorizationStatus
    }

    // MARK: - App version

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
