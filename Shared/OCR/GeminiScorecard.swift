import Foundation

// MARK: - GeminiScorecard
// Gemini Vision API 응답 1:1 매핑.
// values = over-par delta (실제 타수 아님).
// par 행은 values = 홀별 실제 par (3/4/5).
// out/inScore/total = 실제 타수 합계 (이미지에 직접 인쇄된 값).
//
// ★ CodingKeys 주의:
//   responseSchema 및 실제 Gemini 응답 키는 "inScore" — "in" 아님.
//   case inScore = "inScore" 로 명시.

public struct GeminiScorecard: Codable, Sendable {
    public let courseName: String
    public let date: String          // Gemini 반환 형식 (보통 "YYYY-MM-DD")
    public let rows: [GeminiRow]

    // MARK: - 헬퍼

    public var parRow: GeminiRow? {
        rows.first { $0.kind == "par" }
    }

    public var players: [GeminiRow] {
        rows.filter { $0.kind == "player" }
    }
}

public struct GeminiRow: Codable, Sendable {
    public let label: String
    public let kind: String          // "par" | "player"
    public let isOwner: Bool?
    public let values: [Int]         // over-par delta (par행은 실제 par 3/4/5)
    public let out: Int              // 전반 실제 타수 합계
    public let inScore: Int          // 후반 실제 타수 합계
    public let total: Int            // 18홀 실제 합계

    // ★ Gemini responseSchema가 "inScore" 키를 사용하므로 동일하게 매핑.
    //   (계획서 샘플의 "in"은 오류 — 사용 금지)
    enum CodingKeys: String, CodingKey {
        case label, kind, isOwner, values, out, total
        case inScore = "inScore"
    }
}

// MARK: - OCRError

public enum OCRError: Error, LocalizedError, Sendable {
    case apiKeyMissing
    case apiKeyNotConfigured
    case httpError(Int, String)
    case invalidResponse
    case validationFailed(String)
    case exhausted
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Gemini API 키가 Info.plist에 설정되지 않았습니다."
        case .apiKeyNotConfigured:
            return "Gemini API 키가 올바르게 구성되지 않았습니다. (placeholder 상태)"
        case .httpError(let code, _):
            return "Gemini API 요청 오류 (HTTP \(code)). 잠시 후 다시 시도해 주세요."
        case .invalidResponse:
            return "Gemini 응답을 파싱할 수 없습니다."
        case .validationFailed(let reason):
            return "스코어카드 구조 검증 실패: \(reason)"
        case .exhausted:
            return "최대 재시도 횟수를 초과했습니다. 수동으로 입력해 주세요."
        case .cancelled:
            return "분석이 취소되었습니다."
        }
    }
}
