import Foundation
import Shared

extension RoundViewModel {
    /// HealthKit 워크아웃 클로저 자동 연결.
    /// `RoundViewModel`(Shared)이 `WorkoutCoordinator`(App-iOS)를 직접 의존하지 않도록 분리.
    /// 앱 진입점에서 ViewModel 생성 직후 한 번 호출.
    @MainActor
    public func attachWorkoutCoordinator() {
        onWorkoutStart = { courseName in
            await WorkoutCoordinator.shared.startWorkout(courseName: courseName)
        }
        onWorkoutEnd = {
            await WorkoutCoordinator.shared.endWorkout()
        }
        onWorkoutBannerUpdate = {
            WorkoutCoordinator.shared.bannerMessage
        }
    }
}
