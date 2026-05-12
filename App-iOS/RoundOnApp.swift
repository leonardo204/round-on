import SwiftUI
import SwiftData
import Shared

@main
struct RoundOnApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            self.modelContainer = try Self.makeModelContainer()
        } catch {
            fatalError("ModelContainer 초기화 실패: \(error)")
        }
    }

    static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([Round.self, Player.self, HoleScore.self, RoundPhoto.self])
        // GolfCourse는 등록 안 함 (20-ARCHITECTURE §6 옵션 A — 번들 JSON 인메모리 로드)

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
        }
    }
}
