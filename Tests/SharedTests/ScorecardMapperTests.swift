import XCTest
@testable import Shared

// NOTE: ScorecardMapper.swift는 project.yml에서 SharedTests 타겟 소스로 포함되므로
// 로직을 재현하지 않고 실제 ScorecardMapper.makeDraft / absoluteStrokes를 직접 호출해 검증한다.

// MARK: - ScorecardMapperTests
// PAR 대비 상대값 → 절대 타수 변환 로직 + OCR 파이프라인 연동 테스트

final class ScorecardMapperTests: XCTestCase {

    // MARK: absoluteStrokes 계산 단위 테스트

    func test_absoluteStrokes_par3_relative1_returns4() {
        // PAR 3 홀에서 상대값 +1이면 절대 타수 4
        let result = ScorecardMapper.absoluteStrokes(par: 3, relative: 1)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par4_relative0_returns4() {
        // PAR 4 홀에서 상대값 0이면 절대 타수 4 (파)
        let result = ScorecardMapper.absoluteStrokes(par: 4, relative: 0)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par5_relativeMinus1_returns4() {
        // PAR 5 홀에서 상대값 -1이면 절대 타수 4 (버디)
        let result = ScorecardMapper.absoluteStrokes(par: 5, relative: -1)
        XCTAssertEqual(result, 4)
    }

    func test_absoluteStrokes_par4_relative2_returns6() {
        // PAR 4 홀에서 상대값 +2이면 절대 타수 6 (더블 보기)
        let result = ScorecardMapper.absoluteStrokes(par: 4, relative: 2)
        XCTAssertEqual(result, 6)
    }

    // MARK: OCR + Mapper 통합 테스트 (IMG_1335.PNG)
    // NOTE: Vision OCR은 시뮬레이터에서 CoreML 홈 디렉토리 제약으로 크래시 가능.
    // 단위 테스트 환경에서는 Skip 처리. 실기기 또는 macOS 환경에서 CLI로 검증.

    func test_ocrPipeline_IMG1335_extractsTablesWithoutCrash() throws {
        throw XCTSkip("Vision OCR은 시뮬레이터 CoreML 제약으로 크래시 가능 — 실기기/macOS 검증 권장")
    }

    func test_ocrPipeline_IMG1335_playerRowsExistOrEmpty() throws {
        throw XCTSkip("Vision OCR은 시뮬레이터 CoreML 제약으로 크래시 가능 — 실기기/macOS 검증 권장")
    }

    // MARK: 동성 마스킹 동반자 (실측 버그)
    // 골프장이 카드에 인쇄한 마스킹 라벨은 동성이면 문자열이 완전히 같다("이**").
    // label만으로 join하면 같은 섹션의 서로 다른 사람이 덮어써진다.

    func test_makeDraft_sameSurnameInOneSection_keepsAllPlayers() throws {
        // [이**, 김**, 이**, 정**] — 두 번째 "이**"가 첫 번째를 덮어쓰면 3명이 된다.
        let table = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: [
                ("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0]),
                ("김**", [1, 1, 1, 1, 1, 1, 1, 1, 1]),
                ("이**", [-1, -1, -1, -1, -1, -1, -1, -1, -1]),
                ("정**", [2, 2, 2, 2, 2, 2, 2, 2, 2])
            ]
        )
        let draft = try ScorecardMapper.makeDraft(from: Scorecard(tables: [table]))

        XCTAssertEqual(draft.players.count, 4, "동성 마스킹 라벨이어도 4명 모두 개별 선수로 보존되어야 함")
        XCTAssertEqual(
            draft.players.map(\.rawLabel),
            ["이**", "김**", "이**", "정**"],
            "카드 등장 순서가 그대로 보존되어야 함"
        )

        let sectionId = draft.sections[0].id
        XCTAssertEqual(draft.players[0].scores[sectionId] ?? [], relative([0, 0, 0, 0, 0, 0, 0, 0, 0]),
                       "첫 번째 이**는 자기 점수를 유지해야 함")
        XCTAssertEqual(draft.players[2].scores[sectionId] ?? [], relative([-1, -1, -1, -1, -1, -1, -1, -1, -1]),
                       "두 번째 이**는 자기 점수를 가져야 함 (세 번째 사람 점수가 들어오면 안 됨)")
        XCTAssertEqual(draft.players[3].scores[sectionId] ?? [], relative([2, 2, 2, 2, 2, 2, 2, 2, 2]),
                       "정**의 점수가 앞 선수로 밀려 들어가면 안 됨")
    }

    func test_makeDraft_sameSurnameAcrossSections_joinsByAppearanceOrder() throws {
        // 전반/후반 두 테이블에 같은 4명 — 등장 순번대로 join되어 4명이어야 한다.
        let out = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: [
                ("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0]),
                ("이**", [1, 1, 1, 1, 1, 1, 1, 1, 1])
            ]
        )
        let backIn = makeTable(
            sectionName: "IN",
            pars: [4, 5, 3, 4, 4, 4, 3, 5, 4],
            players: [
                ("이**", [2, 2, 2, 2, 2, 2, 2, 2, 2]),
                ("이**", [3, 3, 3, 3, 3, 3, 3, 3, 3])
            ]
        )
        let draft = try ScorecardMapper.makeDraft(from: Scorecard(tables: [out, backIn]))

        XCTAssertEqual(draft.players.count, 2, "전반/후반은 등장 순번대로 join되어 2명이어야 함")
        let front = draft.sections[0].id
        let back = draft.sections[1].id
        XCTAssertEqual(draft.players[0].scores[front] ?? [], relative([0, 0, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(draft.players[0].scores[back] ?? [], relative([2, 2, 2, 2, 2, 2, 2, 2, 2]),
                       "첫 번째 이**의 후반은 후반 테이블 첫 행이어야 함")
        XCTAssertEqual(draft.players[1].scores[front] ?? [], relative([1, 1, 1, 1, 1, 1, 1, 1, 1]))
        XCTAssertEqual(draft.players[1].scores[back] ?? [], relative([3, 3, 3, 3, 3, 3, 3, 3, 3]),
                       "두 번째 이**의 후반은 후반 테이블 둘째 행이어야 함")
    }

    func test_makeDraft_sameSurnameMatchesOwnerName_exactlyOneOwner() throws {
        // ownerName "이영섭" → 마스킹 라벨은 첫 글자로 매칭되므로 "이**" 2명 모두 매칭 후보다.
        // 라벨 비교로 owner를 정하면 2명이 owner가 된다 → 인덱스로 특정해야 한다.
        let table = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: [
                ("김**", [0, 0, 0, 0, 0, 0, 0, 0, 0]),
                ("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0]),
                ("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0])
            ]
        )
        let draft = try ScorecardMapper.makeDraft(from: Scorecard(tables: [table]), ownerName: "이영섭")

        XCTAssertEqual(draft.players.filter(\.isOwner).count, 1, "동성 마스킹이어도 owner는 정확히 1명이어야 함")
        XCTAssertTrue(draft.players[1].isOwner, "먼저 매칭된 이**(인덱스 1)가 owner여야 함")
    }

    // MARK: Vision 폴백 안전성
    // Vision 폴백은 행 순서/개수 보장이 약하다 — 섹션 간 행 수가 달라도 오배정/크래시가 없어야 한다.

    func test_makeDraft_visionFallback_missingBackRow_doesNotMisassignScores() throws {
        // 후반에서 두 번째 "이**" 행이 누락된 경우
        let out = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: [
                ("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0]),
                ("김**", [1, 1, 1, 1, 1, 1, 1, 1, 1]),
                ("이**", [2, 2, 2, 2, 2, 2, 2, 2, 2])
            ]
        )
        let backIn = makeTable(
            sectionName: "IN",
            pars: [4, 5, 3, 4, 4, 4, 3, 5, 4],
            players: [
                ("이**", [3, 3, 3, 3, 3, 3, 3, 3, 3]),
                ("김**", [4, 4, 4, 4, 4, 4, 4, 4, 4])
            ]
        )
        let draft = try ScorecardMapper.makeDraft(from: Scorecard(tables: [out, backIn]))

        XCTAssertEqual(draft.players.count, 3, "후반 행이 누락돼도 전반 기준 3명이 유지되어야 함")
        let back = draft.sections[1].id
        XCTAssertEqual(draft.players[0].scores[back] ?? [], relative([3, 3, 3, 3, 3, 3, 3, 3, 3]),
                       "후반 첫 이** 행은 첫 번째 이**에게 배정되어야 함")
        XCTAssertNil(draft.players[2].scores[back],
                     "후반 행이 없는 두 번째 이**는 후반 점수가 비어야 함 (다른 사람 점수가 들어오면 안 됨)")
        XCTAssertEqual(draft.players[1].scores[back] ?? [], relative([4, 4, 4, 4, 4, 4, 4, 4, 4]))
    }

    func test_makeDraft_visionFallback_extraBackRow_appendsInsteadOfOverwriting() throws {
        // 후반에 "이**"가 전반보다 1명 더 인식된 경우 — 덮어쓰지 않고 별도 엔트리로 노출(사용자가 리뷰에서 수정)
        let out = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: [("이**", [0, 0, 0, 0, 0, 0, 0, 0, 0])]
        )
        let backIn = makeTable(
            sectionName: "IN",
            pars: [4, 5, 3, 4, 4, 4, 3, 5, 4],
            players: [
                ("이**", [1, 1, 1, 1, 1, 1, 1, 1, 1]),
                ("이**", [2, 2, 2, 2, 2, 2, 2, 2, 2])
            ]
        )
        let draft = try ScorecardMapper.makeDraft(from: Scorecard(tables: [out, backIn]))

        XCTAssertEqual(draft.players.count, 2, "후반 잉여 행은 덮어쓰지 않고 별도 선수로 추가되어야 함")
        let front = draft.sections[0].id
        let back = draft.sections[1].id
        XCTAssertEqual(draft.players[0].scores[front] ?? [], relative([0, 0, 0, 0, 0, 0, 0, 0, 0]),
                       "전반 점수가 후반 잉여 행에 덮어써지면 안 됨")
        XCTAssertEqual(draft.players[0].scores[back] ?? [], relative([1, 1, 1, 1, 1, 1, 1, 1, 1]))
        XCTAssertNil(draft.players[1].scores[front], "잉여 엔트리는 전반이 비어야 함")
        XCTAssertEqual(draft.players[1].scores[back] ?? [], relative([2, 2, 2, 2, 2, 2, 2, 2, 2]))
    }

    // MARK: Owner 결정성 테스트 (S2)

    func test_ownerSelection_noOwnerName_firstEntryIsOwner() throws {
        // OCR 등장 순서: ["나**", "박**", "김**"] — Dictionary 정렬 시 "김"이 첫 번째가 될 수 있음.
        // 올바른 동작: 등장 순서 첫 번째("나**")가 owner가 되어야 함.
        let draft = try makeDraft(labels: ["나**", "박**", "김**"], ownerName: nil)
        XCTAssertEqual(draft.players.first(where: \.isOwner)?.rawLabel, "나**",
                       "ownerName 없을 때 첫 번째 등장 라벨이 owner여야 함 (사전순 X)")
    }

    func test_ownerSelection_withOwnerName_matchesByPrefix() throws {
        // 마스킹 라벨("박**")은 ownerName 첫 글자("박")만으로 매칭
        let draft = try makeDraft(labels: ["나**", "박**", "김**"], ownerName: "박진우")
        XCTAssertEqual(draft.players.first(where: \.isOwner)?.rawLabel, "박**",
                       "마스킹 라벨은 ownerName 첫 글자('박')로 prefix 매칭되어야 함")
    }

    func test_ownerSelection_withExactOwnerName_matchesExact() throws {
        let draft = try makeDraft(labels: ["나**", "박진우", "김**"], ownerName: "박진우")
        XCTAssertEqual(draft.players.first(where: \.isOwner)?.rawLabel, "박진우",
                       "정확 일치하는 라벨이 owner여야 함")
    }

    func test_ownerSelection_noMatch_fallbackToFirst() throws {
        // ownerName이 전혀 일치하지 않으면 첫 번째로 fallback
        let draft = try makeDraft(labels: ["나**", "박**", "김**"], ownerName: "홍길동")
        XCTAssertEqual(draft.players.first(where: \.isOwner)?.rawLabel, "나**",
                       "매칭 없을 때 첫 번째 entry로 fallback되어야 함")
    }

    // MARK: Private helpers

    /// Int 배열 → [Int?] (makeDraft 결과 비교용)
    private func relative(_ values: [Int]) -> [Int?] {
        values.map { Optional($0) }
    }

    /// PAR 행 + 선수 행으로 구성된 ScoreTable 생성
    private func makeTable(
        sectionName: String,
        pars: [Int],
        players: [(label: String, values: [Int])]
    ) -> ScoreTable {
        var rows: [ScoreRow] = [
            ScoreRow(
                label: "PAR",
                kind: .par,
                values: pars.map { ScoreValue(raw: "\($0)", intValue: $0) }
            )
        ]
        for player in players {
            rows.append(
                ScoreRow(
                    label: player.label,
                    kind: .player,
                    values: player.values.map { ScoreValue(raw: "\($0)", intValue: $0) }
                )
            )
        }
        return ScoreTable(sectionName: sectionName, columns: [], rows: rows)
    }

    /// 라벨만 주어 owner 선택을 검증하기 위한 단일 섹션 드래프트 생성
    private func makeDraft(labels: [String], ownerName: String?) throws -> ScorecardImportDraft {
        let table = makeTable(
            sectionName: "OUT",
            pars: [4, 4, 3, 5, 4, 4, 3, 5, 4],
            players: labels.map { ($0, [0, 0, 0, 0, 0, 0, 0, 0, 0]) }
        )
        return try ScorecardMapper.makeDraft(from: Scorecard(tables: [table]), ownerName: ownerName)
    }
}
