import Foundation
import Shared

/// ATT(App Tracking Transparency) 플로우 완료를 앱 전역에 알리는 조율자.
///
/// 권한 alert 경합 방지가 목적이다:
/// - `RoundOnApp`이 scene `.active` 시점에 ATT 요청 → 응답 후 `markCompleted()` 호출.
/// - `ContentView`가 위치 권한 부트스트랩 전에 `waitUntilCompleted()`로 ATT 완료를 await.
///
/// 이로써 **ATT 응답 완료 → 위치 권한 요청** 순서가 결정론적으로 보장되어
/// 두 시스템 alert이 동시에 겹치지 않는다.
@MainActor
final class TrackingCoordinator {
    static let shared = TrackingCoordinator()

    /// ATT 플로우(요청+응답 또는 이미 결정됨 확인)가 끝났는지 여부.
    private(set) var isCompleted = false

    /// 완료를 기다리는 대기자들의 continuation. 완료 시 일괄 resume.
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    /// ATT 플로우 완료를 알린다. 이후 `waitUntilCompleted()`는 즉시 반환된다.
    func markCompleted() {
        guard !isCompleted else { return }
        isCompleted = true
        AppLogger.app.info("ATT 플로우 완료 신호 — 대기 중인 위치 부트스트랩 \(self.waiters.count)건 해제")
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    /// ATT 플로우가 완료될 때까지 대기한다.
    /// - 안전장치: 어떤 이유로든 ATT 신호가 오지 않아도 `timeout`(초) 후 자동 진행.
    func waitUntilCompleted(timeout: TimeInterval = 5.0) async {
        if isCompleted { return }

        // 타임아웃 보호: ATT 신호 누락 시에도 위치 부트스트랩이 영구 블록되지 않도록.
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if !isCompleted {
                AppLogger.app.warning("ATT 완료 신호 타임아웃(\(timeout)s) — 위치 부트스트랩 강제 진행")
                markCompleted()
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if isCompleted {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
        timeoutTask.cancel()
    }
}
