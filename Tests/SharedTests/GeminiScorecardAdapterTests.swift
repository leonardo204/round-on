import XCTest
@testable import Shared

// MARK: - GeminiScorecardAdapterTests
// GeminiScorecardAdapter.adapt / resolveDateText 검증.
// 네트워크 없음 — 완전 결정적.

final class GeminiScorecardAdapterTests: XCTestCase {

    // MARK: - 헬퍼

    private func makeRow(
        label: String,
        kind: String,
        isOwner: Bool? = nil,
        values: [Int],
        out: Int,
        inScore: Int,
        total: Int
    ) -> GeminiRow {
        GeminiRow(label: label, kind: kind, isOwner: isOwner,
                  values: values, out: out, inScore: inScore, total: total)
    }

    private func makeCard(courseName: String = "테스트CC",
                          date: String = "2026-05-01",
                          rows: [GeminiRow]) -> GeminiScorecard {
        GeminiScorecard(courseName: courseName, date: date, rows: rows)
    }

    // MARK: - B1. 가로카드(par행 있음) → 홀별 over-par delta 저장
    // ★ ScoreValue.intValue = over-par delta (절대타수 아님).
    //   실타수(par+delta)는 ScorecardMapper.makeRound 단계에서 par+intValue로 계산된다.
    //   어댑터가 par+delta(절대값)를 저장하면 이중 변환되어 저장 타수가 틀린다.

    func test_adapt_withParRow_holeStoresOverParDelta() {
        // hole1: par=4, delta=1 → 저장 delta=1
        // hole2: par=5, delta=2 → 저장 delta=2
        let parValues: [Int] = [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5]
        let ownerDeltas: [Int] = [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4]

        let parRow = makeRow(label: "PAR", kind: "par",
                             values: parValues, out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: ownerDeltas, out: 54, inScore: 60, total: 114)
        let card = makeCard(courseName: "진양밸리CC", date: "2026-04-30",
                            rows: [parRow, ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        // 전반 테이블 존재
        XCTAssertGreaterThanOrEqual(scorecard.tables.count, 1, "테이블이 최소 1개 있어야 함")
        let frontTable = scorecard.tables[0]

        // 전반 테이블에 par행 + player행 존재
        let parScoreRow = frontTable.rows.first { $0.kind == .par }
        let ownerScoreRow = frontTable.rows.first { $0.kind == .player }
        XCTAssertNotNil(parScoreRow, "par ScoreRow가 없음")
        XCTAssertNotNil(ownerScoreRow, "owner ScoreRow가 없음")

        // 홀별 저장값 검산: ScoreValue.intValue = over-par delta (절대타수 아님)
        // ScoreRow.values: [hole1, ..., hole9, subtotal]
        guard let ownerValues = ownerScoreRow?.values else {
            XCTFail("owner ScoreRow values가 nil")
            return
        }

        if ownerValues.count > 0 {
            let hole1 = ownerValues[0]?.intValue
            XCTAssertEqual(hole1, 1, "홀1 over-par delta=1 기대, 실제=\(String(describing: hole1))")
        }
        if ownerValues.count > 1 {
            let hole2 = ownerValues[1]?.intValue
            XCTAssertEqual(hole2, 2, "홀2 over-par delta=2 기대, 실제=\(String(describing: hole2))")
        }
    }

    // MARK: - B2. owner 행이 player 행으로, 동반자도 player로 분리됨

    func test_adapt_withParRow_ownerAndCompanionsBothPresent() {
        let parValues: [Int] = [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5]
        let ownerDeltas: [Int] = [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4]
        let companionDeltas: [Int] = [0,2,1,1,2,1,0,1,1, 1,0,0,0,2,0,2,3,3]

        let parRow = makeRow(label: "PAR", kind: "par",
                             values: parValues, out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: ownerDeltas, out: 54, inScore: 60, total: 114)
        let companionRow = makeRow(label: "문**", kind: "player", isOwner: false,
                                   values: companionDeltas, out: 45, inScore: 47, total: 92)
        let card = makeCard(rows: [parRow, ownerRow, companionRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        let frontTable = scorecard.tables[0]
        let playerRows = frontTable.rows.filter { $0.kind == .player }

        // owner + companion 모두 player 행으로 포함
        XCTAssertEqual(playerRows.count, 2, "player ScoreRow가 2개여야 함 (owner + 동반자)")

        // label 확인
        let labels = playerRows.map { $0.label }
        XCTAssertTrue(labels.contains("이용섭"), "owner '이용섭'이 player 행에 없음")
        XCTAssertTrue(labels.contains("문**"), "동반자 '문**'이 player 행에 없음")
    }

    // MARK: - B3. 전반/후반 테이블 2개 생성

    func test_adapt_withParRow18_creates2Tables() {
        let parValues: [Int] = [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5]
        let ownerDeltas: [Int] = [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4]
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: parValues, out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: ownerDeltas, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [parRow, ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        XCTAssertEqual(scorecard.tables.count, 2, "18홀 par행 있으면 전반+후반 2개 테이블")
        XCTAssertEqual(scorecard.tables[0].sectionName, "전반")
        XCTAssertEqual(scorecard.tables[1].sectionName, "후반")
    }

    // MARK: - B4. 앱스샷(par행 없음) → 합계만 있는 단순 Scorecard

    func test_adapt_withoutParRow_summaryOnlyScorecard() {
        // IMG_1351: par행 없음, inScore=51(0 아님) → 18홀 앱스샷
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: [2,0,4,4,1,2,3,1,2, 2,1,2,3,0,1,4,0,2],
                               out: 55, inScore: 51, total: 106)
        let card = makeCard(courseName: "아리지CC", date: "2026-05-25",
                            rows: [ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        // 앱스샷은 전반/후반 2개 테이블 (par 없을 때 is9hole=false 경로)
        XCTAssertGreaterThanOrEqual(scorecard.tables.count, 1, "테이블이 없음")

        let frontTable = scorecard.tables[0]
        // 홀별 컬럼이 없고 합계 컬럼만 있어야 함
        let holeColumns = frontTable.columns.filter { $0.kind == .hole }
        XCTAssertEqual(holeColumns.count, 0, "앱스샷에는 hole 컬럼이 없어야 함")

        let subtotalColumns = frontTable.columns.filter { $0.kind == .subtotal }
        XCTAssertGreaterThanOrEqual(subtotalColumns.count, 1, "subtotal 컬럼이 있어야 함")
    }

    // MARK: - B5. 앱스샷: par행 없이 inScore==0 + values.count<=9 → 테이블 2개 (18홀 가정)
    // 수정된 is9hole 기준: par행 없으면 18홀로 가정한다.
    // 이유: IMG_1358 back9 누락(inScore=0, values=9)과 실제 9홀 앱스샷이 동일하게 보이므로
    //       par행 없는 상태에서 9홀로 강등하지 않는다.
    //       실제 9홀 라운드는 par행 9개로 buildTablesWithPar 경로를 타야 한다.

    func test_adapt_noParRow_inScoreZero_creates2Tables_18holeDefault() {
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: [0,3,3,2,1,3,2,3,3], out: 56, inScore: 0, total: 56)
        let card = makeCard(rows: [ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        // par행 없으면 18홀 가정 → 전반/후반 2개 테이블
        XCTAssertEqual(scorecard.tables.count, 2,
            "par행 없으면 18홀 가정 → 전반+후반 2개 테이블 (IMG_1358 back9 누락 보호)")
    }

    // MARK: - B5b. 실제 9홀 라운드: par행 9개 → 테이블 1개

    func test_adapt_9hole_withParRow_creates1Table() {
        let par9 = [4,4,3,3,5,4,4,4,5]
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: par9, out: 36, inScore: 0, total: 36)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: [1,1,2,1,0,1,1,2,1], out: 43, inScore: 0, total: 43)
        let card = makeCard(rows: [parRow, ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        // par행 9개 → buildTablesWithPar → 1섹션만 생성
        XCTAssertEqual(scorecard.tables.count, 1, "par행 9개인 실제 9홀 라운드는 테이블 1개")
    }

    // MARK: - B6. courseName, dateText 매핑

    func test_adapt_courseNameAndDateMapped() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: [4,4,3,3,5,4,4,4,5, 4,4,4,5,3,4,3,5,4],
                             out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: Array(repeating: 0, count: 18), out: 36, inScore: 36, total: 72)
        let card = makeCard(courseName: "벨라45CC", date: "2026-04-18",
                            rows: [parRow, ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        XCTAssertEqual(scorecard.clubName, "벨라45CC")
        // resolveDateText: "2026-04-18" → "2026/04/18"
        XCTAssertEqual(scorecard.dateText, "2026/04/18")
    }

    // MARK: - B7. 날짜 정규화: "2026.05.25" → "2026/05/25"

    func test_resolveDateText_dotSeparated_normalized() {
        let result = GeminiScorecardAdapter.resolveDateText("2026.05.25", imageData: nil)
        XCTAssertEqual(result, "2026/05/25")
    }

    // MARK: - B8. 날짜 정규화: "2026/05/25" → "2026/05/25"

    func test_resolveDateText_slashSeparated_normalized() {
        let result = GeminiScorecardAdapter.resolveDateText("2026/05/25", imageData: nil)
        XCTAssertEqual(result, "2026/05/25")
    }

    // MARK: - B9. 날짜 정규화: "2026-04-30" → "2026/04/30"

    func test_resolveDateText_dashSeparated_normalized() {
        let result = GeminiScorecardAdapter.resolveDateText("2026-04-30", imageData: nil)
        XCTAssertEqual(result, "2026/04/30")
    }

    // MARK: - B10. 날짜 파싱 실패 + imageData nil → nil 반환

    func test_resolveDateText_invalidFormat_returnsNil() {
        let result = GeminiScorecardAdapter.resolveDateText("invalid-date", imageData: nil)
        XCTAssertNil(result)
    }

    // MARK: - B11. 후반 소계가 inScore로 올바르게 설정

    func test_adapt_backSection_subtotalEqualsInScore() {
        let parValues: [Int] = [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5]
        let ownerDeltas: [Int] = [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4]

        let parRow = makeRow(label: "PAR", kind: "par",
                             values: parValues, out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: ownerDeltas, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [parRow, ownerRow])

        let scorecard = GeminiScorecardAdapter.adapt(card)

        XCTAssertEqual(scorecard.tables.count, 2, "전반+후반 2개 테이블")
        let backTable = scorecard.tables[1]

        let ownerBackRow = backTable.rows.first { $0.kind == .player }
        XCTAssertNotNil(ownerBackRow)

        // 마지막 value = 소계 = inScore = 60
        let lastValue = ownerBackRow?.values.last??.intValue
        XCTAssertEqual(lastValue, 60, "후반 소계가 inScore(60)와 일치해야 함, 실제=\(String(describing: lastValue))")
    }
}
