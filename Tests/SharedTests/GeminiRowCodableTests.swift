import XCTest
@testable import Shared

// MARK: - GeminiRowCodableTests
// GeminiRow / GeminiScorecard JSON Codable 검증.
// 핵심: "inScore" 키 매핑 정합성 (회귀 방지).

final class GeminiRowCodableTests: XCTestCase {

    // MARK: - C1. "inScore" 키로 디코드 성공

    func test_geminiRow_decodesInScoreKey() throws {
        let json = """
        {
            "label": "이용섭",
            "kind": "player",
            "isOwner": true,
            "values": [1, 2, 3],
            "out": 42,
            "inScore": 48,
            "total": 90
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let row = try JSONDecoder().decode(GeminiRow.self, from: data)

        XCTAssertEqual(row.inScore, 48)
        XCTAssertEqual(row.out, 42)
        XCTAssertEqual(row.total, 90)
        XCTAssertEqual(row.label, "이용섭")
        XCTAssertEqual(row.kind, "player")
        XCTAssertEqual(row.isOwner, true)
        XCTAssertEqual(row.values, [1, 2, 3])
    }

    // MARK: - C2. "in" 키는 inScore에 매핑되지 않아야 함 (회귀 방지)
    // GeminiRow.CodingKeys에 "in" 케이스가 없으므로 디코드 실패해야 함

    func test_geminiRow_withInKey_failsOrIgnoresIt() throws {
        // "inScore" 키 없이 "in"만 있으면 inScore = 0 (기본값 없으면 실패)
        // Swift Codable: required field 누락 시 DecodingError
        let json = """
        {
            "label": "이용섭",
            "kind": "player",
            "isOwner": true,
            "values": [1, 2, 3],
            "out": 42,
            "in": 48,
            "total": 90
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        // "inScore" 필드가 없으므로 디코딩 실패해야 함 (Int에 기본값 없음)
        XCTAssertThrowsError(try JSONDecoder().decode(GeminiRow.self, from: data),
            "'in' 키로만 구성된 JSON은 inScore 매핑 실패해야 함") { error in
            // DecodingError.keyNotFound 또는 .valueNotFound
            XCTAssertTrue(
                error is DecodingError,
                "DecodingError가 아닌 에러 발생: \(error)"
            )
        }
    }

    // MARK: - C3. par 행 디코드: isOwner nil 허용

    func test_geminiRow_parKind_decodesWithoutIsOwner() throws {
        let json = """
        {
            "label": "PAR",
            "kind": "par",
            "values": [4, 5, 4, 3, 4, 4, 3, 5, 4, 5, 4, 3, 4, 4, 3, 4, 4, 5],
            "out": 36,
            "inScore": 36,
            "total": 72
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let row = try JSONDecoder().decode(GeminiRow.self, from: data)

        XCTAssertEqual(row.kind, "par")
        XCTAssertNil(row.isOwner, "par행은 isOwner가 nil이어야 함")
        XCTAssertEqual(row.values.count, 18)
        XCTAssertEqual(row.inScore, 36)
    }

    // MARK: - C4. GeminiScorecard 전체 디코드

    func test_geminiScorecard_fullDecode() throws {
        let json = """
        {
            "courseName": "진양밸리CC",
            "date": "2026-04-30",
            "rows": [
                {
                    "label": "PAR",
                    "kind": "par",
                    "values": [4,5,4,3,4,4,3,5,4, 5,4,3,4,4,3,4,4,5],
                    "out": 36,
                    "inScore": 36,
                    "total": 72
                },
                {
                    "label": "이용섭",
                    "kind": "player",
                    "isOwner": true,
                    "values": [1,2,3,3,2,2,1,4,0, 3,1,3,4,2,3,2,2,4],
                    "out": 54,
                    "inScore": 60,
                    "total": 114
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let card = try JSONDecoder().decode(GeminiScorecard.self, from: data)

        XCTAssertEqual(card.courseName, "진양밸리CC")
        XCTAssertEqual(card.date, "2026-04-30")
        XCTAssertEqual(card.rows.count, 2)

        let par = card.parRow
        XCTAssertNotNil(par, "parRow 헬퍼가 nil 반환")
        XCTAssertEqual(par?.inScore, 36)

        let players = card.players
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players[0].inScore, 60)
        XCTAssertEqual(players[0].isOwner, true)
    }

    // MARK: - C5. 음수 delta 디코드 (버디 케이스)

    func test_geminiRow_negativeDeltaValues_decodesCorrectly() throws {
        let json = """
        {
            "label": "김**",
            "kind": "player",
            "isOwner": false,
            "values": [-1, 0, 1, -2, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1, -1, 0, 1],
            "out": 36,
            "inScore": 36,
            "total": 72
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let row = try JSONDecoder().decode(GeminiRow.self, from: data)

        XCTAssertEqual(row.values[0], -1, "버디(-1) delta가 올바르게 디코드되어야 함")
        XCTAssertEqual(row.values[3], -2, "이글(-2) delta가 올바르게 디코드되어야 함")
    }

    // MARK: - C6. GeminiScorecard encode → decode 왕복 일관성

    func test_geminiScorecard_encodeDecodRoundtrip() throws {
        let original = GeminiScorecard(
            courseName: "테스트CC",
            date: "2026-05-01",
            rows: [
                GeminiRow(label: "PAR", kind: "par", isOwner: nil,
                          values: [4,4,3,3,5,4,4,4,5, 4,4,4,5,3,4,3,5,4],
                          out: 36, inScore: 36, total: 72),
                GeminiRow(label: "이용섭", kind: "player", isOwner: true,
                          values: [2,1,1,2,0,1,1,2,1, 1,2,1,1,2,0,1,1,2],
                          out: 47, inScore: 47, total: 94)
            ]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeminiScorecard.self, from: encoded)

        XCTAssertEqual(decoded.courseName, original.courseName)
        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.rows.count, original.rows.count)

        // inScore 왕복 확인
        let decodedPar = decoded.parRow
        XCTAssertEqual(decodedPar?.inScore, 36)

        let decodedPlayer = decoded.players.first
        XCTAssertEqual(decodedPlayer?.inScore, 47)
    }
}
