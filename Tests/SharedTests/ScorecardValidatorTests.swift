import XCTest
@testable import Shared

// MARK: - ScorecardValidatorTests
// ScorecardValidator.check / inferHoleCount 검증.
// 네트워크 없음 — 완전 결정적.

final class ScorecardValidatorTests: XCTestCase {

    // MARK: - 헬퍼: GeminiScorecard / GeminiRow 생성

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

    // MARK: - 표준 픽스처 (IMG_1335 기반)
    // par: [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5], 합=72
    // owner: values 18개, out=54 in=60 total=114

    private var standard18HolePar: [Int] {
        [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5]
    }

    private var standard18HoleOwnerValues: [Int] {
        [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4]
    }

    // 전반 delta합 = 1+2+3+3+2+2+1+4+0 = 18, par합=36 → 실타수=54(==out) ✓
    // 후반 delta합 = 3+1+3+4+2+3+2+2+4 = 24, par합=36 → 실타수=60(==inScore) ✓

    // MARK: - A1a. IMG_1358 back9 누락 → throw (★ §4 핵심 방어)
    // IMG_1358 정답은 18홀(out=56,in=50,total=106)인데 Gemini가 깨질 때
    // back9를 누락해 values.count=9, inScore=0, total=56으로 떨어진다.
    // out+inScore==total(56+0=56)을 거짓 통과하므로 합계검증만으로는 못 잡는다.
    // par행 없는 앱스샷에서 inferHoleCount는 requested(18)를 신뢰하므로
    // values.count(9) != 18 에서 throw → 재시도 트리거.

    func test_check_IMG1358_back9Missing_throws() throws {
        let playerRow = makeRow(
            label: "이용섭",
            kind: "player",
            isOwner: true,
            values: [0,3,3,2,1,3,2,3,3],  // back9 누락: 9개만
            out: 56,
            inScore: 0,
            total: 56
        )
        let card = makeCard(rows: [playerRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18),
            "IMG_1358 back9 누락(values=9, in=0)은 18홀 요청에서 값 개수 불일치로 throw 되어야 함") { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A1b. back9 누락을 직접 잡는 케이스: inScore가 0이 아닌 경우
    // inScore > 0이면 18홀 카드인데 values=9개 → values.count 검증에서 throw

    func test_check_back9Missing_inScoreNonZero_throws() {
        // inScore=50(0 아님)인데 values=9개: 18홀 카드임이 명확한 케이스
        // inferHoleCount: values.count=9, allInZero=false → mode=9 반환 (구현 한계)
        // 그러나 9홀 검증: out != total → throw
        let badPlayer = makeRow(
            label: "이용섭",
            kind: "player",
            isOwner: true,
            values: [0,3,3,2,1,3,2,3,3],  // 9개
            out: 56,
            inScore: 50,
            total: 106
        )
        let card = makeCard(rows: [badPlayer])

        // 9홀로 추론 → 9홀 검증: out(56) != total(106) → throw
        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A2. 정상 18홀 player 행이 통과

    func test_check_valid18HoleCard_passes() throws {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: standard18HoleOwnerValues, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [parRow, ownerRow])
        XCTAssertNoThrow(try ScorecardValidator.check(card, holeCount: 18))
    }

    // MARK: - A3. out + inScore != total → throw

    func test_check_outPlusInScoreNotEqualTotal_throws() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        // total을 의도적으로 1 높게 설정
        let badRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                             values: standard18HoleOwnerValues, out: 54, inScore: 60, total: 115)
        let card = makeCard(rows: [parRow, badRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A4. par행에 2 또는 6이 섞이면 throw

    func test_check_parValueOutOfRange_2_throws() {
        // 첫 홀 par를 2로 설정 — 현실에서 있을 수 없는 값
        var badPar = standard18HolePar
        badPar[0] = 2
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: badPar, out: 34, inScore: 36, total: 70)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: standard18HoleOwnerValues, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [parRow, ownerRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    func test_check_parValueOutOfRange_6_throws() {
        var badPar = standard18HolePar
        badPar[0] = 6
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: badPar, out: 38, inScore: 36, total: 74)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: standard18HoleOwnerValues, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [parRow, ownerRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A5. 현실성: total 200 → throw (parTotal=72, maxTotal=72+90=162)

    func test_check_totalTooHigh_throws() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        // total=200 은 parTotal+90=162 초과
        let values18 = Array(repeating: 5, count: 18)  // 각 홀 +5
        let badRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                             values: values18, out: 81, inScore: 119, total: 200)
        let card = makeCard(rows: [parRow, badRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A6. inferHoleCount: par행 18개 → 18 반환

    func test_inferHoleCount_withParRow18_returns18() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        let card = makeCard(rows: [parRow])
        let result = ScorecardValidator.inferHoleCount(from: card, requested: 18)
        XCTAssertEqual(result, 18)
    }

    // MARK: - A6. inferHoleCount: par행 9개 → 9 반환

    func test_inferHoleCount_withParRow9_returns9() {
        let par9 = [4,4,3,3,5,4,4,4,5]
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: par9, out: 36, inScore: 0, total: 36)
        let card = makeCard(rows: [parRow])
        let result = ScorecardValidator.inferHoleCount(from: card, requested: 18)
        XCTAssertEqual(result, 9)
    }

    // MARK: - A6. inferHoleCount: par행 없고 9개 values + inScore==0 → requested(18) 신뢰
    // IMG_1358 시그니처(back9 누락)를 9홀로 강등하지 않는다. par행 없으면 requested를 신뢰.

    func test_inferHoleCount_noParRow_playerValues9_inScoreZero_returnsRequested() {
        let player = makeRow(label: "이용섭", kind: "player", isOwner: true,
                             values: [0,3,3,2,1,3,2,3,3], out: 56, inScore: 0, total: 56)
        let card = makeCard(rows: [player])
        let result = ScorecardValidator.inferHoleCount(from: card, requested: 18)
        XCTAssertEqual(result, 18, "par행 없으면 back9 누락 시그니처를 9홀로 강등하지 않고 requested를 신뢰")
    }

    // MARK: - A6. inferHoleCount: par행 없고 player values 18개 → 18 반환

    func test_inferHoleCount_noParRow_playerValues18_returns18() {
        let player = makeRow(label: "이용섭", kind: "player", isOwner: true,
                             values: standard18HoleOwnerValues, out: 54, inScore: 60, total: 114)
        let card = makeCard(rows: [player])
        let result = ScorecardValidator.inferHoleCount(from: card, requested: 18)
        XCTAssertEqual(result, 18)
    }

    // MARK: - A7. player가 없으면 throw

    func test_check_noPlayerRows_throws() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        let card = makeCard(rows: [parRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A8. 9홀 카드: out==total 정상 케이스 통과

    func test_check_valid9HoleCard_passes() throws {
        let par9 = [4,4,3,3,5,4,4,4,5]
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: par9, out: 36, inScore: 0, total: 36)
        let player = makeRow(label: "이용섭", kind: "player", isOwner: true,
                             values: [1,1,2,1,0,1,1,2,1], out: 43, inScore: 0, total: 43)
        let card = makeCard(rows: [parRow, player])
        XCTAssertNoThrow(try ScorecardValidator.check(card, holeCount: 9))
    }

    // MARK: - A9. over-par 불일치 (허용 오차 ±1 초과) → throw

    func test_check_overParInconsistency_throwsWhenExceedsTolerance() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        // 전반 delta합 = 18이어서 par합 36 + 18 = 54 = out ✓
        // 후반 delta합 = 24, par합 36 → 실타수=60 이지만 inScore를 65로 조작 (오차 5)
        let ownerRow = makeRow(label: "이용섭", kind: "player", isOwner: true,
                               values: standard18HoleOwnerValues, out: 54, inScore: 65, total: 119)
        let card = makeCard(rows: [parRow, ownerRow])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18)) { error in
            guard case OCRError.validationFailed(_) = error else {
                XCTFail("OCRError.validationFailed이 아님: \(error)")
                return
            }
        }
    }

    // MARK: - A10. 다중 player 중 한 명만 불량 → throw

    func test_check_multiPlayer_oneInvalid_throws() {
        let parRow = makeRow(label: "PAR", kind: "par",
                             values: standard18HolePar, out: 36, inScore: 36, total: 72)
        let validPlayer = makeRow(label: "문**", kind: "player",
                                  values: Array(repeating: 0, count: 18), out: 36, inScore: 36, total: 72)
        // back9 누락
        let badPlayer = makeRow(label: "이**", kind: "player",
                                values: [0,1,2,1,0,0,1,0,0], out: 41, inScore: 0, total: 41)
        let card = makeCard(rows: [parRow, validPlayer, badPlayer])

        XCTAssertThrowsError(try ScorecardValidator.check(card, holeCount: 18))
    }
}
