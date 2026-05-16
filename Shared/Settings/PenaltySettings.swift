import Foundation

// MARK: - PenaltySettings
// 사용자 정의 가능한 벌타 기본값 (OB / 해저드 / 컨시드)
// + 라운드 진행 화면 모드 (스코어보드 / 홀 입력)
// UserDefaults 기반 단순 wrapper — SwiftUI @AppStorage와 키 일치.

public enum PenaltySettings {

    public enum Key {
        public static let obDelta = "penalty.obDelta"
        public static let hazardDelta = "penalty.hazardDelta"
        public static let okDelta = "penalty.okDelta"
        public static let activeRoundMode = "ui.activeRoundMode"
    }

    public enum Default {
        public static let obDelta = 2
        public static let hazardDelta = 1
        public static let okDelta = 1
        public static let activeRoundMode = "scoreboard"
    }

    /// 허용 범위 — UI stepper와 일관성 유지
    public static let validRange: ClosedRange<Int> = 1...5

    public static var obDelta: Int {
        get { read(Key.obDelta, Default.obDelta) }
        set { write(Key.obDelta, clamp(newValue)) }
    }

    public static var hazardDelta: Int {
        get { read(Key.hazardDelta, Default.hazardDelta) }
        set { write(Key.hazardDelta, clamp(newValue)) }
    }

    public static var okDelta: Int {
        get { read(Key.okDelta, Default.okDelta) }
        set { write(Key.okDelta, clamp(newValue)) }
    }

    /// 라운드 진행 화면 모드. "scoreboard" 또는 "holeInput".
    public static var activeRoundMode: String {
        get { UserDefaults.standard.string(forKey: Key.activeRoundMode) ?? Default.activeRoundMode }
        set { UserDefaults.standard.set(newValue, forKey: Key.activeRoundMode) }
    }

    // MARK: Private

    private static func read(_ key: String, _ fallback: Int) -> Int {
        guard let raw = UserDefaults.standard.object(forKey: key) as? Int else { return fallback }
        return clamp(raw)
    }

    private static func write(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private static func clamp(_ value: Int) -> Int {
        max(validRange.lowerBound, min(validRange.upperBound, value))
    }
}
