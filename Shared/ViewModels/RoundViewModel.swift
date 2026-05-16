import Foundation
import SwiftData
import Observation
import OSLog

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
            AppLogger.round.info("미완료 라운드 복구: \(latestRound.courseName, privacy: .private)")
            activate(round: latestRound)
        } else {
            AppLogger.round.debug("복구할 미완료 라운드 없음")
        }
    }

    /// 새 라운드 시작
    /// - Parameters:
    ///   - courseId: 골프장 DB ID
    ///   - courseName: 골프장 이름
    ///   - frontCourseName: 전반 9홀 코스 라벨 (예: "동코스"). nil이면 화면에서 "전반" 표시.
    ///   - backCourseName: 후반 9홀 코스 라벨 (예: "남코스"). 9홀 라운드면 nil.
    ///   - players: 참가 플레이어 목록
    ///   - holesCount: 9 또는 18만 허용. 그 외 값은 release 빌드에서도 안전 거부.
    public func startRound(
        courseId: String,
        courseName: String,
        frontCourseName: String? = nil,
        backCourseName: String? = nil,
        players: [Player],
        holesCount: Int
    ) {
        // 9/18 외 값은 모든 빌드에서 안전 거부 (라운드 미생성)
        guard holesCount == 9 || holesCount == 18 else {
            AppLogger.round.error("holesCount는 9 또는 18만 허용됩니다. 전달된 값: \(holesCount)")
            return
        }

        // 9홀 라운드이면 backCourseName을 강제로 nil 처리 (UI 미리셋 누락 방어)
        let normalizedBack = (holesCount == 9) ? nil : backCourseName

        // legacy courseSubName: displaySubLabel과 동기화 (18홀 front+back 모두 보존)
        let legacyJoined = [frontCourseName, normalizedBack]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
        let legacySubName: String? = legacyJoined.isEmpty ? nil : legacyJoined

        let round = Round(
            courseId: courseId,
            courseName: courseName,
            // legacy courseSubName: front/back 합성 값으로 동기화 (displaySubLabel과 일치)
            courseSubName: legacySubName,
            frontCourseName: frontCourseName,
            backCourseName: normalizedBack,
            players: players,
            startedAt: .now
        )

        // HoleScore 초기화 (par 기본값 4)
        var holeScores: [HoleScore] = []
        for holeNumber in 1...holesCount {
            let score = HoleScore(holeNumber: holeNumber, par: 4)
            holeScores.append(score)
        }
        round.holes = (round.holes ?? []) + holeScores

        modelContext.insert(round)
        try? modelContext.save()

        AppLogger.round.info("라운드 시작: \(courseName, privacy: .private) \(holesCount)홀 \(players.count)명")

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
        let totalHoles = round.holeList.count
        round.isFinished = true
        round.finishedAt = .now
        try? modelContext.save()
        AppLogger.round.info("라운드 종료: \(round.courseName, privacy: .private) \(totalHoles)홀")
        deactivate()

        // A1: HealthKit 운동 종료
        Task {
            await onWorkoutEnd?()
        }
    }

    /// 카운트 +1
    public func increment(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        let maxCount = 15  // spec_3.md §8.3
        let current = holeScore.count(for: playerId)
        guard current < maxCount else { return }

        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    // MARK: F7 — 사후 편집 API

    /// 완료된 라운드 편집 진입. ScoreCardViewModel 재생성.
    public func editRound(_ round: Round) {
        AppLogger.round.info("라운드 편집 진입: \(round.courseName, privacy: .private)")
        self.currentRound = round
        self.scoreCardViewModel = ScoreCardViewModel(round: round)
        self.playerListViewModel = PlayerListViewModel(players: round.playerList)
    }

    /// 편집 내용 저장. SwiftData에 쓰기 후 scoreCardViewModel 갱신.
    /// - Returns: 저장 성공 여부
    @discardableResult
    public func commitEdit() throws -> Bool {
        guard let round = currentRound else { return false }
        try modelContext.save()
        AppLogger.round.info("라운드 편집 저장 완료: \(round.courseName, privacy: .private)")
        scoreCardViewModel?.refresh(from: round)
        // 편집 완료 후 currentRound 초기화 (홈으로 돌아갈 때 활성 라운드 오판 방지)
        // isFinished == true인 경우만 deactivate
        if round.isFinished {
            self.currentRound = nil
            self.scoreCardViewModel = nil
            self.playerListViewModel = nil
        }
        return true
    }

    /// 카운트 -1
    public func decrement(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        let current = holeScore.count(for: playerId)
        guard current > 0 else { return }  // 0 미만 금지

        upsertCount(in: holeScore, playerId: playerId, delta: -1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// OB 탭 (+2)
    public func tapOB(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertOB(in: holeScore, playerId: playerId, delta: 1)
        upsertCount(in: holeScore, playerId: playerId, delta: 2)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// 해저드 탭 (+1 벌타 + counts +1)
    public func tapHazard(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertHazard(in: holeScore, playerId: playerId, delta: 1)
        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    /// OK/컨시드 탭 (+1)
    public func tapOK(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save()
        scoreCardViewModel?.refresh(from: round)
    }

    // MARK: Private helpers

    private func activate(round: Round) {
        self.currentRound = round
        let holeVM = HoleViewModel(totalHoles: round.holeList.count)
        self.holeViewModel = holeVM
        self.scoreCardViewModel = ScoreCardViewModel(round: round)
        self.playerListViewModel = PlayerListViewModel(players: round.playerList)
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
            let before = holeScore.counts[idx].value
            let after = max(0, before + delta)
            if delta < 0 && before == 0 {
                AppLogger.counter.warning("카운터 clamp: 홀\(holeScore.holeNumber) 음수 차단")
            } else {
                AppLogger.counter.debug("카운터: 홀\(holeScore.holeNumber) \(before)→\(after)")
            }
            holeScore.counts[idx].value = after
        } else if delta > 0 {
            AppLogger.counter.debug("카운터 신규: 홀\(holeScore.holeNumber) delta=\(delta)")
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
