// CommonScorecardParser.swift
// 범용 fallback 파서 — 최소 휴리스틱으로 어떤 표 형식이든 일부 잡기

import CoreGraphics
import Foundation

public enum CommonScorecardParser: ScorecardParser {

    public static let typeName = "CommonScorecardParser"

    // MARK: - detect

    /// PAR 행이 있거나 단일자리 9개 이상 행이 존재하면 0.5 반환.
    public static func detect(lines: [OCRTextLine]) -> Double {
        let rows = OCRRowGrouper.groupIntoRows(lines: lines)

        let hasParRow = rows.contains { row in
            row.map { $0.text }.contains(where: { $0.uppercased() == "PAR" || $0 == "파" })
        }
        if hasParRow { return 0.5 }

        let hasDenseRow = rows.contains { row in
            let tokens = row.map { $0.text }
            let singles = OCRTokenExtractor.splitToSingleDigits(tokens: tokens)
                .filter { $0 >= 2 && $0 <= 6 }
            return singles.count >= 9
        }
        return hasDenseRow ? 0.5 : 0.0
    }

    // MARK: - parse

    /// 완화된 임계값(4개 이상)으로 PAR 행을 채택하고, 가능한 만큼 추출 후 반환.
    /// 결과가 빈약해도 warning만 채우고 반환 (throw 안 함).
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

        // --- 2. PAR 행 탐색 (임계 4개로 완화) ---
        for (rowIdx, row) in rows.enumerated() {
            let tokens = row.map { $0.text }
            guard tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" }) else { continue }

            var nums = OCRTokenExtractor.extractNineNumbers(from: tokens)
            AppLogger.ocr.debug("[\(typeName)] PAR 후보 #\(rowIdx) nums=\(nums, privacy: .public)")

            if nums.count >= 9 {
                parRows.append(Array(nums.prefix(9)))
                parRowIndices.append(rowIdx)
            } else if nums.count >= 4 {
                // 4개 이상이면 완화 채택, 부족 슬롯 4 padding
                while nums.count < 9 { nums.append(4) }
                AppLogger.ocr.warning("[\(typeName)] PAR 행 #\(rowIdx) 완화 채택 + padding: \(nums, privacy: .public)")
                parRows.append(nums)
                parRowIndices.append(rowIdx)
            }
        }

        // PAR 행 없으면 nil
        guard !parRows.isEmpty else {
            AppLogger.ocr.info("[\(typeName)] PAR 행 없음 → nil 반환")
            return nil
        }

        AppLogger.ocr.debug("[\(typeName)] PAR 블록 \(parRows.count)개")

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

            var scanIdx = parRowIdx + 1
            while scanIdx < rows.count {
                let row = rows[scanIdx]
                let tokens = row.map { $0.text }

                if tokens.contains(where: { $0.uppercased() == "PAR" || $0 == "파" }) { break }
                let nums = OCRTokenExtractor.extractNineNumbers(from: tokens)
                // Common은 3개 미만이면 멈추지 않고 건너뜀 (빈약해도 계속 스캔)
                if nums.count < 3 {
                    scanIdx += 1
                    continue
                }

                guard let nameToken = tokens.first(where: { PlayerNameClassifier.isPlayerName($0) }) else {
                    scanIdx += 1
                    continue
                }

                let allNums = OCRTokenExtractor.extractAllScoreNumbers(from: tokens)
                let total = allNums.count >= 10 ? allNums[9] : nil

                let scores9: [Int]
                if let hXs = headerXs {
                    scores9 = OCRTokenExtractor.mapRowToColumns(row: row, headerXs: hXs)
                } else {
                    scores9 = allNums.count >= 9 ? Array(allNums.prefix(9)) : Array(allNums.prefix(allNums.count))
                }

                localPlayers.append((name: nameToken, scores: scores9, total: total))
                _ = parNums
                scanIdx += 1
            }

            for lp in localPlayers {
                if processedPlayerNames.contains(lp.name) {
                    if let idx = players.firstIndex(where: { $0.name == lp.name }) {
                        let ex = players[idx]
                        let mergedScores = ex.scores + lp.scores
                        let newTotal = (ex.total ?? 0) + (lp.total ?? lp.scores.reduce(0, +))
                        players[idx] = OCRPlayer(name: ex.name, scores: mergedScores, total: newTotal,
                                                 isOwnerCandidate: ex.isOwnerCandidate)
                    }
                } else {
                    processedPlayerNames.insert(lp.name)
                    let isOwner = players.isEmpty || (!lp.name.contains("*") && players.allSatisfy { !$0.isOwnerCandidate })
                    players.append(OCRPlayer(name: lp.name, scores: lp.scores, total: lp.total,
                                            isOwnerCandidate: isOwner))
                }
            }
        }

        // --- 5. pars 합산 ---
        let pars: [Int]
        if parRows.count == 1 { pars = parRows[0] }
        else if parRows.count >= 2 { pars = parRows[0] + parRows[1] }
        else { pars = [] }

        // --- 6. 경고 (빈약해도 반환) ---
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
