import Foundation
import HealthKit
import Observation

// MARK: - WorkoutCoordinator
// B3: HealthKit 골프 운동 세션 관리 (53-PERMISSIONS §4)
// 시뮬레이터에서도 빌드 통과: HKHealthStore.isHealthDataAvailable() 분기 처리
// RoundViewModel이 startRound/finishRound 시 자동 호출

@Observable
@MainActor
public final class WorkoutCoordinator {

    // MARK: Singleton

    public static let shared = WorkoutCoordinator()

    // MARK: State

    public var isAuthorized: Bool = false
    public var isWorkoutActive: Bool = false

    /// 권한 실패 등 사용자에게 노출할 배너 메시지
    public var bannerMessage: String?

    // MARK: Private

    private let healthStore = HKHealthStore()
    private var builder: HKWorkoutBuilder?

    // MARK: Init

    public init() {}

    // MARK: 권한 요청

    /// HealthKit 권한을 요청한다. 권한 실패/미지원이면 false 반환 (라운드 진행은 방해하지 않음)
    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            // 시뮬레이터 / HealthKit 미지원 기기 → 조용히 false
            return false
        }

        let types: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: types, read: [])
            isAuthorized = true
            return true
        } catch {
            // 권한 실패 시 배너 메시지 설정 (라운드 중단 없음)
            bannerMessage = "건강 데이터 권한이 없어 운동 기록이 저장되지 않습니다."
            return false
        }
    }

    // MARK: 운동 시작 (라운드 시작 시)

    /// 골프 운동 세션을 시작한다. 권한 없음/미지원이면 배너를 띄우고 종료 (라운드 계속 진행)
    public func startWorkout(courseName: String) async {
        // 권한 요청 (아직 미요청이면 여기서 요청)
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted {
                // 배너는 requestAuthorization 내부에서 설정됨
                return
            }
        }

        guard HKHealthStore.isHealthDataAvailable() else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .golf
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        self.builder = builder

        do {
            try await builder.beginCollection(at: .now)
            isWorkoutActive = true
        } catch {
            bannerMessage = "운동 기록을 시작할 수 없어요."
            self.builder = nil
        }
    }

    // MARK: 운동 종료 (라운드 종료 시)

    /// 골프 운동 세션을 종료하고 HealthKit에 저장한다
    public func endWorkout() async {
        guard let builder = builder, isWorkoutActive else { return }

        do {
            try await builder.endCollection(at: .now)
            let _ = try await builder.finishWorkout()
            isWorkoutActive = false
            self.builder = nil
        } catch {
            bannerMessage = "운동 기록을 저장할 수 없어요."
            self.builder = nil
            isWorkoutActive = false
        }
    }
}
