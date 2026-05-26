import Foundation

// MARK: - ScoreDiff
// viewer.ts 4단계 분류 (2026-05-24 v6 디자인 이식)
// birdie(≤-1) / par(0) / bogey(+1) / double(≥+2)
// HIO/Eagle/Triple은 각각 birdie/double 구간으로 통합

public enum ScoreDiff: Equatable {
    case birdie  // ≤ -1 (HIO/Albatross/Eagle 포함)
    case par     // 0
    case bogey   // +1
    case double  // ≥ +2 (Triple 포함)

    /// PAR 대비 diff 값으로 직접 분류
    public static func classify(diff: Int) -> ScoreDiff {
        switch diff {
        case ..<0: return .birdie
        case 0:    return .par
        case 1:    return .bogey
        default:   return .double
        }
    }

    /// strokes + par로 분류
    public static func classify(strokes: Int, par: Int) -> ScoreDiff {
        guard strokes > 0 else { return .par }
        return classify(diff: strokes - par)
    }

    /// VoiceOver 발화 텍스트
    public var voiceOverTerm: String {
        switch self {
        case .birdie: return "버디 이상"
        case .par:    return "파"
        case .bogey:  return "보기"
        case .double: return "더블보기 이상"
        }
    }
}
