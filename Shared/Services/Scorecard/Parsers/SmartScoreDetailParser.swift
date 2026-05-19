// SmartScoreDetailParser.swift
// 스마트스코어 정밀 표 형식 파서 (IMG_1335 기준 휴리스틱)

import CoreGraphics
import Foundation

public enum SmartScoreDetailParser: ScorecardParser {

    public static let typeName = "SmartScoreDetailParser"

    // MARK: - detect

    /// 스마트스코어 형식 식별 신호:
    /// - SMARTSCORE / SMART / SCORE 토큰 → +0.3
    /// - PAR 행 1개 이상 → +0.3
    /// - TOTAL 토큰 → +0.2
    /// - CC/GC 토큰 → +0.2
    public static func detect(lines: [OCRTextLine]) -> Double {
        let allText = lines.map { $0.text.uppercased() }.joined(separator: " ")
        var score = 0.0

        if allText.contains("SMARTSCORE") || allText.contains("SMART") || allText.contains("SCORE") {
            score += 0.3
        }

        let rows = OCRRowGrouper.groupIntoRows(lines: lines)
        let hasParRow = rows.contains { row in
            row.map { $0.text }.contains(where: { $0.uppercased() == "PAR" || $0 == "파" })
        }
        if hasParRow { score += 0.3 }

        if allText.contains("TOTAL") { score += 0.2 }

        if allText.contains("CC") || allText.contains("GC") { score += 0.2 }

        return min(score, 1.0)
    }

    // MARK: - parse

    public static func parse(lines: [OCRTextLine]) -> ScorecardOCRResult? {
        let rows = OCRRowGrouper.groupIntoRows(lines: lines, tolerance: 0.02)
        AppLogger.ocr.debug("[\(typeName)] 행 군집화: \(rows.count)행")

        var courseName: String? = nil
        var dateFound: Date? = nil
        var teeOffTime: String? = nil
        var frontCourseName: String? = nil
        var backCourseName: String? = nil
        var parRows: [[Int]] = []
        var parRowIndices: [Int] = []
        var courseLabels: [String] = []
        var players: [OCRPlayer] = []

        // --- 1. 날짜/시간/골프장명 ---
        for row in rows {
            let merged = row.map { $0.text }.joined(separator: " ")

            if merged.contains("DATE") || merged.contains("date") {
                if let d = DateExtractor.extractDate(from: merged) { dateFound = d }
            }
            if dateFound == nil, let d = DateExtractor.extractDate(from: merged) {
                dateFound = d
            }
            if merged.contains("TEE") || merged.contains("tee") || merged.contains("티오프") {
                teeOffTime = DateExtractor.extractTeeOffTime(from: merged)
            }
            if courseName == nil {
                if let cn = CourseNameExtractor.extractCourseName(from: merged) {
                    courseName = cn
                }
            }
        }

        // --- 2. PAR 행 탐색 (임계 7개, 부족 슬롯 4 padding) ---
        for (rowIdx, row) in rows.enumerated() {
            let tokens = row.map { $0.text }
            guard tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" }) else { continue }

            var nums = OCRTokenExtractor.extractNineNumbers(from: tokens)
            AppLogger.ocr.debug("[\(typeName)] PAR 후보 #\(rowIdx) nums=\(nums, privacy: .public)")

            if nums.count >= 9 {
                parRows.append(Array(nums.prefix(9)))
                parRowIndices.append(rowIdx)
            } else if nums.count >= 7 {
                while nums.count < 9 { nums.append(4) }
                AppLogger.ocr.warning("[\(typeName)] PAR 행 #\(rowIdx) 부족 → 4로 padding: \(nums, privacy: .public)")
                parRows.append(nums)
                parRowIndices.append(rowIdx)
            }
        }
        AppLogger.ocr.debug("[\(typeName)] PAR 블록 \(parRows.count)개 (rowIdx=\(parRowIndices, privacy: .public))")

        // PAR 행이 없으면 nil → 다음 parser 시도
        guard !parRows.isEmpty else {
            AppLogger.ocr.info("[\(typeName)] PAR 행 없음 → nil 반환")
            return nil
        }

        // --- 3. 코스명 (PAR 행 위 1~3행) ---
        for parIdx in parRowIndices {
            for offset in 1...min(3, parIdx) {
                let prevTokens = rows[parIdx - offset].map { $0.text }
                if let label = prevTokens.first(where: { CourseNameExtractor.isCourseLabelCandidate($0) }) {
                    courseLabels.append(label)
                    break
                }
            }
        }
        if courseLabels.count >= 1 { frontCourseName = courseLabels[0] }
        if courseLabels.count >= 2 { backCourseName = courseLabels[1] }

        // --- 4. 플레이어 행 추출 ---
        var processedPlayerNames: Set<String> = []

        for (pIdx, parRowIdx) in parRowIndices.enumerated() {
            let parNums = parRows[pIdx]
            var localPlayers: [(name: String, scores: [Int], total: Int?)] = []

            let headerXs = OCRTokenExtractor.extractHeaderColumns(rows: rows, parRowIdx: parRowIdx)
            let headerXsDesc = headerXs.map { xs in xs.map { String(format: "%.3f", $0) }.joined(separator: ",") } ?? "nil"
            AppLogger.ocr.debug("[\(typeName)] PAR행 #\(parRowIdx) headerXs=\(headerXsDesc, privacy: .public)")

            // TOTAL 컬럼 X 동적 추출: PAR 행 위/아래 1~3행에서 "TOTAL" 토큰 leftX 검색.
            // 없으면 headerXs.last + 한 컬럼 폭 fallback (헤더 균등 분포 가정).
            // hardcode 0.38 같은 이미지별 휴리스틱 제거.
            let totalColumnX: CGFloat = {
                let searchRange = max(0, parRowIdx-3)...min(rows.count-1, parRowIdx+3)
                for ridx in searchRange {
                    for line in rows[ridx] where line.text.uppercased() == "TOTAL" || line.text == "합" || line.text == "합계" {
                        return line.leftX
                    }
                }
                if let xs = headerXs, xs.count >= 2 {
                    let step = xs[xs.count-1] - xs[xs.count-2]
                    return xs.last! + step * 0.7  // 마지막 홀 + 한 컬럼 폭의 70%
                }
                return 0.38  // 최후 fallback
            }()
            AppLogger.ocr.debug("[\(typeName)] PAR행 #\(parRowIdx) totalColumnX=\(String(format: "%.3f", totalColumnX), privacy: .public)")

            var scanIdx = parRowIdx + 1
            while scanIdx < rows.count {
                let row = rows[scanIdx]
                let tokens = row.map { $0.text }

                if tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" }) { break }
                // 플레이어 행 식별: par filter(2~6) 없이 단일자리 점수(0~9) 3개 이상 있어야 함
                // (동반자 점수가 1,1,0,1 같이 par 범위 밖일 때 끊기지 않게)
                let scoreDigits = OCRTokenExtractor.extractAllScoreNumbers(from: tokens).filter { (0...15).contains($0) }
                if scoreDigits.count < 3 {
                    AppLogger.ocr.debug("[\(typeName)] 행 #\(scanIdx) 점수 \(scoreDigits.count)개 → 플레이어 행 아님, 스캔 중단")
                    break
                }

                guard let nameToken = tokens.first(where: { PlayerNameClassifier.isPlayerName($0) }) else {
                    scanIdx += 1
                    continue
                }

                let allNums = OCRTokenExtractor.extractAllScoreNumbers(from: tokens)
                // 9홀 score = 0~9 단일자리만
                let singles = allNums.filter { (0...9).contains($0) }
                var scores9: [Int] = Array(singles.prefix(9))
                while scores9.count < 9 { scores9.append(0) }
                // TOTAL = TOTAL 컬럼 위치(leftX >= totalColumnX) 안의 **첫 번째** 두자리 정수.
                // 후반 행에 "구간 합 + 전체 합"("47 92")이 묶이는 케이스 → 47 = 구간 합 채택.
                // score 자리에 잘못 묶인 두자리("000 20 23"의 20,23)는 동적 임계로 자동 제외.
                // totalColumnX는 헤더 "TOTAL" 토큰 X 또는 headerXs.last + step*0.7로 계산됨 (위 참조).
                let totalColumnXThreshold: CGFloat = max(totalColumnX - 0.02, 0.30)
                var total: Int? = nil
                for line in row.sorted(by: { $0.leftX < $1.leftX }) where line.leftX >= totalColumnXThreshold {
                    let subs = line.text.components(separatedBy: CharacterSet(charactersIn: " \t,/|-"))
                    if let firstTwoDigit = subs
                        .map({ $0.trimmingCharacters(in: .whitespaces) })
                        .first(where: { $0.count == 2 && (10...199).contains(Int($0) ?? 0) })
                        .flatMap({ Int($0) }) {
                        total = firstTwoDigit
                        break
                    }
                }
                _ = headerXs  // 향후 검증/보조용
                AppLogger.ocr.debug("[\(typeName)] 플레이어 '\(nameToken, privacy: .public)' 순서매핑=\(scores9, privacy: .public) total=\(total ?? -1) (singles=\(singles.count))")

                localPlayers.append((name: nameToken, scores: scores9, total: total))
                _ = parNums
                scanIdx += 1
            }

            // 후반 합산은 이름이 아닌 순서 기준 — OCR 이름 오인식("이**" → "0**") robust
            if pIdx == 0 {
                // 첫 PAR 블록: 새 player 추가
                for lp in localPlayers {
                    processedPlayerNames.insert(lp.name)
                    let isOwner = players.isEmpty || (!lp.name.contains("*") && players.allSatisfy { !$0.isOwnerCandidate })
                    players.append(OCRPlayer(name: lp.name, scores: lp.scores, total: lp.total,
                                            isOwnerCandidate: isOwner))
                }
            } else {
                // 후반 블록: 행 순서 그대로 merge (i번째 후반 row = i번째 전반 row 동일 player로 간주)
                for (i, lp) in localPlayers.enumerated() {
                    if i < players.count {
                        let ex = players[i]
                        let mergedScores = ex.scores + lp.scores
                        let newTotal = (ex.total ?? 0) + (lp.total ?? lp.scores.reduce(0, +))
                        players[i] = OCRPlayer(name: ex.name, scores: mergedScores, total: newTotal,
                                              isOwnerCandidate: ex.isOwnerCandidate)
                        AppLogger.ocr.debug("[\(typeName)] 후반 merge: '\(lp.name, privacy: .public)' → players[\(i)] '\(ex.name, privacy: .public)'")
                    } else {
                        // 후반 행이 전반보다 많으면 신규 추가 (드문 케이스)
                        players.append(OCRPlayer(name: lp.name, scores: lp.scores, total: lp.total,
                                                isOwnerCandidate: false))
                    }
                }
            }
        }

        // --- 5. pars 합산 ---
        let pars: [Int]
        if parRows.count == 1 { pars = parRows[0] }
        else if parRows.count >= 2 { pars = parRows[0] + parRows[1] }
        else { pars = [] }

        // 점수 형식(par-diff vs 절대값) 정규화는 ScorecardOCRService.recognize에서 ScoreFormatNormalizer로 일괄 처리.

        // --- 6. 경고 진단 ---
        var warnings: [ScorecardOCRWarning] = []
        if courseName == nil              { warnings.append(.missingCourseName) }
        if dateFound == nil               { warnings.append(.missingDate) }
        if frontCourseName == nil         { warnings.append(.missingFrontCourseName) }
        if pars.count == 9                { warnings.append(.onlyHalfRound) }
        if pars.count >= 18 && backCourseName == nil { warnings.append(.missingBackCourseName) }
        if players.isEmpty                { warnings.append(.noPlayers) }
        else if players.count == 1        { warnings.append(.fewPlayers) }

        let mismatch = players.contains { p in
            guard let t = p.total else { return false }
            return abs(p.scores.reduce(0, +) - t) >= 5
        }
        if mismatch { warnings.append(.scoreSumMismatch) }

        return ScorecardOCRResult(
            courseName: courseName,
            date: dateFound,
            teeOffTime: teeOffTime,
            frontCourseName: frontCourseName,
            backCourseName: backCourseName,
            pars: pars,
            players: players,
            rawLines: lines,
            warnings: warnings
        )
    }
}
