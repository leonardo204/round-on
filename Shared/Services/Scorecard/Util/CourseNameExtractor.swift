// CourseNameExtractor.swift
// 골프장명·코스 라벨 추출 유틸

import Foundation

public enum CourseNameExtractor {

    // MARK: - 골프장명 추출

    /// 텍스트 행에서 골프장명 후보 추출.
    /// CC/GC 접미사 우선, 한국어 접미사 차순.
    public static func extractCourseName(from text: String) -> String? {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let adKeywords = ["SMARTSCORE", "GOLF", "SERVICE", "NO.1GOLF",
                          "전국", "서비스", "스코어카드", "스코어", "입력대행", "직접입력", "무료", "출력", "전송"]

        func isAdToken(_ token: String) -> Bool {
            let upper = token.uppercased()
            return adKeywords.contains(where: { upper.contains($0.uppercased()) })
        }

        // 우선순위 1: CC/GC로 끝나는 토큰
        for token in tokens {
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()[]✓✔"))
            let upper = trimmed.uppercased()
            if (upper.hasSuffix("CC") || upper.hasSuffix("GC"))
                && (3...20).contains(trimmed.count)
                && !isAdToken(trimmed) {
                return trimmed
            }
        }

        // 우선순위 2: 한국어 접미사
        let suffixes = ["컨트리클럽", "골프클럽", "골프장", "리조트", "밸리", "힐스", "파크"]
        for suffix in suffixes {
            for (i, token) in tokens.enumerated() {
                if token.contains(suffix), !isAdToken(token) {
                    let prev = i > 0 ? tokens[i - 1] : ""
                    if isAdToken(prev) { continue }
                    if i > 0 {
                        let combined = prev + token
                        if (3...20).contains(combined.count) { return combined }
                    }
                    if (3...20).contains(token.count) { return token }
                }
            }
        }
        return nil
    }

    // MARK: - 코스 라벨 판별

    /// PAR 행 근처의 코스 라벨 후보 여부 판별.
    public static func isCourseLabelCandidate(_ text: String) -> Bool {
        let reserved = ["PAR", "Par", "파", "TOTAL", "합", "합계", "DATE", "TEE", "OFF"]
        guard !reserved.contains(text) else { return false }
        guard text.count >= 1 && text.count <= 8 else { return false }
        if Int(text) != nil { return false }
        return true
    }
}
