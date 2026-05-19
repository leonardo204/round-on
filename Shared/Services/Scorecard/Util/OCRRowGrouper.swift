// OCRRowGrouper.swift
// OCR 텍스트 라인을 Y 좌표 기준으로 행(row)으로 군집화

import CoreGraphics

public enum OCRRowGrouper {

    /// Y 좌표 tolerance 이내 라인들을 하나의 행으로 묶음.
    /// - Parameters:
    ///   - lines: OCRTextLine 배열 (topLeftY 오름차순 정렬 가정)
    ///   - tolerance: Y 좌표 허용 오차 (기본 0.02 = 2%)
    /// - Returns: 행 배열, 각 행은 leftX 오름차순 정렬
    public static func groupIntoRows(lines: [OCRTextLine], tolerance: CGFloat = 0.02) -> [[OCRTextLine]] {
        guard !lines.isEmpty else { return [] }

        var rows: [[OCRTextLine]] = []
        var currentRow: [OCRTextLine] = [lines[0]]
        var currentY = lines[0].topLeftY

        for line in lines.dropFirst() {
            if abs(line.topLeftY - currentY) <= tolerance {
                currentRow.append(line)
            } else {
                rows.append(currentRow.sorted { $0.leftX < $1.leftX })
                currentRow = [line]
                currentY = line.topLeftY
            }
        }
        rows.append(currentRow.sorted { $0.leftX < $1.leftX })
        return rows
    }
}
