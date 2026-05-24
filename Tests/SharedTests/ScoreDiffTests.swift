import XCTest
@testable import Shared

// MARK: - ScoreDiffTests
// ScoreDiff.classify(diff:) 및 classify(strokes:par:) 단위 테스트
// 4단계 통합 (birdie≤-1 / par / bogey+1 / double≥+2)

final class ScoreDiffTests: XCTestCase {

    // MARK: classify(diff:) — 경계값 테스트

    func test_classifyDiff_minus4_returnsBirdie() {
        XCTAssertEqual(ScoreDiff.classify(diff: -4), .birdie)
    }

    func test_classifyDiff_minus3_returnsBirdie() {
        XCTAssertEqual(ScoreDiff.classify(diff: -3), .birdie)
    }

    func test_classifyDiff_minus2_returnsBirdie() {
        XCTAssertEqual(ScoreDiff.classify(diff: -2), .birdie)
    }

    func test_classifyDiff_minus1_returnsBirdie() {
        XCTAssertEqual(ScoreDiff.classify(diff: -1), .birdie)
    }

    func test_classifyDiff_zero_returnsPar() {
        XCTAssertEqual(ScoreDiff.classify(diff: 0), .par)
    }

    func test_classifyDiff_plus1_returnsBogey() {
        XCTAssertEqual(ScoreDiff.classify(diff: 1), .bogey)
    }

    func test_classifyDiff_plus2_returnsDouble() {
        XCTAssertEqual(ScoreDiff.classify(diff: 2), .double)
    }

    func test_classifyDiff_plus3_returnsDouble() {
        XCTAssertEqual(ScoreDiff.classify(diff: 3), .double)
    }

    func test_classifyDiff_plus5_returnsDouble() {
        XCTAssertEqual(ScoreDiff.classify(diff: 5), .double)
    }

    // MARK: classify(strokes:par:) — 4단계 통합 검증

    func test_classifyStrokes_holeinOne_par4_returnsBirdie() {
        // HIO: diff=-3 → birdie
        XCTAssertEqual(ScoreDiff.classify(strokes: 1, par: 4), .birdie)
    }

    func test_classifyStrokes_eagle_par5_returnsBirdie() {
        // Eagle: diff=-2 → birdie
        XCTAssertEqual(ScoreDiff.classify(strokes: 3, par: 5), .birdie)
    }

    func test_classifyStrokes_birdie_par4_returnsBirdie() {
        XCTAssertEqual(ScoreDiff.classify(strokes: 3, par: 4), .birdie)
    }

    func test_classifyStrokes_par_par4_returnsPar() {
        XCTAssertEqual(ScoreDiff.classify(strokes: 4, par: 4), .par)
    }

    func test_classifyStrokes_bogey_par4_returnsBogey() {
        XCTAssertEqual(ScoreDiff.classify(strokes: 5, par: 4), .bogey)
    }

    func test_classifyStrokes_double_par4_returnsDouble() {
        // DoubleBogey: diff=+2 → double
        XCTAssertEqual(ScoreDiff.classify(strokes: 6, par: 4), .double)
    }

    func test_classifyStrokes_triple_par4_returnsDouble() {
        // Triple+: diff=+3 → double (4단계에서 통합)
        XCTAssertEqual(ScoreDiff.classify(strokes: 7, par: 4), .double)
    }

    func test_classifyStrokes_zeroStrokes_returnsPar() {
        // strokes == 0 (미기록): guard 통과 → par 반환
        XCTAssertEqual(ScoreDiff.classify(strokes: 0, par: 4), .par)
    }

    // MARK: classify(strokes:par:)와 classify(diff:) 일관성

    func test_classifyConsistency_strokesAndDiff_matchForAllCases() {
        let cases: [(strokes: Int, par: Int, expectedDiff: Int)] = [
            (1, 4, -3), (2, 4, -2), (3, 4, -1), (4, 4, 0),
            (5, 4, 1), (6, 4, 2), (7, 4, 3),
            (2, 5, -3), (3, 5, -2), (4, 5, -1), (5, 5, 0)
        ]
        for tc in cases {
            let fromStrokes = ScoreDiff.classify(strokes: tc.strokes, par: tc.par)
            let fromDiff = ScoreDiff.classify(diff: tc.expectedDiff)
            XCTAssertEqual(fromStrokes, fromDiff,
                "strokes:\(tc.strokes)/par:\(tc.par) → classify(strokes:par:)과 classify(diff:\(tc.expectedDiff))가 다름")
        }
    }

    // MARK: voiceOverTerm

    func test_voiceOverTerm_allCases() {
        XCTAssertEqual(ScoreDiff.birdie.voiceOverTerm, "버디 이상")
        XCTAssertEqual(ScoreDiff.par.voiceOverTerm, "파")
        XCTAssertEqual(ScoreDiff.bogey.voiceOverTerm, "보기")
        XCTAssertEqual(ScoreDiff.double.voiceOverTerm, "더블보기 이상")
    }
}
