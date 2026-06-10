import Foundation
import HealthKit
import OSLog
import Combine

// MARK: - WatchWorkoutManager (watchOS 전용)
// 라운드 진행 중 화면 always-on 유지를 위한 HKWorkoutSession 매니저.
//
// 메커니즘: watchOS는 활성 HKWorkoutSession(러닝/운동)이 있는 동안
// 해당 운동 앱을 "always-on" 상태로 유지한다 — 손목을 내려도 시계 화면으로
// 빠지지 않고 라운드 화면이 dimmed 상태로 계속 표시된다(Apple "운동" 앱과 동일).
// iOS의 WorkoutCoordinator는 HKWorkoutBuilder 단독이라 always-on이 안 되므로,
// Watch에서는 HKWorkoutSession + HKLiveWorkoutBuilder를 사용한다.
//
// 시뮬레이터/HealthKit 미지원 환경에서는 isHealthDataAvailable() 가드로 조용히
// no-op 처리하여 빌드/런타임 크래시를 방지한다. 라운드 진행은 절대 막지 않는다.

@MainActor
public final class WatchWorkoutManager: NSObject, ObservableObject {

    // MARK: Singleton

    public static let shared = WatchWorkoutManager()

    // MARK: Logging

    private static let log = Logger(subsystem: "kr.zerolive.golf.roundon", category: "WatchWorkout")

    // MARK: State

    /// HealthKit 권한 승인 여부(요청 완료 후 true)
    private var isAuthorized = false

    /// 세션 활성 여부 — 중복 start/end 방지 가드.
    /// 컨트롤 페이지 버튼 라벨/노출이 관찰하므로 @Published.
    @Published public private(set) var isActive = false

    /// 일시정지 여부 — 컨트롤 페이지 멈춤↔재개 라벨 토글이 관찰.
    @Published public private(set) var isPaused = false

    // MARK: Private

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: Init

    private override init() {
        super.init()
    }

    // MARK: 권한 요청

    /// HealthKit 권한을 요청한다. 미지원/시뮬레이터/실패면 false (라운드 진행은 방해하지 않음)
    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            Self.log.notice("requestAuthorization skip — HealthKit unavailable (simulator?)")
            return false
        }

        let share: Set<HKSampleType> = [HKQuantityType.workoutType()]

        do {
            try await healthStore.requestAuthorization(toShare: share, read: [])
            isAuthorized = true
            Self.log.info("requestAuthorization granted")
            return true
        } catch {
            Self.log.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: 세션 시작 (라운드 활성화 시)

    /// 골프 운동 세션을 시작해 화면 always-on을 유지한다.
    /// 이미 활성 상태면 중복 시작하지 않는다. 실패해도 라운드는 계속 진행된다(로그만).
    public func startWorkout() async {
        guard !isActive else {
            Self.log.notice("startWorkout skip — session already active")
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            Self.log.notice("startWorkout skip — HealthKit unavailable (simulator?)")
            return
        }

        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted {
                Self.log.notice("startWorkout abort — authorization not granted")
                return
            }
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .golf
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            session.delegate = self

            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            isActive = true
            Self.log.info("startWorkout ok — HKWorkoutSession started (always-on engaged)")
        } catch {
            Self.log.error("startWorkout failed: \(error.localizedDescription, privacy: .public)")
            // 정리 — 라운드 진행은 막지 않음
            session = nil
            builder = nil
            isActive = false
        }
    }

    // MARK: 일시정지 / 재개 (컨트롤 페이지)

    /// 운동 세션을 일시정지한다 — always-on/측정을 잠시 멈춘다.
    /// 세션 비활성이거나 이미 멈춤이면 no-op.
    public func pauseWorkout() {
        guard isActive else {
            Self.log.notice("pauseWorkout skip — no active session")
            return
        }
        guard !isPaused else {
            Self.log.notice("pauseWorkout skip — already paused")
            return
        }
        session?.pause()
        isPaused = true
        Self.log.info("pauseWorkout ok — session paused")
    }

    /// 일시정지된 운동 세션을 재개한다. 세션 비활성이거나 멈춤 상태가 아니면 no-op.
    public func resumeWorkout() {
        guard isActive else {
            Self.log.notice("resumeWorkout skip — no active session")
            return
        }
        guard isPaused else {
            Self.log.notice("resumeWorkout skip — not paused")
            return
        }
        session?.resume()
        isPaused = false
        Self.log.info("resumeWorkout ok — session resumed")
    }

    // MARK: 세션 종료 (라운드 종료 시)

    /// always-on이 라운드 비활성 상태에서 살아있는 "좀비 세션"인지 검사하고,
    /// 그렇다면 정리한다. 호출부(scenePhase/.task 등)에서 불일치 감지 시 사용.
    /// 좀비가 아니면(세션 없음) no-op.
    public func cleanupIfZombie(reason: String) async {
        guard isActive else { return }
        Self.log.notice("zombie workout session detected — cleaning up (reason: \(reason, privacy: .public))")
        await endWorkout()
    }

    /// 운동 세션을 종료하고 HealthKit에 저장한다. 비활성이면 no-op.
    public func endWorkout() async {
        guard isActive, let session = session, let builder = builder else {
            Self.log.notice("endWorkout skip — no active session")
            return
        }

        let end = Date()
        session.end()

        do {
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            Self.log.info("endWorkout ok — session ended & workout saved")
        } catch {
            Self.log.error("endWorkout failed: \(error.localizedDescription, privacy: .public)")
        }

        // 상태 정리(성공/실패 무관)
        self.session = nil
        self.builder = nil
        isActive = false
        isPaused = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {

    public nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        let to = toState.rawValue
        let from = fromState.rawValue
        Task { @MainActor in
            Self.log.info("session state: \(from, privacy: .public) -> \(to, privacy: .public)")
            // delegate가 보고하는 실제 세션 상태와 isPaused를 일관 유지
            switch toState {
            case .paused:
                self.isPaused = true
            case .running:
                self.isPaused = false
            case .ended, .stopped:
                // 외부 요인으로 세션이 종료/중단된 경우 상태 가드 해제
                self.isActive = false
                self.isPaused = false
            default:
                break
            }
        }
    }

    public nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            Self.log.error("session failed: \(error.localizedDescription, privacy: .public)")
            self.session = nil
            self.builder = nil
            self.isActive = false
        }
    }
}
