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

    /// SwiftData 저장 실패 시 UI 고지용 메시지. 저장이 다시 성공하면 자동으로 nil이 된다.
    /// 저장 실패는 화면상 카운터가 정상으로 보여도 기록이 유실되는 유일한 무증상 경로이므로 UI에 반드시 노출한다.
    /// UI 레이어(ActiveRoundView 등)가 관찰해 배너로 표시 — Shared는 App-iOS를 알지 못한다(상태 노출만).
    public private(set) var lastSaveError: String?

    /// par prefill 성공 시 ActiveRoundView에서 일회성 토스트 표시용
    public var lastPrefillToastMessage: String?

    /// 홀 완료(잠금) 직후 표시할 결과 멘트. 3초 후 자동 nil (UI가 소비).
    public var lastHoleMessage: String?

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

    // MARK: WCSession sync DI (B — iOS↔Watch 양방향)

    /// 디바이스 식별자 ("iPhone" / "Watch") — 자기 자신이 보낸 echo 이벤트 무시용
    public var deviceId: String = "Unknown"

    /// ShotEvent broadcaster — App-iOS/App-Watch에서 WCBroker.send(shotEvent:) 주입
    public var onBroadcastShot: ((ShotEvent) -> Void)?

    /// HoleChange broadcaster
    public var onBroadcastHole: ((HoleChange) -> Void)?

    /// PlayerSwitch broadcaster
    public var onBroadcastPlayerSwitch: ((PlayerSwitch) -> Void)?

    /// RoundSnapshot broadcaster (라운드 시작 + par 변경 시)
    public var onBroadcastSnapshot: ((RoundSnapshot) -> Void)?

    /// RoundEnd broadcaster (라운드 종료/폐기 시)
    public var onBroadcastRoundEnd: ((RoundEnd) -> Void)?

    // MARK: Private

    private let modelContext: ModelContext

    /// 디바이스별 단조 증가 ShotEvent counter
    private var localCounter: UInt64 = 0

    // MARK: Init

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: Sync helpers

    private func nextCounter() -> UInt64 {
        localCounter += 1
        return localCounter
    }

    private func makeSnapshot(from round: Round) -> RoundSnapshot {
        let playerSnaps = round.playerList.map {
            PlayerSnapshot(id: $0.id, name: $0.name, isOwner: $0.isOwner, order: $0.order)
        }
        let parArray = round.holeList
            .sorted { $0.holeNumber < $1.holeNumber }
            .map { $0.par }
        return RoundSnapshot(
            roundId: round.id,
            courseId: round.courseId,
            players: playerSnaps,
            activeHoleNumber: holeViewModel?.currentHoleNumber ?? 1,
            activePlayerIndex: playerListViewModel?.activePlayerIndex ?? 0,
            parArray: parArray
        )
    }

    private func emitShot(type: ShotType, holeNumber: Int, playerId: UUID) {
        guard let broadcast = onBroadcastShot else { return }
        let event = ShotEvent(
            type: type,
            playerId: playerId,
            holeNumber: holeNumber,
            deviceId: deviceId,
            perDeviceCounter: nextCounter()
        )
        broadcast(event)
    }

    private func emitSnapshot() {
        guard let round = currentRound, let broadcast = onBroadcastSnapshot else { return }
        broadcast(makeSnapshot(from: round))
    }

    /// 저장 실패 배너를 사용자가 닫았을 때 UI에서 호출. 다음 저장이 성공해도 자동 해제된다.
    public func clearSaveError() {
        lastSaveError = nil
    }

    /// 현재 활성 라운드의 snapshot을 Watch에 명시적으로 재전송.
    /// 사용처: app 재시작 후 resumeIfNeeded로 라운드 복구된 경우, Watch가 늦게 깬 경우.
    public func broadcastCurrentSnapshot() {
        emitSnapshot()
    }

    private func emitRoundEnd(roundId: UUID, reason: RoundEnd.Reason) {
        guard let broadcast = onBroadcastRoundEnd else { return }
        let end = RoundEnd(roundId: roundId, reason: reason, deviceId: deviceId)
        broadcast(end)
    }

    // MARK: Public API

    /// 진행 중인 라운드 복구 (F6). 앱 시작 및 standby 복귀(scenePhase .active) 시 호출.
    /// 미완료 라운드가 여러 개이면 lastActiveAt desc → startedAt desc 순으로 가장 최근 1개 선택.
    /// 이미 동일 라운드가 활성화되어 있으면 무동작 (idempotent).
    public func resumeIfNeeded() {
        let descriptor = FetchDescriptor<Round>(
            predicate: #Predicate { !$0.isFinished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let rounds = try? modelContext.fetch(descriptor), !rounds.isEmpty else {
            AppLogger.round.debug("복구할 미완료 라운드 없음")
            return
        }
        // lastActiveAt 있는 라운드 우선, 없으면 startedAt 기준 (이미 sortBy로 정렬됨)
        let latestRound = rounds.max(by: {
            let lhs = $0.lastActiveAt ?? $0.startedAt
            let rhs = $1.lastActiveAt ?? $1.startedAt
            return lhs < rhs
        }) ?? rounds[0]

        // 이미 동일 라운드 활성 → 무동작 (idempotent)
        if let current = currentRound, current.id == latestRound.id {
            AppLogger.round.debug("라운드 이미 활성 (idempotent): \(latestRound.courseName, privacy: .private)")
            return
        }

        AppLogger.round.info("미완료 라운드 복구: \(latestRound.courseName, privacy: .private) hole=\(latestRound.lastActiveHoleNumber) player=\(latestRound.lastActivePlayerIndex)")
        activate(round: latestRound)
    }

    /// 새 라운드 시작
    /// - Parameters:
    ///   - courseId: 골프장 DB ID
    ///   - courseName: 골프장 이름
    ///   - frontCourseName: 전반 9홀 코스 라벨 (예: "동코스"). nil이면 화면에서 "전반" 표시.
    ///   - backCourseName: 후반 9홀 코스 라벨 (예: "남코스"). 9홀 라운드면 nil.
    ///   - backTentative: 후반 코스를 "추후 결정"으로 잠정 배정한 경우 — 전반 다음 순번 코스 자동 배정.
    ///   - players: 참가 플레이어 목록
    ///   - holesCount: 9 또는 18만 허용. 그 외 값은 release 빌드에서도 안전 거부.
    public func startRound(
        courseId: String,
        courseName: String,
        frontCourseName: String? = nil,
        backCourseName: String? = nil,
        backTentative: Bool = false,
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

        // 잠정 배정: 전반 다음 순번 코스 자동 결정 (wrap-around)
        let tentativeBackName: String?
        if holesCount == 18 && backTentative {
            tentativeBackName = deriveTentativeBackCourseName(courseId: courseId, frontCourseName: frontCourseName)
            AppLogger.round.info("후반 잠정 배정: courseId=\(courseId) front=\(frontCourseName ?? "-") → tentative=\(tentativeBackName ?? "nil")")
        } else {
            tentativeBackName = nil
        }

        // 실제 사용할 후반 코스명 결정
        let resolvedBack = backTentative ? tentativeBackName : normalizedBack

        // legacy courseSubName: displaySubLabel과 동기화 (18홀 front+back 모두 보존)
        let legacyJoined = [frontCourseName, resolvedBack]
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
            backCourseName: resolvedBack,
            players: players,
            startedAt: .now
        )
        round.isBackTentative = backTentative && (tentativeBackName != nil)

        // HoleScore 초기화 — CourseParsResolver (UserParOverride > CourseParsCatalog)
        let prefillPars: [Int]?
        if holesCount == 18 {
            prefillPars = CourseParsResolver.pars18(courseId: courseId, front: frontCourseName, back: resolvedBack, context: modelContext)
            if let pp = prefillPars {
                AppLogger.round.info("Par prefill 적용: courseId=\(courseId) front=\(frontCourseName ?? "-") back=\(resolvedBack ?? "-") → \(pp)")
            }
        } else {
            prefillPars = CourseParsResolver.pars(courseId: courseId, subCourseName: frontCourseName, context: modelContext)
            if let pp = prefillPars {
                AppLogger.round.info("Par prefill 적용: courseId=\(courseId) front=\(frontCourseName ?? "-") → \(pp)")
            }
        }
        if prefillPars == nil || prefillPars?.count != holesCount {
            AppLogger.round.debug("Par prefill 미적용 (catalog 미등록 또는 형식 불일치) — 모든 홀 par 4 기본값")
        }

        var holeScores: [HoleScore] = []
        for holeNumber in 1...holesCount {
            let par = prefillPars?[holeNumber - 1] ?? 4
            let score = HoleScore(holeNumber: holeNumber, par: par)
            holeScores.append(score)
        }
        round.holes = (round.holes ?? []) + holeScores

        modelContext.insert(round)
        persist("startRound", roundId: round.id)

        AppLogger.round.info("라운드 시작: \(courseName, privacy: .private) \(holesCount)홀 \(players.count)명")

        // par prefill 성공 시 토스트 메시지 세팅 (ActiveRoundView에서 소비)
        if let pp = prefillPars, pp.count == holesCount {
            if backTentative, let tentative = tentativeBackName {
                let frontLabel = frontCourseName.map { "\($0)/" } ?? ""
                lastPrefillToastMessage = "\(frontLabel)\(tentative) par 자동 설정 (후반 잠정)"
            } else if let front = frontCourseName, let back = resolvedBack {
                lastPrefillToastMessage = "\(front)/\(back) par 자동 설정 완료"
            } else if let front = frontCourseName {
                lastPrefillToastMessage = "\(front) par 자동 설정 완료"
            } else {
                lastPrefillToastMessage = "par 자동 설정 완료"
            }
        }

        activate(round: round)

        // B: Watch로 RoundSnapshot 송출 (페어링되어 있으면)
        emitSnapshot()

        // A1: HealthKit 운동 시작 (권한 실패 시에도 라운드는 정상 진행)
        Task {
            await onWorkoutStart?(courseName)
            // 배너 메시지 수신
            if let msg = onWorkoutBannerUpdate?(), !msg.isEmpty {
                bannerMessage = msg
            }
        }
    }

    /// 라운드 종료 — 모든 홀 isLocked = true 후 저장
    public func finishRound() {
        guard let round = currentRound else { return }
        let totalHoles = round.holeList.count
        let roundId = round.id
        // 라운드 종료 시 모든 홀 잠금
        for hole in round.holeList {
            hole.isLocked = true
        }
        round.isFinished = true
        round.finishedAt = .now
        persist("finishRound", roundId: roundId)
        AppLogger.round.info("라운드 종료: \(round.courseName, privacy: .private) \(totalHoles)홀 — 전체 홀 잠금")
        emitRoundEnd(roundId: roundId, reason: .finished)
        deactivate()

        // A1: HealthKit 운동 종료
        Task {
            await onWorkoutEnd?()
        }
    }

    /// 특정 홀 잠금 해제. 잠긴 홀을 수정해야 할 때 UI에서 confirmation 후 호출.
    public func unlockHole(_ holeNumber: Int) {
        guard let round = currentRound else { return }
        guard let hole = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }
        hole.isLocked = false
        save("unlockHole", holeNumber: holeNumber)
        AppLogger.round.info("홀 잠금 해제: \(holeNumber)번 홀")
    }

    /// 카운트 +1. double par (par×2) 이상 또는 잠긴 홀은 차단.
    /// - Returns: 정상 증가 시 true, 차단 시 false (UI에서 warning haptic 트리거용)
    @discardableResult
    public func increment(holeNumber: Int, playerId: UUID) -> Bool {
        guard let round = currentRound else { return false }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return false }

        // 잠긴 홀 차단
        guard !holeScore.isLocked else {
            AppLogger.counter.warning("카운터 차단: 홀\(holeNumber) 잠금 상태")
            return false
        }

        let current = holeScore.count(for: playerId)
        let limit = max(2, holeScore.par * 2)  // double par 도달 시 차단 (par 1이라면 최소 2)
        guard current < limit else {
            AppLogger.counter.warning("카운터 차단: 홀\(holeScore.holeNumber) double par(\(limit)) 초과")
            return false
        }

        upsertCount(in: holeScore, playerId: playerId, delta: 1)
        save("increment", holeNumber: holeNumber)
        scoreCardViewModel?.refresh(from: round)
        emitShot(type: .increment, holeNumber: holeNumber, playerId: playerId)
        return true
    }

    /// 라운드 중 전반/후반 9홀 코스 변경 — CourseParsCatalog에서 par 재prefill.
    /// half: .front (홀 1-9) 또는 .back (홀 10-18)
    public enum Half: String, Sendable { case front, back }

    public func changeSubCourse(half: Half, to newSubCourseName: String) {
        guard let round = currentRound else { return }
        // courseName 필드 업데이트
        switch half {
        case .front: round.frontCourseName = newSubCourseName
        case .back:
            round.backCourseName = newSubCourseName
            // 후반 코스를 수동 변경하면 잠정 상태 해제
            if round.isBackTentative {
                round.isBackTentative = false
                AppLogger.round.info("후반 잠정 상태 해제: 수동 변경 → \(newSubCourseName)")
            }
        }
        // 새 9홀 par 조회 (CourseParsResolver: UserParOverride 우선)
        let pars = CourseParsResolver.pars(courseId: round.courseId, subCourseName: newSubCourseName, context: modelContext)
        if let pars = pars, pars.count == 9 {
            let range = (half == .front) ? (1...9) : (10...18)
            for hole in round.holeList where range.contains(hole.holeNumber) {
                let idx = hole.holeNumber - (half == .front ? 1 : 10)
                if idx < pars.count { hole.par = pars[idx] }
            }
            AppLogger.round.info("코스 변경: \(half.rawValue) → \(newSubCourseName) — par \(pars) 재prefill")
        } else {
            AppLogger.round.warning("코스 변경: \(half.rawValue) → \(newSubCourseName) — par catalog 미매칭, par 유지")
        }
        save("changeSubCourse.\(half.rawValue)")
        scoreCardViewModel?.refresh(from: round)
        emitSnapshot()  // Watch sync
    }

    /// 후반 코스 잠정 확인 — "맞아요"를 선택했을 때 호출.
    /// isBackTentative를 false로 클리어하고 저장 + Watch sync.
    public func confirmBackCourse() {
        guard let round = currentRound else { return }
        round.isBackTentative = false
        save("confirmBackCourse")
        emitSnapshot()
        AppLogger.round.info("후반 잠정 코스 확인됨: \(round.backCourseName ?? "-", privacy: .private)")
    }

    // MARK: - Private helpers

    /// 전반 코스 다음 순번의 서브코스를 자동 배정 (wrap-around).
    /// 예: [A, B, C]에서 front=A이면 → B. front=C이면 → A.
    /// 매칭 실패(front가 nil 또는 목록에 없음)이면 첫 번째 코스 반환.
    private func deriveTentativeBackCourseName(courseId: String, frontCourseName: String?) -> String? {
        let subs = CourseParsCatalog.subCourseNames(for: courseId)
        guard !subs.isEmpty else { return nil }
        guard let front = frontCourseName, let idx = subs.firstIndex(of: front) else {
            return subs.first  // 전반 미지정 또는 매칭 실패 → 첫 코스
        }
        return subs[(idx + 1) % subs.count]  // wrap-around
    }

    /// 홀의 par 변경 (3/4/5만 허용). 변경 시 RoundSnapshot 재전송 + UserParOverride upsert.
    public func setPar(holeNumber: Int, par: Int) {
        guard [3, 4, 5].contains(par) else { return }
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }
        guard holeScore.par != par else { return }
        AppLogger.round.info("Par 변경: 홀\(holeNumber) \(holeScore.par)→\(par)")
        holeScore.par = par
        save("setPar", holeNumber: holeNumber)
        scoreCardViewModel?.refresh(from: round)
        emitSnapshot()  // par 변경은 snapshot으로 전체 동기화

        // UserParOverride upsert — 같은 서브코스의 9홀 par를 취합해 저장
        upsertParOverride(round: round, changedHoleNumber: holeNumber)
    }

    /// 라운드 중 par 변경 시 서브코스 단위(9홀) UserParOverride를 upsert한다.
    /// - 같은 서브코스 내 변경되지 않은 홀은 현재 HoleScore.par 값 유지
    /// - composite key (courseId|subCourseName) 으로 기존 레코드 갱신 또는 신규 insert
    private func upsertParOverride(round: Round, changedHoleNumber: Int) {
        // 서브코스 이름 결정 (홀 번호 기준: 1-9=front, 10-18=back)
        let isBack = changedHoleNumber >= 10
        let subCourseName: String
        if isBack {
            subCourseName = round.backCourseName ?? round.frontCourseName ?? ""
        } else {
            subCourseName = round.frontCourseName ?? ""
        }

        // 9홀 범위 결정
        let range = isBack ? (10...18) : (1...9)
        let holes = round.holeList.filter { range.contains($0.holeNumber) }
            .sorted { $0.holeNumber < $1.holeNumber }
        guard holes.count == 9 else { return }
        let pars = holes.map { $0.par }

        // FetchDescriptor로 기존 레코드 조회 (로컬 변수로 predicate 캡처)
        let courseIdCopy = round.courseId
        let roundId = round.id
        var descriptor = FetchDescriptor<UserParOverride>(
            predicate: #Predicate { $0.courseId == courseIdCopy && $0.subCourseName == subCourseName },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let existing = (try? modelContext.fetch(descriptor))?.first

        if let override = existing {
            override.pars = pars
            override.updatedAt = .now
            override.roundIdLast = roundId
        } else {
            let override = UserParOverride(
                courseId: courseIdCopy,
                subCourseName: subCourseName,
                pars: pars,
                updatedAt: .now,
                roundIdLast: roundId
            )
            modelContext.insert(override)
        }
        persist("upsertParOverride", roundId: roundId, holeNumber: changedHoleNumber)
        AppLogger.persistence.info("UserParOverride upsert: courseId=\(courseIdCopy) sub=\(subCourseName) pars=\(pars)")
    }

    /// 라운드 폐기 (저장 없이 영구 삭제)
    public func discardRound() {
        guard let round = currentRound else { return }
        let roundId = round.id
        AppLogger.round.warning("라운드 폐기: \(round.courseName, privacy: .private)")
        modelContext.delete(round)
        persist("discardRound", roundId: roundId)
        emitRoundEnd(roundId: roundId, reason: .discarded)
        deactivate()
        Task { await onWorkoutEnd?() }
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

    /// 카운트 -1. 골프 룰상 최저는 1타(홀인원)이므로 0 미만은 차단. 잠긴 홀도 차단.
    /// 0 = 미입력 상태(아직 안 침), 1 = 홀인원, 음수 불가.
    public func decrement(holeNumber: Int, playerId: UUID) {
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return }

        // 잠긴 홀 차단
        guard !holeScore.isLocked else {
            AppLogger.counter.warning("카운터 차단: 홀\(holeNumber) 잠금 상태")
            return
        }

        let current = holeScore.count(for: playerId)
        guard current > 0 else { return }  // 음수 금지 — 골프 룰 최저 1타

        upsertCount(in: holeScore, playerId: playerId, delta: -1)
        save("decrement", holeNumber: holeNumber)
        scoreCardViewModel?.refresh(from: round)
        emitShot(type: .decrement, holeNumber: holeNumber, playerId: playerId)
    }

    /// OB 탭 — PenaltySettings.obDelta 만큼 타수 추가 (default +2). double par 초과는 차단.
    /// - Returns: 정상 적용 시 true, double par 초과로 차단 시 false
    @discardableResult
    public func tapOB(holeNumber: Int, playerId: UUID) -> Bool {
        applyPenalty(holeNumber: holeNumber, playerId: playerId, delta: PenaltySettings.obDelta, kind: .ob)
    }

    /// 해저드 탭 — PenaltySettings.hazardDelta 만큼 타수 추가 (default +1).
    @discardableResult
    public func tapHazard(holeNumber: Int, playerId: UUID) -> Bool {
        applyPenalty(holeNumber: holeNumber, playerId: playerId, delta: PenaltySettings.hazardDelta, kind: .hazard)
    }

    /// OK/컨시드 탭 — PenaltySettings.okDelta 만큼 타수 추가 (default +1).
    @discardableResult
    public func tapOK(holeNumber: Int, playerId: UUID) -> Bool {
        applyPenalty(holeNumber: holeNumber, playerId: playerId, delta: PenaltySettings.okDelta, kind: .ok)
    }

    /// 더블파 탭 — 해당 홀의 타수를 par×2로 강제 설정. 잠긴 홀은 차단.
    /// - Returns: 성공 시 true, 라운드/홀 없으면 false
    @discardableResult
    public func setToDoublePar(holeNumber: Int, playerId: UUID) -> Bool {
        guard let round = currentRound else { return false }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return false }
        guard !holeScore.isLocked else {
            AppLogger.counter.warning("더블파 차단: 홀\(holeNumber) 잠금 상태")
            return false
        }
        let target = max(2, holeScore.par * 2)
        let current = holeScore.count(for: playerId)
        let delta = target - current
        if delta != 0 {
            upsertCount(in: holeScore, playerId: playerId, delta: delta)
        }
        save("setToDoublePar", holeNumber: holeNumber)
        scoreCardViewModel?.refresh(from: round)
        emitShot(type: .increment, holeNumber: holeNumber, playerId: playerId)
        AppLogger.counter.info("더블파 설정: 홀\(holeNumber) \(current)→\(target)")
        return true
    }

    private enum PenaltyKind { case ob, hazard, ok }

    private func applyPenalty(holeNumber: Int, playerId: UUID, delta: Int, kind: PenaltyKind) -> Bool {
        guard let round = currentRound else { return false }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == holeNumber }) else { return false }

        // 잠긴 홀 차단
        guard !holeScore.isLocked else {
            AppLogger.counter.warning("벌타 차단: 홀\(holeNumber) 잠금 상태")
            return false
        }

        let current = holeScore.count(for: playerId)
        let limit = max(2, holeScore.par * 2)
        // delta 적용 시 double par 초과면 차단
        guard current + delta <= limit else {
            AppLogger.counter.warning("벌타 차단: 홀\(holeScore.holeNumber) \(current)+\(delta) > \(limit)")
            return false
        }

        switch kind {
        case .ob:     upsertOB(in: holeScore, playerId: playerId, delta: 1)
        case .hazard: upsertHazard(in: holeScore, playerId: playerId, delta: 1)
        case .ok:     break  // OK는 타수만 추가, 별도 카운터 없음
        }
        upsertCount(in: holeScore, playerId: playerId, delta: delta)
        save("penalty.\(kind)", holeNumber: holeNumber)
        scoreCardViewModel?.refresh(from: round)
        let shotType: ShotType = (kind == .ob ? .ob : (kind == .hazard ? .hazard : .ok))
        emitShot(type: shotType, holeNumber: holeNumber, playerId: playerId)
        return true
    }

    // MARK: B — Watch sync 수신 처리 (broadcast 없이 로컬 적용)

    /// 외부 RoundSnapshot 수신 — Watch에서 iPhone의 라운드 시작 미러링.
    /// 동일 roundId 이미 활성 시 par/active 위치만 갱신.
    public func applyRemoteSnapshot(_ snapshot: RoundSnapshot) {
        // 동일 roundId 이미 활성 → par/active만 동기화
        if let round = currentRound, round.id == snapshot.roundId {
            for (idx, par) in snapshot.parArray.enumerated() {
                let holeNumber = idx + 1
                if let hs = round.holeList.first(where: { $0.holeNumber == holeNumber }), hs.par != par {
                    hs.par = par
                }
            }
            if holeViewModel?.currentHoleNumber != snapshot.activeHoleNumber {
                holeViewModel?.goToHole(index: snapshot.activeHoleNumber - 1, silent: true)
            }
            if playerListViewModel?.activePlayerIndex != snapshot.activePlayerIndex {
                if let p = playerListViewModel?.players.first(where: { $0.order == snapshot.activePlayerIndex }) {
                    playerListViewModel?.activate(player: p, silent: true)
                }
            }
            persist("applyRemoteSnapshot.sync", roundId: round.id)
            scoreCardViewModel?.refresh(from: round)
            return
        }

        // 새 라운드 — in-memory Round 생성 후 activate
        let players = snapshot.players
            .sorted { $0.order < $1.order }
            .map { Player(id: $0.id, name: $0.name, isOwner: $0.isOwner, order: $0.order) }
        let round = Round(
            id: snapshot.roundId,
            courseId: snapshot.courseId,
            courseName: snapshot.courseId,  // Watch에서는 courseName 미수신 → courseId fallback
            players: players,
            startedAt: .now
        )
        for (idx, par) in snapshot.parArray.enumerated() {
            let hs = HoleScore(holeNumber: idx + 1, par: par)
            round.holes = (round.holes ?? []) + [hs]
        }
        modelContext.insert(round)
        persist("applyRemoteSnapshot.insert", roundId: round.id)
        activate(round: round)
        if snapshot.activeHoleNumber > 0 {
            holeViewModel?.goToHole(index: snapshot.activeHoleNumber - 1, silent: true)
        }
        if let p = players.first(where: { $0.order == snapshot.activePlayerIndex }) {
            playerListViewModel?.activate(player: p, silent: true)
        }
        AppLogger.round.info("원격 라운드 활성: id=\(snapshot.roundId) (\(players.count)명)")
    }

    /// 외부 ShotEvent 수신 — counts/OB/해저드 미러링. broadcast 안 함.
    public func applyRemoteShot(_ event: ShotEvent) {
        // echo 무시 (자기가 보낸 메시지)
        guard event.deviceId != deviceId else { return }
        guard let round = currentRound else { return }
        guard let holeScore = round.holeList.first(where: { $0.holeNumber == event.holeNumber }) else { return }

        switch event.type {
        case .increment:
            upsertCount(in: holeScore, playerId: event.playerId, delta: 1)
        case .decrement:
            upsertCount(in: holeScore, playerId: event.playerId, delta: -1)
        case .ob:
            upsertOB(in: holeScore, playerId: event.playerId, delta: 1)
            upsertCount(in: holeScore, playerId: event.playerId, delta: 2)
        case .hazard:
            upsertHazard(in: holeScore, playerId: event.playerId, delta: 1)
            upsertCount(in: holeScore, playerId: event.playerId, delta: 1)
        case .ok:
            upsertCount(in: holeScore, playerId: event.playerId, delta: 1)
        }
        save("applyRemoteShot.\(event.type.rawValue)", holeNumber: event.holeNumber)
        scoreCardViewModel?.refresh(from: round)
    }

    /// 외부 HoleChange 수신 — silent로 적용 (echo loop 방지)
    public func applyRemoteHoleChange(_ change: HoleChange) {
        guard change.deviceId != deviceId else { return }
        holeViewModel?.goToHole(index: change.newHoleNumber - 1, silent: true)
    }

    /// 외부 PlayerSwitch 수신 — silent로 적용 (echo loop 방지)
    public func applyRemotePlayerSwitch(_ switchEvent: PlayerSwitch) {
        guard switchEvent.deviceId != deviceId else { return }
        guard let players = playerListViewModel?.players,
              players.indices.contains(switchEvent.newPlayerIndex) else { return }
        playerListViewModel?.activate(player: players[switchEvent.newPlayerIndex], silent: true)
    }

    /// 외부 RoundEnd 수신 — 상대 디바이스에서 종료/폐기 → 로컬도 deactivate.
    /// Watch가 받으면 in-memory Round는 더 이상 의미 없으니 삭제 후 초기 화면으로.
    public func applyRemoteRoundEnd(_ end: RoundEnd) {
        guard end.deviceId != deviceId else { return }
        guard let round = currentRound, round.id == end.roundId else {
            AppLogger.round.debug("RoundEnd 무시 — 활성 라운드 ID 불일치")
            return
        }
        AppLogger.round.info("원격 라운드 종료 수신: reason=\(end.reason.rawValue)")
        // 로컬 데이터 삭제 (Watch는 in-memory mirror라 안전)
        modelContext.delete(round)
        persist("applyRemoteRoundEnd", roundId: end.roundId)
        deactivate()
    }

    // MARK: Private helpers

    private func activate(round: Round) {
        self.currentRound = round

        // 저장된 마지막 홀/플레이어 위치 복원 (clamp: 유효 범위 초과 방어)
        let totalHoles = round.holeList.count
        let holeNumber = max(1, min(round.lastActiveHoleNumber, max(1, totalHoles)))
        let playerCount = round.playerList.count
        let playerIndex = max(0, min(round.lastActivePlayerIndex, max(0, playerCount - 1)))

        // B: 홀 이동 → WC HoleChange 송출 + last* 업데이트
        let holeVM = HoleViewModel(totalHoles: totalHoles, initialHoleNumber: holeNumber)
        holeVM.onHoleChanged = { [weak self] newHoleNumber in
            self?.emitHoleChange(newHoleNumber: newHoleNumber)
        }
        self.holeViewModel = holeVM
        self.scoreCardViewModel = ScoreCardViewModel(round: round)

        // B: 플레이어 전환 → WC PlayerSwitch 송출 + last* 업데이트
        let playerVM = PlayerListViewModel(players: round.playerList, initialIndex: playerIndex)
        playerVM.onActivePlayerChanged = { [weak self] newIndex in
            self?.emitPlayerSwitch(newPlayerIndex: newIndex)
        }
        self.playerListViewModel = playerVM
    }

    private func emitHoleChange(newHoleNumber: Int) {
        // 이전 홀 자동 잠금: 본인(owner) 샷이 1 이상인 홀만 잠금
        if let round = currentRound {
            let prevHoleNumber = newHoleNumber - 1
            // 이전 홀 번호가 유효한 경우(1 이상)에만 잠금 시도
            if prevHoleNumber >= 1,
               let prevHole = round.holeList.first(where: { $0.holeNumber == prevHoleNumber }) {
                // 본인(isOwner) 플레이어 찾기
                let ownerShotCount: Int
                if let owner = round.playerList.first(where: { $0.isOwner }) {
                    ownerShotCount = prevHole.count(for: owner.id)
                } else {
                    // isOwner가 없으면 전체 첫 번째 플레이어
                    ownerShotCount = round.playerList.first.map { prevHole.count(for: $0.id) } ?? 0
                }
                if ownerShotCount > 0 && !prevHole.isLocked {
                    prevHole.isLocked = true
                    AppLogger.round.info("홀 자동 잠금: \(prevHoleNumber)번 홀 (owner \(ownerShotCount)타)")

                    // 멘트 생성 — owner 기준 ScoreDiff
                    if let owner = round.playerList.first(where: { $0.isOwner }) {
                        let diff = ScoreDiff.classify(strokes: ownerShotCount, par: prevHole.par)
                        let message = HoleResultMessage.text(for: diff)
                        lastHoleMessage = message
                        // 3초 후 자동 nil
                        Task { [weak self] in
                            try? await Task.sleep(for: .seconds(3))
                            self?.lastHoleMessage = nil
                        }
                    }
                }
            }

            round.lastActiveHoleNumber = newHoleNumber
            round.lastActiveAt = Date()
            save("holeChange", holeNumber: newHoleNumber)
        }
        guard let broadcast = onBroadcastHole else { return }
        let subLabel: String? = {
            guard let round = currentRound else { return nil }
            return newHoleNumber <= 9 ? round.frontCourseName : round.backCourseName
        }()
        let change = HoleChange(
            newHoleNumber: newHoleNumber,
            trigger: .manualSwipe,
            subCourseName: subLabel,
            deviceId: deviceId,
            perDeviceCounter: nextCounter()
        )
        broadcast(change)
    }

    private func emitPlayerSwitch(newPlayerIndex: Int) {
        // last* 영구 저장 — standby 복귀 시 이 플레이어로 복원
        if let round = currentRound {
            round.lastActivePlayerIndex = newPlayerIndex
            round.lastActiveAt = Date()
            save("playerSwitch")
        }
        guard let broadcast = onBroadcastPlayerSwitch else { return }
        let switchEvent = PlayerSwitch(
            newPlayerIndex: newPlayerIndex,
            deviceId: deviceId,
            perDeviceCounter: nextCounter()
        )
        broadcast(switchEvent)
    }

    private func deactivate() {
        self.currentRound = nil
        self.holeViewModel = nil
        self.scoreCardViewModel = nil
        self.playerListViewModel = nil
    }

    private func save(_ step: String, holeNumber: Int? = nil) {
        // 샷 입력 등 모든 저장 시점에 lastActiveAt 갱신 (정확한 마지막 활동 시각 보존)
        currentRound?.lastActiveAt = Date()
        persist(step, roundId: currentRound?.id, holeNumber: holeNumber)
    }

    /// 모든 SwiftData 저장의 단일 통로. 실패 시 진단 로그 + lastSaveError(사용자 고지) 세팅.
    /// - Parameters:
    ///   - step: 실패 로그에 남길 작업명 (예: "increment", "finishRound")
    ///   - roundId: 실패한 저장이 속한 라운드 (UUID prefix만 기록 — PII 아님)
    ///   - holeNumber: 홀 단위 작업이면 홀 번호
    /// - Returns: 저장 성공 여부
    @discardableResult
    private func persist(_ step: String, roundId: UUID? = nil, holeNumber: Int? = nil) -> Bool {
        do {
            try modelContext.save()
            // 직전 실패 후 복구 성공 → 배너 자동 해제
            if lastSaveError != nil {
                AppLogger.persistence.info("저장 복구됨 [\(step)] — 이전 실패 상태 해제")
                lastSaveError = nil
            }
            return true
        } catch {
            let roundPart = roundId.map { " round=\($0.uuidString.prefix(8))" } ?? ""
            let holePart = holeNumber.map { " hole=\($0)" } ?? ""
            AppLogger.persistence.error("저장 실패 [\(step)]\(roundPart)\(holePart): \(error.localizedDescription)")
            lastSaveError = "기록 저장에 실패했어요. 이어서 입력한 내용이 유실될 수 있어요."
            return false
        }
    }

    private func upsertCount(in holeScore: HoleScore, playerId: UUID, delta: Int) {
        if let idx = holeScore.counts.firstIndex(where: { $0.playerId == playerId }) {
            let before = holeScore.counts[idx].value
            let after = max(0, before + delta)  // 음수 차단 — 골프 룰 최저 1타, 0=미입력
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
