import Foundation
import HealthKit
import Observation

// MARK: - WorkoutCoordinator
// B3: HealthKit 골프 운동 세션 관리 (53-PERMISSIONS §4)
// 시뮬레이터에서도 빌드 통과: HKHealthStore.isHealthDataAvailable() 분기 처리

@Observable
@MainActor
public final class WorkoutCoordinator {

    // MARK: State

    public var isAuthorized: Bool = false
    public var isWorkoutActive: Bool = false
    public var errorMessage: String?

    // MARK: Private

    private let healthStore = HKHealthStore()
    private var builder: HKWorkoutBuilder?

    // MARK: Init

    public init() {}

    // MARK: 권한 요청

    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            // 시뮬레이터 / HealthKit 미지원 기기
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
            errorMessage = "건강 앱 권한을 가져올 수 없어요."
            return false
        }
    }

    // MARK: 운동 시작 (라운드 시작 시)

    public func startWorkout() async {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .golf
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        self.builder = builder

        do {
            try await builder.beginCollection(at: .now)
            isWorkoutActive = true
        } catch {
            errorMessage = "운동 기록을 시작할 수 없어요."
            self.builder = nil
        }
    }

    // MARK: 운동 종료 (라운드 종료 시)

    public func endWorkout() async {
        guard let builder = builder, isWorkoutActive else { return }

        do {
            try await builder.endCollection(at: .now)
            let _ = try await builder.finishWorkout()
            isWorkoutActive = false
            self.builder = nil
        } catch {
            errorMessage = "운동 기록을 저장할 수 없어요."
            self.builder = nil
            isWorkoutActive = false
        }
    }
}
