// DateExtractor.swift
// 날짜·티오프 시간 추출 유틸

import Foundation

public enum DateExtractor {

    /// 텍스트에서 날짜 추출 (yyyy/MM/dd, yyyy.MM.dd, yyyy-MM-dd).
    public static func extractDate(from text: String) -> Date? {
        let pattern = #"(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let sub = String(text[match])
            let sep = sub.first(where: { "/.-".contains($0) }) ?? "/"
            let parts = sub.components(separatedBy: String(sep))
            if parts.count == 3,
               let year  = Int(parts[0]),
               let month = Int(parts[1]),
               let day   = Int(parts[2]) {
                var comps = DateComponents()
                comps.year  = year
                comps.month = month
                comps.day   = day
                return Calendar.current.date(from: comps)
            }
        }
        return nil
    }

    /// 텍스트에서 티오프 시간 문자열 추출 (AM/PM HH:mm 또는 HH:mm).
    public static func extractTeeOffTime(from text: String) -> String? {
        let pattern = #"(AM|PM|am|pm)?\s*(\d{1,2}:\d{2})"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
