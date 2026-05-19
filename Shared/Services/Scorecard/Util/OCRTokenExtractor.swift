// OCRTokenExtractor.swift
// OCR 토큰 분해·숫자 추출·헤더 컬럼 매핑 유틸

import CoreGraphics
import Foundation

public enum OCRTokenExtractor {

    // MARK: - 단일자리 분해 (PAR 행용)

    /// 토큰 배열을 공백/구두점으로 split 후 단일자리 숫자만 반환.
    /// 두 자리 이상은 TOTAL/합계 → 무시.
    public static func splitToSingleDigits(tokens: [String]) -> [Int] {
        var result: [Int] = []
        for token in tokens {
            let subs = token.components(separatedBy: CharacterSet(charactersIn: " \t,/|-"))
            for sub in subs {
                let trimmed = sub.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if trimmed.count == 1, let d = Int(trimmed), (0...9).contains(d) {
                    result.append(d)
                }
            }
        }
        return result
    }

    /// 토큰 배열에서 2~6 범위 정수 최대 9개 추출 (PAR 행용).
    public static func extractNineNumbers(from tokens: [String]) -> [Int] {
        let allDigits = splitToSingleDigits(tokens: tokens)
        return allDigits.filter { $0 >= 2 && $0 <= 6 }
    }

    // MARK: - 스코어 추출 (플레이어 행용)

    /// 토큰 배열에서 0~99 범위 정수 추출 (TOTAL 포함).
    public static func extractAllScoreNumbers(from tokens: [String]) -> [Int] {
        var result: [Int] = []
        for token in tokens {
            let subs = token.components(separatedBy: CharacterSet(charactersIn: " \t,/|-"))
            for sub in subs {
                let trimmed = sub.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if trimmed.count <= 2, let n = Int(trimmed), (0...99).contains(n) {
                    result.append(n)
                    continue
                }
                if trimmed.allSatisfy({ $0.isNumber }) {
                    for ch in trimmed {
                        if let d = Int(String(ch)) { result.append(d) }
                    }
                }
            }
        }
        return result
    }

    // MARK: - 헤더 컬럼 X 추출

    /// PAR 행 위쪽(1~3행) 또는 아래 1행에서 1~9 홀번호 라벨의 X 좌표 9개 반환.
    /// 찾지 못하면 nil → 기존 simple 추출 fallback.
    public static func extractHeaderColumns(rows: [[OCRTextLine]], parRowIdx: Int) -> [CGFloat]? {
        var candidateIndices: [Int] = []
        for offset in 1...min(3, parRowIdx) {
            candidateIndices.append(parRowIdx - offset)
        }
        if parRowIdx + 1 < rows.count {
            candidateIndices.append(parRowIdx + 1)
        }

        for rowIdx in candidateIndices {
            let row = rows[rowIdx]
            var holeLines: [(x: CGFloat, num: Int)] = []
            for line in row {
                let subs = line.text.components(separatedBy: .whitespaces)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if subs.count == 1,
                   let n = Int(subs[0]),
                   (1...9).contains(n) {
                    holeLines.append((x: line.leftX, num: n))
                }
            }
            let nums = holeLines.map { $0.num }
            let xs   = holeLines.map { $0.x }
            guard nums.count == 9,
                  Set(nums).count == 9,
                  Set(nums) == Set(1...9) else { continue }
            let isMonotonic = zip(xs, xs.dropFirst()).allSatisfy { $0 < $1 }
            guard isMonotonic else { continue }
            return xs
        }
        return nil
    }

    // MARK: - 컬럼 매핑

    /// 한 행의 OCRTextLine들을 9개 컬럼에 매핑.
    /// - Parameters:
    ///   - row: 플레이어 행
    ///   - headerXs: 9개 컬럼 X (단조증가)
    /// - Returns: 9개 컬럼별 점수 (인식 못한 경우 0)
    public static func mapRowToColumns(row: [OCRTextLine], headerXs: [CGFloat]) -> [Int] {
        var columnValues: [Int?] = Array(repeating: nil, count: 9)

        let colSpacing = headerXs.count >= 2
            ? (headerXs.last! - headerXs.first!) / CGFloat(headerXs.count - 1)
            : 0.04
        let totalThreshold = headerXs.last! + colSpacing * 0.6

        let sortedRow = row.sorted { $0.leftX < $1.leftX }

        for line in sortedRow {
            if line.leftX > totalThreshold { continue }

            let rawTokens = line.text
                .components(separatedBy: CharacterSet(charactersIn: " \t,/|-"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let digitTokens = rawTokens.filter { t in t.count == 1 && Int(t) != nil }

            guard !digitTokens.isEmpty else { continue }

            if digitTokens.count == 1 {
                let bestCol = nearestColumnIndex(x: line.leftX, headerXs: headerXs)
                let val = Int(digitTokens[0])!
                if columnValues[bestCol] == nil {
                    columnValues[bestCol] = val
                }
            } else {
                let k = digitTokens.count
                let w = line.boundingBox.width
                for (i, tok) in digitTokens.enumerated() {
                    guard let val = Int(tok) else { continue }
                    let tokenCenterX = line.leftX + (CGFloat(i) + 0.5) * w / CGFloat(k)
                    if tokenCenterX > totalThreshold { continue }
                    let bestCol = nearestColumnIndex(x: tokenCenterX, headerXs: headerXs)
                    if columnValues[bestCol] == nil {
                        columnValues[bestCol] = val
                    }
                }
            }
        }

        return columnValues.map { $0 ?? 0 }
    }

    // MARK: - 내부 헬퍼

    /// 주어진 X에 가장 가까운 컬럼 인덱스 반환
    public static func nearestColumnIndex(x: CGFloat, headerXs: [CGFloat]) -> Int {
        var bestIdx = 0
        var bestDist = abs(x - headerXs[0])
        for (i, hx) in headerXs.enumerated().dropFirst() {
            let dist = abs(x - hx)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        return bestIdx
    }
}
