import Foundation

// MARK: - ScorecardValidator
// Gemini 응답의 구조적 정합성을 검증한다.
//
// ★ 핵심: 합계(out+in=total) 검증만으로는 부족하다.
//   IMG_1358 케이스: back 9홀 누락(values.count=9), inScore=0, total=56
//   → out+inScore=56==total로 거짓 통과. values.count==holeCount 로 잡는다.
//
// holeCount는 인자를 신뢰하지 않고 카드 구조(par행, out/in/total 패턴)로 추론.
// 9홀 단독 카드를 18홀로 오판해 거부하지 않도록 주의.

public enum ScorecardValidator {

    // MARK: - 공개 API

    /// Gemini 카드 전체를 검증한다. 하나라도 실패하면 OCRError.validationFailed를 throw.
    public static func check(_ card: GeminiScorecard, holeCount requestedHoleCount: Int) throws {
        // 1. holeCount 추론 (par행 우선, 없으면 요청값, 없으면 player 행 길이로 추론)
        let inferredHoleCount = inferHoleCount(from: card, requested: requestedHoleCount)

        // 2. par행 검증 (있을 때)
        if let parRow = card.parRow {
            try validateParRow(parRow, holeCount: inferredHoleCount)
        }

        // 3. player행 각각 검증
        for player in card.players {
            try validatePlayerRow(player, holeCount: inferredHoleCount, parRow: card.parRow)
        }

        // 4. 전체 player가 없으면 오인식
        if card.players.isEmpty {
            throw OCRError.validationFailed("player 행이 없습니다.")
        }
    }

    // MARK: - holeCount 추론

    /// par행이 있으면 그 길이를 신뢰하고, 없으면 호출자의 기대 홀 수(requested)를 쓴다.
    public static func inferHoleCount(from card: GeminiScorecard, requested: Int) -> Int {
        // par행 길이가 9/18 판별의 유일한 확실한 구조 단서.
        if let parRow = card.parRow, !parRow.values.isEmpty {
            return parRow.values.count
        }
        // par행 없음(앱스샷): inScore==0 + values.count==9 를 9홀로 강등하지 않는다.
        // 그 시그니처는 18홀 카드의 back9 누락(IMG_1358: out=56,in=0,total=56)과 동일하므로,
        // 강등하면 §4 핵심 방어("값 개수==holeCount")가 무력화된다.
        // 실제 9홀 라운드는 par행 9개 또는 호출자의 requested=9로 식별한다.
        return requested
    }

    // MARK: - Private

    private static func validateParRow(_ parRow: GeminiRow, holeCount: Int) throws {
        // par행 길이 검증: values.count == holeCount (불일치는 오인식 신호)
        guard parRow.values.count == holeCount else {
            throw OCRError.validationFailed(
                "par행 길이(\(parRow.values.count))가 holeCount(\(holeCount))와 다릅니다. 오인식 가능성."
            )
        }
        // par값 현실성: 3/4/5 범위
        for (i, v) in parRow.values.enumerated() {
            guard v >= 3 && v <= 5 else {
                throw OCRError.validationFailed("par행 [\(i)]값 \(v)가 3~5 범위를 벗어납니다.")
            }
        }
    }

    private static func validatePlayerRow(
        _ player: GeminiRow,
        holeCount: Int,
        parRow: GeminiRow?
    ) throws {
        let label = player.label

        // 검증 1: 값 개수 == holeCount (★ IMG_1358 케이스를 여기서 잡는다)
        guard player.values.count == holeCount else {
            throw OCRError.validationFailed(
                "\(label): values.count(\(player.values.count)) ≠ holeCount(\(holeCount)). " +
                "back9 누락 가능성."
            )
        }

        // 검증 2: 합계 정합 out + inScore == total
        // 9홀 카드의 경우 inScore=0이 정상
        if holeCount == 18 {
            guard player.out + player.inScore == player.total else {
                throw OCRError.validationFailed(
                    "\(label): out(\(player.out)) + inScore(\(player.inScore)) ≠ total(\(player.total))"
                )
            }
        }
        // 9홀 카드는 out == total
        if holeCount == 9 {
            guard player.out == player.total else {
                throw OCRError.validationFailed(
                    "\(label)(9홀): out(\(player.out)) ≠ total(\(player.total))"
                )
            }
        }

        // 검증 3: par행이 있을 때 over-par 정합
        if let parRow = parRow, parRow.values.count == holeCount {
            try validateOverParConsistency(player: player, parRow: parRow, holeCount: holeCount)
        }

        // 검증 4: 현실성 (total 범위)
        // par총합 없으면 72(표준 18홀) 기준
        let parTotal: Int
        if let parRow = parRow, parRow.values.count == holeCount {
            parTotal = parRow.values.reduce(0, +)
        } else {
            parTotal = holeCount == 9 ? 36 : 72
        }
        let minTotal = parTotal - holeCount  // 모든 홀 버디 (언더 홀수 초과는 비현실)
        let maxTotal = parTotal + 90          // 모든 홀 대다수 +5 = 비현실 상한
        guard player.total >= minTotal && player.total <= maxTotal else {
            throw OCRError.validationFailed(
                "\(label): total(\(player.total))이 현실 범위 [\(minTotal)~\(maxTotal)] 밖입니다."
            )
        }
    }

    /// over-par delta합 + par합 == 섹션 실제 타수 합 검증
    private static func validateOverParConsistency(
        player: GeminiRow,
        parRow: GeminiRow,
        holeCount: Int
    ) throws {
        guard holeCount == 18 else { return }  // 9홀은 단순화

        let frontDeltas = player.values.prefix(9)
        let backDeltas = player.values.suffix(9)
        let frontPars = parRow.values.prefix(9)
        let backPars = parRow.values.suffix(9)

        let frontCalcTotal = zip(frontDeltas, frontPars).reduce(0) { $0 + $1.0 + $1.1 }
        let backCalcTotal = zip(backDeltas, backPars).reduce(0) { $0 + $1.0 + $1.1 }

        // 허용 오차: ±1 (반올림 등 인쇄 오차 허용)
        if abs(frontCalcTotal - player.out) > 1 {
            throw OCRError.validationFailed(
                "\(player.label): 전반 delta합산(\(frontCalcTotal)) ≠ out(\(player.out))"
            )
        }
        if abs(backCalcTotal - player.inScore) > 1 {
            throw OCRError.validationFailed(
                "\(player.label): 후반 delta합산(\(backCalcTotal)) ≠ inScore(\(player.inScore))"
            )
        }
    }
}
