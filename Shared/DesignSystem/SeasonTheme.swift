import Foundation

public enum SeasonTheme: String, CaseIterable, Sendable {
    case spring
    case summer
    case autumn
    case winter

    /// 한국 기준 월→계절. 12,1,2=겨울 / 3-5=봄 / 6-8=여름 / 9-11=가을
    public static func forMonth(_ month: Int) -> SeasonTheme {
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .winter
        }
    }

    public var displayName: String {
        switch self {
        case .spring: "봄"
        case .summer: "여름"
        case .autumn: "가을"
        case .winter: "겨울"
        }
    }
}
