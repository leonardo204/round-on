import Foundation

// MARK: - HoleResultMessage
// 홀 완료(잠금) 시 표시할 결과 멘트 (4단계 ScoreDiff 기반)
// Watch 화면 좁음 — 전체 60자 이하 유지

public enum HoleResultMessage {
    public static func text(for diff: ScoreDiff) -> String {
        switch diff {
        case .birdie: return "버디 이상! 축하드립니다 🎯 이 기세 그대로!"
        case .par:    return "파! 안정적인 플레이입니다 👍"
        case .bogey:  return "보기네요. 다음 홀에서 만회해봐요 🌱"
        case .double: return "더블보기 이상이에요. 호흡 가다듬고 다음 홀 집중! 🍃"
        }
    }
}
