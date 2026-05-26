import Foundation
import Observation

// MARK: - HoleViewModel
// 수동 홀 진행 상태 관리 (22-STATE_MANAGEMENT §3)
// F3: 홀 단위 자동 감지 미제공 — 수동 홀 진행만 지원

@Observable
@MainActor
public final class HoleViewModel {

    // MARK: State

    /// 0-indexed 현재 홀 인덱스
    public private(set) var currentHoleIndex: Int = 0
    /// 전체 홀 수 (9 / 18 / 27 / 36 등)
    public let totalHoles: Int

    /// 홀 변경 시 호출 — RoundViewModel이 setup하여 WC sync 송출에 활용
    /// 인자: (새 1-indexed 홀 번호)
    public var onHoleChanged: ((Int) -> Void)?

    // MARK: Computed

    /// 1-indexed 현재 홀 번호 (표시용)
    public var currentHoleNumber: Int { currentHoleIndex + 1 }
    /// OUT(1-9) / IN(10-18) 구분 (18홀 기준)
    public var isInSection: Bool { currentHoleNumber > 9 }
    /// 마지막 홀 여부
    public var isLastHole: Bool { currentHoleIndex == totalHoles - 1 }
    /// 첫 번째 홀 여부
    public var isFirstHole: Bool { currentHoleIndex == 0 }

    // MARK: Init

    /// - Parameters:
    ///   - totalHoles: 전체 홀 수
    ///   - initialHoleNumber: 복원 시작 홀 번호 (1-indexed). 기본값 1.
    public init(totalHoles: Int, initialHoleNumber: Int = 1) {
        self.totalHoles = max(1, totalHoles)
        let clamped = max(1, min(initialHoleNumber, self.totalHoles))
        self.currentHoleIndex = clamped - 1
    }

    // MARK: Navigation

    /// 다음 홀로 이동 (마지막 홀에서는 무시)
    public func nextHole() {
        guard !isLastHole else { return }
        currentHoleIndex += 1
        onHoleChanged?(currentHoleNumber)
    }

    /// 이전 홀로 이동 (첫 번째 홀에서는 무시)
    public func previousHole() {
        guard !isFirstHole else { return }
        currentHoleIndex -= 1
        onHoleChanged?(currentHoleNumber)
    }

    /// 특정 홀로 직접 이동 (0-indexed). 호출자가 silent=true로 callback 억제 가능 (원격 적용 시).
    public func goToHole(index: Int, silent: Bool = false) {
        guard index >= 0 && index < totalHoles else { return }
        let changed = (currentHoleIndex != index)
        currentHoleIndex = index
        if changed && !silent {
            onHoleChanged?(currentHoleNumber)
        }
    }
}
