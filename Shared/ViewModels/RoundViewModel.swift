import Foundation
import SwiftData
import Observation

// MARK: - RoundViewModel
// 라운드 라이프사이클 관리 (22-STATE_MANAGEMENT §3)
// F6: 앱 재시작 시 진행 중인 라운드 자동 복구
// A1: WorkoutCoordinator는 클로저 DI로 연결 (Shared → App-iOS 역방향 의존성 방지)

@Observable
@MainActor
public final class RoundViewModel {

    // MARK: Published state

    public var currentRound: Round?
    public var isRoundActive: Bool { currentRound != nil && !(currentRound?.isFinished ?? true) }

    /// HealthKit 권한 실패 등 배너 표시용 메시지
    public var bannerMessage: String?

    // 하위 VM (RoundViewModel이 소유)
    public private(set) var holeViewModel: HoleViewModel?
    public private(set) var scoreCardViewModel: ScoreCardViewModel?
    public private(set) var playerListViewModel: PlayerListViewModel?

    // MARK: HealthKit DI (A1)

    /// App-iOS에서 WorkoutCoordinator.shared.startWorkout(courseName:)를 주입
    public var onWorkoutStart: ((String) async -> Void)?

    /// App-iOS에서 WorkoutCoordinator.shared.endWorkout()를 주입
    public var onWorkoutEnd: (() async -> Void)?

    /// App-iOS에서 WorkoutCoordinator.bannerMessage를 수신해 여기에 반영하도록 주입
    public var onWorkoutBannerUpdate: (() -> String?)?

    // MARK: Private

    private let modelContext: ModelContext

    // MARK: Init

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: Public API

    /// 진행 중인 라운드 복구 (F6). 앱 시작 시 호출.
    public func resumeIfNeeded() {
        let descriptor = FetchDescriptor<Round>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let rounds = try? modelContext.fetch(descriptor),
           let latestRound = rounds.first {
            activate(round: latestRound)
        }
    }

    /// 새 라운드 시작
    public func startRound(
        courseId: String,
        courseName: String,
        courseSubName: String?,
        players: [Player],
        holesCount: Int
    ) {
        let round = Round(
            courseId: courseId,
            courseName: courseName,
            courseSubName: courseSubName,
            players: players,
            startedAt: .now
        )

        // HoleScore 초기화 (par 기본값 4)
        for holeNumber in 1...holesCount {
            let score = HoleScore(holeNumber: holeNumber, par: 4)
            round.holes.append(score)
        }

        modelContext.insert(round)
        try? modelContext.save()

        activate(round: round)

        // A1: HealthKit 운동 시작 (권한 실패 시에도 라운드는 정상 진행)
        Task {
            await onWorkoutStart?(courseName)
            // 배너 메시지 수신
            if let msg = onWorkoutBannerUpdate?(), !msg.isEmpty {
                bannerMessage = msg
            }
        }
    }

    /// 라운드 종료
    public func finishRound() {
        guard let round = currentRound else { return }
        round.isFinished = true
        round.finishedAt = .now
        try? modelContext.save()
        deactivate()

        // A1: HealthKit 운동 종료
        Task {
            await onWorkoutEnd?()
        }
    }

    /// 카운트 +1
    public func increment(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return }

        let maxCount = 15  // spec_3.md §8.3
        let current = holeScore.count(for: playerId)
        guard current < maxCount else { return }

        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// 카운트 -1
    public func decrement(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return }

        let current = holeScore.count(for: playerId)
        guard current > 0 else { return }  // 0 미만 금지

        upsertCount(in: holeScore, playerId: playerId, delta: -1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// OB 탭 (+2)
    public func tapOB(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertOB(in: holeScore, playerId: playerId, delta: 1)
        upsertCount(in: holeScore, playerId: playerId, delta: 2)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// 해저드 탭 (+1 벌타 + counts +1)
    public func tapHazard(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertHazard(in: holeScore, playerId: playerId, delta: 1)
        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// OK/컨시드 탭 (+1)
    public func tapOK(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    // MARK: Private helpers

    private func activate(round: Round) {
        self.currentRound = round
        let holeVM = HoleViewModel(totalHoles: round.holes.count)
        self.holeViewModel = holeVM
        self.scoreCardViewModel = ScoreCardViewModel(round: round)
        self.playerListViewModel = PlayerListViewModel(players: round.players)
    }

    private func deactivate() {
        self.currentRound = nil
        self.holeViewModel = nil
        self.scoreCardViewModel = nil
        self.playerListViewModel = nil
    }

    private func save() {
        try? modelContext.save()
    }

    private func upsertCount(in holeScore: HoleScore, playerId: UUID, delta: Int) {
        if let idx = holeScore.counts.firstIndex(where: { $0.playerId == playerId }) {
            holeScore.counts[idx].value = max(0, holeScore.counts[idx].value + delta)
        } else if delta > 0 {
            holeScore.counts.append(ScoreEntry(playerId: playerId, value: delta))
        }
    }

    private func upsertOB(in holeScore: HoleScore, playerId: UUID, delta: Int) {
        if let idx = holeScore.obCount.firstIndex(where: { $0.playerId == playerId }) {
            holeScore.obCount[idx].value += delta
        } else {
            holeScore.obCount.append(ScoreEntry(playerId: playerId, value: delta))
        }
    }

    private func upsertHazard(in holeScore: HoleScore, playerId: UUID, delta: Int) {
        if let idx = holeScore.hazardCount.firstIndex(where: { $0.playerId == playerId }) {
            holeScore.hazardCount[idx].value += delta
        } else {
            holeScore.hazardCount.append(ScoreEntry(playerId: playerId, value: delta))
        }
    }
}
