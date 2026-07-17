import SwiftUI
import SwiftData
import Shared

// MARK: - RoundOnWatchApp
// Watch 루트. iPhone에서 시작된 라운드를 WCSession으로 받아 in-memory에 보관 후 진행.
// Watch는 source-of-truth가 아니라 mirror — 영구 저장은 iPhone (CloudKit 또는 local).

@main
struct RoundOnWatchApp: App {

    /// 초기화 실패 시 nil. iOS와 달리 CloudKit→로컬 단계가 없어 재시도할 대체 store가 존재하지 않으므로,
    /// 유일한 폴백은 "컨테이너 없이 런치해서 상태를 고지"하는 것 (try!로 즉시 크래시하면 복구 불가).
    let modelContainer: ModelContainer?

    init() {
        self.modelContainer = Self.makeInMemoryContainer()
    }

    /// Watch용 인메모리 ModelContainer 생성.
    /// iOS의 3단(CloudKit→로컬→인메모리) 폴백을 그대로 옮기지 않는 이유:
    /// Watch는 이미 최종 단계인 인메모리 store만 쓰고(영구 저장은 iPhone 담당),
    /// 실패 원인은 사실상 schema 자체이므로 같은 schema로 재시도해봐야 동일하게 실패한다.
    private static func makeInMemoryContainer() -> ModelContainer? {
        let schema = Schema([Round.self, Player.self, HoleScore.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            AppLogger.persistence.info("[Watch] 인메모리 ModelContainer 초기화 성공")
            return container
        } catch {
            AppLogger.persistence.critical("[Watch] 인메모리 ModelContainer 초기화 실패 — 미러링 불가 안내 화면으로 전환: \(error)")
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                WatchContentView()
                    .modelContainer(modelContainer)
            } else {
                // 크래시 대신 상태 고지 — Watch가 죽어도 iPhone 기록은 안전하다는 점을 알린다.
                WatchStorageUnavailableView()
            }
        }
    }
}

// MARK: - WatchStorageUnavailableView
// ModelContainer 초기화 실패 전용 화면. Watch는 mirror이므로 이 상태에서도 iPhone 라운드는 정상 진행된다.

struct WatchStorageUnavailableView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                Text("워치에서 라운드를 열 수 없어요")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("아이폰에서는 그대로 기록할 수 있어요. 워치 앱을 다시 실행해 주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .onAppear {
            AppLogger.app.error("[Watch] 저장소 사용 불가 화면 표시 — ModelContainer 초기화 실패")
        }
    }
}
