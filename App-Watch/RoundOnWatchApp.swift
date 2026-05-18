import SwiftUI
import SwiftData
import Shared

// MARK: - RoundOnWatchApp
// Watch 루트. iPhone에서 시작된 라운드를 WCSession으로 받아 in-memory에 보관 후 진행.
// Watch는 source-of-truth가 아니라 mirror — 영구 저장은 iPhone (CloudKit 또는 local).

@main
struct RoundOnWatchApp: App {

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        self.modelContainer = try! ModelContainer(for: schema, configurations: config)
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(modelContainer)
        }
    }
}
