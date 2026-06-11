import SwiftUI
import SwiftData
import Shared
import GoogleMobileAds
import AppTrackingTransparency

@main
struct RoundOnApp: App {
    let modelContainer: ModelContainer

    /// scene이 .active가 된 시점에 ATT 플로우를 1회만 트리거하기 위한 환경/상태.
    @Environment(\.scenePhase) private var scenePhase
    @State private var didStartTrackingFlow = false

    init() {
        // ⚠️ AdMob SDK 초기화는 ATT 동의 응답 이후로 이동 (startTrackingThenAds).
        //    정책상 IDFA 기반 SDK는 ATT 응답 후 초기화가 옳다 (App Store Guideline 2.1).

        // CloudKit 초기화 실패 시 로컬 전용으로 fallback — fatal 없이 앱 계속 실행
        if let container = Self.makeModelContainerWithFallback() {
            self.modelContainer = container
        } else {
            // 로컬 전용도 실패 시 인메모리로 최후 fallback
            AppLogger.persistence.error("모든 ModelContainer 초기화 실패 — 인메모리 fallback 진입")
            let schema = Schema([
                Round.self, Player.self, HoleScore.self,
                PersistedDiscoveredCourse.self,
                UserParOverride.self, CoursesSyncMeta.self,
                StatsShareRecord.self
            ])
            // swiftlint:disable:next force_try
            self.modelContainer = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    /// CloudKit → 로컬 전용 2단계 fallback
    private static func makeModelContainerWithFallback() -> ModelContainer? {
        let schema = Schema([
            Round.self,
            Player.self,
            HoleScore.self,
            PersistedDiscoveredCourse.self,  // 카카오 발견 골프장 영구 캐시
            UserParOverride.self,             // 사용자 par 수정 영구 저장 (신규)
            CoursesSyncMeta.self,            // 원격 fetch 동기화 메타 (신규)
            StatsShareRecord.self            // 통계 공유 영속 레코드 (stats-share-v1)
        ])

        // GolfCourse는 등록 안 함 (20-ARCHITECTURE §6 옵션 A — 번들 JSON 인메모리 로드)

        // 1단계: CloudKit 또는 비활성 설정으로 시도
        do {
            let container = try makeModelContainer(schema: schema)
            AppLogger.persistence.info("ModelContainer 초기화 성공")
            return container
        } catch {
            // 2단계: 로컬 전용 fallback (iCloud 미로그인, CloudKit 비활성 환경 대응)
            AppLogger.persistence.error("CloudKit ModelContainer 실패 — 로컬 전용 fallback: \(error)")
            do {
                let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: localConfig)
                AppLogger.persistence.warning("로컬 전용 ModelContainer로 실행 중 (CloudKit 비활성)")
                return container
            } catch {
                AppLogger.persistence.error("로컬 전용 ModelContainer도 실패: \(error)")
                return nil
            }
        }
    }

    private static func makeModelContainer(schema: Schema) throws -> ModelContainer {
        // CloudKit 안전 토글:
        // - 시뮬레이터: 항상 비활성 (빌드 컨피그 무관 — Release QA 시뮬레이터에서도 안전)
        // - 환경변수 ROUNDON_DISABLE_CLOUDKIT=1: 비활성
        // - 그 외: CloudKit private DB
        #if targetEnvironment(simulator)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
        #else
        if ProcessInfo.processInfo.environment["ROUNDON_DISABLE_CLOUDKIT"] == "1" {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        }
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.kr.zerolive.golf.roundon"))
        return try ModelContainer(for: schema, configurations: config)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .onAppear {
                    AppLogger.app.info("RoundOn 앱 시작")
                    // cold start 원격 fetch (7일 stale 기준, 라운드 진행 중 호출 금지)
                    let context = modelContainer.mainContext
                    Task {
                        await CourseRepository.shared.fetchRemoteIfStale(context: context)
                        // F: 기존 courseId 미지정 라운드 backfill (confident match만, 앱 시작 1회)
                        await Self.backfillRoundCourseIds(context: context)
                    }
                }
                // ATT는 scene이 .active가 된 시점에만 트리거 (1회).
                // requestTrackingAuthorization()은 앱이 .active일 때만 프롬프트를 띄우므로,
                // onAppear+sleep 대신 .active 시점을 명시적으로 잡아 프롬프트 표시를 보장한다.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active && !didStartTrackingFlow {
                        didStartTrackingFlow = true
                        Task { await startTrackingThenAds() }
                    }
                }
        }
    }

    // MARK: - F: 기존 라운드 courseId backfill (앱 시작 1회)

    /// courseId == "" 인 finished Round에 대해 confident match가 있으면 courseId를 채워 저장한다.
    /// 애매하면(매칭 없음/불확실) skip — 런타임 courseFor가 표시를 이미 처리하므로 안전이 최우선.
    @MainActor
    private static func backfillRoundCourseIds(context: ModelContext) async {
        // 1회 가드 (UserDefaults)
        let flagKey = "roundon.backfill.courseId.v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let courses = (try? await CourseRepository.shared.loadAll()) ?? []
        guard !courses.isEmpty else {
            AppLogger.round.info("[Backfill] 골프장 DB 비어있음 — backfill 보류")
            return
        }

        var descriptor = FetchDescriptor<Round>()
        descriptor.predicate = #Predicate { $0.isFinished == true && $0.courseId == "" }
        let targets = (try? context.fetch(descriptor)) ?? []
        guard !targets.isEmpty else {
            UserDefaults.standard.set(true, forKey: flagKey)
            AppLogger.round.info("[Backfill] 대상 라운드 없음 — 완료 처리")
            return
        }

        var filled = 0
        for round in targets {
            let name = round.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let candidates = CourseNameMatcher.findSimilarCourses(query: name, from: courses, limit: 1)
            guard let top = candidates.first,
                  CourseNameMatcher.matches(course: top, query: name) else {
                continue // 애매하면 skip
            }
            round.courseId = top.id
            round.courseName = top.name
            filled += 1
        }

        if filled > 0 {
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: flagKey)
        AppLogger.round.info("[Backfill] courseId backfill 완료 — \(targets.count)개 중 \(filled)개 채움")
    }

    // MARK: - ATT (App Tracking Transparency) → AdMob 초기화 순서 보장

    /// scene .active 진입 직후 실행되는 권한/광고 부트스트랩.
    /// 순서: ① ATT 요청(응답 대기) → ② AdMob 초기화 → ③ ContentView에 ATT 완료 통지(위치 부트스트랩 해제).
    @MainActor
    private func startTrackingThenAds() async {
        // active 직후 UI 안정화를 위한 짧은 한 번의 지연 (긴 sleep 금지).
        try? await Task.sleep(nanoseconds: 400_000_000)

        // ① ATT 요청 — scene이 .active이므로 .notDetermined면 프롬프트가 확실히 뜬다.
        await requestTrackingPermission()

        // ② AdMob SDK 초기화 — ATT 응답(허용/거부 무관) 이후에 시작.
        GADMobileAds.sharedInstance().start { status in
            let count = status.adapterStatusesByClassName.count
            AppLogger.app.info("AdMob SDK 초기화 완료: \(count)개 어댑터 (ATT 응답 후)")
        }

        // ③ ATT 플로우 완료 통지 → ContentView의 위치 권한 부트스트랩 해제.
        TrackingCoordinator.shared.markCompleted()
    }

    /// ATT 추적 권한 요청 (1회만 표시, 이후 저장된 상태 반환)
    /// - 허용: 맞춤 광고 → eCPM 높음
    /// - 거부: 비맞춤 광고 (기능 차이 없음, 수익만 감소)
    @MainActor
    private func requestTrackingPermission() async {
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
            AppLogger.app.info("ATT 이미 결정됨: \(status.rawValue) — 프롬프트 생략")
            return
        }

        AppLogger.app.info("ATT 요청 진입 — scene active, 프롬프트 표시 시도")
        let newStatus = await ATTrackingManager.requestTrackingAuthorization()
        switch newStatus {
        case .authorized:
            AppLogger.app.info("ATT 추적 허용")
        case .denied:
            AppLogger.app.info("ATT 추적 거부 — 비맞춤 광고 진행")
        case .restricted:
            AppLogger.app.info("ATT 추적 제한됨")
        case .notDetermined:
            AppLogger.app.info("ATT 미결정")
        @unknown default:
            AppLogger.app.info("ATT 알 수 없는 상태")
        }
    }
}
