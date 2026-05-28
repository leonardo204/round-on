import SwiftUI
import SwiftData
import Shared

@main
struct RoundOnApp: App {
    let modelContainer: ModelContainer

    init() {
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
                    }
                }
        }
    }
}
