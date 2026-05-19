import Foundation

// MARK: - ScoreFormatNormalizer
// 스코어카드 점수 형식 자동 감지 + 친 타수 절대값으로 정규화
//
// 일부 표 (스마트스코어 등)는 점수를 "par 대비 +차이"로 표기:
//   par=4, 친 타수=5 → 점수 "1"
//   par=3, 친 타수=3 → 점수 "0"
//
// 라운드온 내부 데이터 모델은 친 타수 절대값을 사용하므로 변환 필요.
//
// 감지 휴리스틱:
//   1. OCR total 있으면: |scores.sum - total| vs |(scores.sum + parSum) - total|
//      후자가 더 작으면 par-diff로 추정 → par + diff
//   2. OCR total 없으면: scores.sum이 parSum의 50% 미만이면서 모든 값이 0~9 단일자리면 par-diff 추정
//
// parser별로 중복 작성하지 않고 ScorecardOCRService.recognize()에서 한 번만 호출.

public enum ScoreFormatNormalizer {

    /// 결과를 정규화. 점수가 par-diff 형식으로 보이면 친 타수 절대값으로 변환.
    public static func normalize(result: ScorecardOCRResult) -> ScorecardOCRResult {
        guard !result.pars.isEmpty else { return result }
        let parSum = result.pars.reduce(0, +)

        var normalized: [OCRPlayer] = []
        for p in result.players {
            guard p.scores.count == result.pars.count else {
                normalized.append(p)
                continue
            }
            let diffSum = p.scores.reduce(0, +)
            let absoluteSum = diffSum  // 같은 의미지만 분기 가독성용

            let shouldConvert: Bool
            var reason: String

            if let total = p.total {
                // 휴리스틱 1: total과 거리 비교
                let distAsAbsolute = abs(absoluteSum - total)
                let distAsDiff = abs((absoluteSum + parSum) - total)
                shouldConvert = distAsDiff < distAsAbsolute
                reason = "total=\(total) absDist=\(distAsAbsolute) diffDist=\(distAsDiff)"
            } else {
                // 휴리스틱 2: total 없으면 점수가 par 합 50% 미만이면서 모두 0~9 단일자리면 par-diff 추정
                let halfPar = parSum / 2
                let allSingleDigit = p.scores.allSatisfy { (0...9).contains($0) }
                shouldConvert = absoluteSum < halfPar && allSingleDigit
                reason = "total=nil sum=\(absoluteSum) parSum=\(parSum) (< \(halfPar) ?) allSingle=\(allSingleDigit)"
            }

            if shouldConvert {
                let actualScores = zip(p.scores, result.pars).map { $0 + $1 }
                AppLogger.ocr.info("[Normalizer] '\(p.name, privacy: .public)' par-diff → 친타수 변환: \(actualScores, privacy: .public) [\(reason, privacy: .public)]")
                normalized.append(OCRPlayer(
                    name: p.name,
                    scores: actualScores,
                    total: p.total,
                    isOwnerCandidate: p.isOwnerCandidate
                ))
            } else {
                AppLogger.ocr.debug("[Normalizer] '\(p.name, privacy: .public)' 절대값 형식 유지 [\(reason, privacy: .public)]")
                normalized.append(p)
            }
        }

        return ScorecardOCRResult(
            courseName: result.courseName,
            date: result.date,
            teeOffTime: result.teeOffTime,
            frontCourseName: result.frontCourseName,
            backCourseName: result.backCourseName,
            pars: result.pars,
            players: normalized,
            rawLines: result.rawLines,
            warnings: result.warnings
        )
    }
}
