import SwiftUI
import CoreLocation
import UIKit
import SwiftData
import Shared
import PhotosUI

// MARK: - SettingsView
// 설정 화면: 위치 권한 상태 + 앱 버전 정보 (확장 예정)

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var iCloudLoggedIn: Bool = false

    // 가져오기 진입
    @State private var showImportLanding = false

    // DB 업데이트 상태
    @State private var dbUpdateState: DBUpdateState = .idle
    private enum DBUpdateState: Equatable {
        case idle
        case loading
        case success(String)
        case failure
    }

    // 개인정보 및 데이터 전송 섹션
    private let privacyURLString = "https://golf.zerolive.co.kr/privacy"
    @State private var showPrivacySafari = false
    @State private var showRevokeAlert = false
    @State private var consentRefreshTick = false  // 동의 철회 후 UI 갱신 트리거

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
                iCloudRow
            } header: {
                Text("iCloud 동기화")
            } footer: {
                Text("iPhone 「설정 → 사용자 이름(맨 위)」에 Apple 계정으로 로그인되어 있어야 동기화됩니다. 로그인되면 라운드 기록이 같은 Apple 계정의 다른 iPhone/iPad에도 자동 동기화됩니다.\n\nCloudKit private DB 사용 — 개인 데이터는 본인의 iCloud 안에만 저장되며 외부로 전송되지 않습니다.")
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

            Section {
                dbUpdateRow
            } header: {
                Text("골프장 데이터")
            } footer: {
                Text("앱 실행 시 자동으로 최신 골프장 정보를 확인합니다. 수동으로 즉시 갱신하려면 버튼을 탭하세요.")
            }

            // ★ 가져오기 섹션
            Section {
                importRow
            } header: {
                Text("가져오기")
            } footer: {
                Text("사진 보관함의 스코어카드를 인식해 라운드로 저장합니다. 원본 이미지는 저장되지 않습니다.")
            }

            // ★ 개인정보 및 데이터 전송 섹션
            Section {
                // 1. 동의 상태 행
                privacyInfoRow(
                    title: "동의 상태",
                    detail: consentStatusText
                )

                // 2. 전송 데이터 행
                privacyInfoRow(
                    title: "전송 데이터",
                    detail: "스코어카드 사진(분석 시), 촬영일"
                )

                // 3. 수신자 행
                privacyInfoRow(
                    title: "수신자",
                    detail: "Google LLC (Gemini API)"
                )

                // 4. 목적 행
                privacyInfoRow(
                    title: "목적",
                    detail: "스코어카드 자동 인식 · 분석 후 별도 저장 안 함"
                )

                // 5. 동의 시점 안내 행
                privacyInfoRow(
                    title: "동의 시점",
                    detail: "스코어카드 최초 분석 시 명시 동의, 동의 전에는 전송하지 않음"
                )

                // 6. 개인정보 처리방침 보기
                Button {
                    showPrivacySafari = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 15))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        Text("개인정보 처리방침 보기")
                            .font(.body)
                            .foregroundStyle(.tint)
                        Spacer()
                        Image(systemName: "safari")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 4)
                }

                // 7. 동의 철회 버튼 (동의 상태일 때만 노출)
                if ConsentManager.shared.isAccepted || consentRefreshTick {
                    if ConsentManager.shared.isAccepted {
                        Button(role: .destructive) {
                            showRevokeAlert = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.raised")
                                    .font(.system(size: 15))
                                    .frame(width: 24)
                                Text("데이터 전송 동의 철회")
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("개인정보 및 데이터 전송")
            } footer: {
                Text("Gemini AI를 이용한 스코어카드 분석 기능에만 적용됩니다. 동의 철회 시 이후 사진은 기기 내 인식으로만 처리됩니다.")
            }

            Section("정보") {
                LabeledContent("앱 버전", value: appVersionText)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showImportLanding) {
            ImportLandingView()
        }
        .sheet(isPresented: $showPrivacySafari) {
            if let url = URL(string: privacyURLString) {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .alert("동의를 철회하시겠습니까?", isPresented: $showRevokeAlert) {
            Button("철회", role: .destructive) {
                ConsentManager.shared.revoke()
                consentRefreshTick.toggle()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("철회하면 이후 사진 전송이 중단되고 기기 내 인식으로 처리됩니다.")
        }
        .task {
            refreshLocationStatus()
            refreshICloudStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshLocationStatus()
                refreshICloudStatus()
            }
        }
    }

    // MARK: - iCloud row

    private var iCloudRow: some View {
        HStack(spacing: 12) {
            Image(systemName: iCloudLoggedIn ? "icloud.fill" : "icloud.slash")
                .font(.system(size: 17))
                .foregroundStyle(iCloudLoggedIn ? Color.accentGreen : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud")
                    .font(.body)
                Text(iCloudStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !iCloudLoggedIn {
                Button("설정 열기") {
                    // iOS 시스템 설정 앱 루트로 이동 → 사용자가 맨 위 "Apple 계정에 로그인" 탭
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentGreen)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("iCloud 동기화 \(iCloudStatusText)")
    }

    private var iCloudStatusText: String {
        #if targetEnvironment(simulator)
        return "시뮬레이터 — 동기화 비활성"
        #else
        return iCloudLoggedIn
            ? "Apple 계정 로그인됨 — 라운드 자동 동기화"
            : "Apple 계정 로그인 안 됨 — iPhone 설정에서 로그인 필요"
        #endif
    }

    private func refreshICloudStatus() {
        // FileManager.default.ubiquityIdentityToken은 iCloud 계정 로그인 여부의 가장 간단한 지표
        // iCloud Drive 활성화 여부까지 정확히 알려면 CloudKit accountStatus 사용
        iCloudLoggedIn = (FileManager.default.ubiquityIdentityToken != nil)
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

    // MARK: - Import row

    private var importRow: some View {
        Button {
            showImportLanding = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 17))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("스코어보드 가져오기")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("사진의 스코어카드를 라운드로 변환")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - DB update row

    private var dbUpdateRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 17))
                .foregroundStyle(dbUpdateIconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("골프장 DB 업데이트")
                    .font(.body)
                Text(dbUpdateSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if dbUpdateState == .loading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("지금 갱신") {
                    triggerDBUpdate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentGreen)
            }
        }
        .padding(.vertical, 4)
    }

    private var dbUpdateIconColor: Color {
        switch dbUpdateState {
        case .idle: return .secondary
        case .loading: return .accentGreen
        case .success: return .accentGreen
        case .failure: return .red
        }
    }

    private var dbUpdateSubtitle: String {
        switch dbUpdateState {
        case .idle: return "최근 갱신 일시 확인 불가"
        case .loading: return "서버에서 확인 중..."
        case .success(let msg): return msg
        case .failure: return "업데이트 실패 — 잠시 후 다시 시도해 주세요"
        }
    }

    private func triggerDBUpdate() {
        guard dbUpdateState != .loading else { return }
        dbUpdateState = .loading
        Task {
            let (coursesUpdated, _) = await CourseRepository.shared.fetchRemoteForce(context: modelContext)
            if coursesUpdated {
                dbUpdateState = .success("업데이트 완료")
            } else {
                dbUpdateState = .success("최신 데이터입니다")
            }
            // 3초 후 idle 복귀
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dbUpdateState = .idle
        }
    }

    // MARK: - Privacy section helpers

    private var consentStatusText: String {
        _ = consentRefreshTick  // 트리거 의존
        if ConsentManager.shared.isAccepted {
            if let date = ConsentManager.shared.acceptedDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy.MM.dd"
                return "동의함 ✓ (\(formatter.string(from: date)))"
            }
            return "동의함 ✓"
        }
        return "미동의"
    }

    @ViewBuilder
    private func privacyInfoRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
