import SwiftUI
import CoreLocation
import UIKit
import SwiftData
import Shared
import PhotosUI
import CloudKit
import os.log

private let settingsLogger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "Settings")

// MARK: - SettingsView
// 설정 화면: 위치 권한 상태 + 앱 버전 정보 (확장 예정)

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var iCloudLoggedIn: Bool = false

    // 수동 iCloud 동기화
    @State private var iCloudAccountAvailable: Bool = false
    @State private var isSyncing: Bool = false
    @State private var syncResultMessage: String? = nil

    private let cloudContainerID = "iCloud.kr.zerolive.golf.roundon"

    // 가져오기 진입
    @State private var showImportLanding = false

    // DB 업데이트 상태
    @State private var dbUpdateState: DBUpdateState = .idle
    @State private var dbLastSuccessAt: Date? = nil
    private enum DBUpdateState: Equatable {
        case idle
        case loading
        case success(String)
        case failure
    }

    // AI 분석 팝업
    @State private var showAIAnalysis = false

    // 벌타 기본값 (PenaltySettings.Key와 일치)
    @AppStorage(PenaltySettings.Key.obDelta) private var obDelta: Int = PenaltySettings.Default.obDelta
    @AppStorage(PenaltySettings.Key.hazardDelta) private var hazardDelta: Int = PenaltySettings.Default.hazardDelta
    @AppStorage(PenaltySettings.Key.okDelta) private var okDelta: Int = PenaltySettings.Default.okDelta

    #if DEBUG
    @AppStorage("dev_season_override") private var devSeasonOverride: String = ""
    #endif

    var body: some View {
        List {
            Section("권한") {
                locationRow
            }

            Section {
                iCloudRow
                iCloudAccountStatusRow
                manualSyncRow
            } header: {
                Text("iCloud 동기화")
            } footer: {
                Text("라운드 기록은 iCloud로 자동 동기화됩니다. 즉시 반영이 필요할 때 「지금 동기화」를 사용하세요. (실제 반영은 네트워크·iCloud 상태에 따라 다를 수 있습니다.)\n\nCloudKit private DB 사용 — 개인 데이터는 본인의 iCloud 안에만 저장되며 외부로 전송되지 않습니다.")
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

            // ★ AI 분석 섹션 (할당량 + 개인정보 통합)
            Section {
                aiAnalysisRow
            } header: {
                Text("AI 사용 설정")
            } footer: {
                Text("스코어카드 자동 인식 무료 횟수 관리 및 개인정보 전송 동의 설정")
            }

            Section {
                LabeledContent("앱 버전", value: appVersionText)
                Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                    HStack {
                        Text("지도 데이터 출처")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.secondary)
                    }
                }
            } header: {
                Text("정보")
            } footer: {
                Text("© OpenStreetMap contributors, ODbL 1.0")
            }

            #if DEBUG
            Section {
                Picker("계절 테마 강제", selection: $devSeasonOverride) {
                    Text("자동 (현재 월)").tag("")
                    ForEach(SeasonTheme.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s.rawValue)
                    }
                }
            } header: {
                Text("DEVELOPER")
            } footer: {
                Text("개발 빌드 전용 — App Store 빌드에는 포함되지 않습니다.")
            }
            #endif
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showImportLanding) {
            ImportLandingView()
        }
        .sheet(isPresented: $showAIAnalysis) {
            AIAnalysisView()
        }
        .task {
            refreshLocationStatus()
            refreshICloudStatus()
            loadDBLastSuccessAt()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshLocationStatus()
                refreshICloudStatus()
                loadDBLastSuccessAt()
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
        Task {
            iCloudAccountAvailable = await checkAccountAvailable()
        }
    }

    // MARK: - iCloud 계정 상태 row

    private var iCloudAccountStatusRow: some View {
        LabeledContent("계정 상태") {
            Text(iCloudAccountAvailable ? "연결됨" : "연결 안 됨 / 로그인 필요")
                .foregroundStyle(iCloudAccountAvailable ? Color.accentGreen : Color.secondary)
        }
    }

    // MARK: - 수동 동기화 row

    private var manualSyncRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.icloud")
                .font(.system(size: 17))
                .foregroundStyle(isSyncing ? Color.accentGreen : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("지금 동기화")
                    .font(.body)
                if let msg = syncResultMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isSyncing {
                    Text("동기화 중...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("로컬 변경을 iCloud로 즉시 푸시 요청합니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("동기화") {
                    Task { await triggerManualSync() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentGreen)
            }
        }
        .padding(.vertical, 4)
        .disabled(isSyncing)
    }

    /// CloudKit 계정 상태가 .available 인지 async 확인.
    private func checkAccountAvailable() async -> Bool {
        let container = CKContainer(identifier: cloudContainerID)
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            settingsLogger.warning("[Settings] accountStatus 조회 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 「지금 동기화」 탭 핸들러.
    /// 1) iCloud 계정 상태 확인 → 미로그인이면 안내 후 종료
    /// 2) modelContext.save() 강제 호출 → CloudKit 푸시 유도
    /// 3) 짧은 대기 후 정직한 완료 안내
    @MainActor
    private func triggerManualSync() async {
        guard !isSyncing else { return }
        settingsLogger.info("[Settings] 수동 iCloud 동기화 시작")
        isSyncing = true
        syncResultMessage = nil
        defer { isSyncing = false }

        // 1) 계정 상태 확인
        let available = await checkAccountAvailable()
        iCloudAccountAvailable = available
        settingsLogger.info("[Settings] iCloud 계정 상태: \(available ? "available" : "unavailable")")
        guard available else {
            syncResultMessage = "iCloud에 로그인되어 있지 않습니다. iPhone 설정에서 로그인해 주세요."
            settingsLogger.warning("[Settings] 동기화 중단 — iCloud 계정 미로그인")
            return
        }

        // 2) 로컬 변경 강제 저장 → CloudKit 푸시 유도
        do {
            try modelContext.save()
            settingsLogger.info("[Settings] modelContext.save() 성공 — CloudKit 푸시 요청됨")
        } catch {
            syncResultMessage = "로컬 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
            settingsLogger.error("[Settings] modelContext.save() 실패: \(error.localizedDescription)")
            return
        }

        // 3) 짧은 대기 후 정직한 완료 안내
        try? await Task.sleep(nanoseconds: 1_800_000_000)
        syncResultMessage = "동기화를 요청했어요. iCloud 상태에 따라 잠시 후 반영됩니다."
        settingsLogger.info("[Settings] 수동 iCloud 동기화 요청 완료")
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
                Image(systemName: "sparkles")
                    .font(.system(size: 17))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 스코어보드 가져오기")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("AI가 사진 속 스코어카드를 읽어 라운드로 변환")
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
        case .idle:
            if let date = dbLastSuccessAt, date > Date.distantPast {
                return "마지막 동기화: \(kstDateString(date))"
            }
            return "동기화 기록 없음"
        case .loading: return "서버에서 확인 중..."
        case .success(let msg): return msg
        case .failure: return "업데이트 실패 — 잠시 후 다시 시도해 주세요"
        }
    }

    /// CoursesSyncMeta에서 마지막 성공 시각 로드 (courses 기준).
    private func loadDBLastSuccessAt() {
        var descriptor = FetchDescriptor<CoursesSyncMeta>(
            predicate: #Predicate { $0.endpoint == "courses" }
        )
        descriptor.fetchLimit = 1
        if let meta = (try? modelContext.fetch(descriptor))?.first,
           meta.lastSuccessAt > Date.distantPast {
            dbLastSuccessAt = meta.lastSuccessAt
        }
    }

    /// KST yyyy.MM.dd HH:mm 포맷 날짜 문자열.
    private func kstDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return formatter.string(from: date)
    }

    private func triggerDBUpdate() {
        guard dbUpdateState != .loading else { return }
        dbUpdateState = .loading
        Task {
            let (coursesUpdated, parsUpdated) = await CourseRepository.shared.fetchRemoteForce(context: modelContext)
            loadDBLastSuccessAt()
            if coursesUpdated || parsUpdated {
                dbUpdateState = .success("업데이트 완료")
            } else {
                dbUpdateState = .success("최신 데이터입니다")
            }
            // 3초 후 idle 복귀
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            dbUpdateState = .idle
        }
    }

    // MARK: - AI Analysis row

    private var aiAnalysisRow: some View {
        Button {
            showAIAnalysis = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 사용 설정")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("무료 횟수 \(RewardedAdManager.shared.remaining)/3 · 개인정보 동의 관리")
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
