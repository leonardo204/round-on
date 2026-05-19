import Foundation
import OSLog

// MARK: - AppLogger
// OSLog 기반 구조화 로깅 (작업 B1)
// 카테고리별 Logger를 공유 싱글턴으로 제공 — 매 호출마다 재생성 금지
// PII(이름/좌표)는 반드시 .private privacy 마킹 사용

public enum AppLogger {
    private static let subsystem = "kr.zerolive.golf.roundon"

    /// 앱 라이프사이클·진입점·복구
    public static let app = Logger(subsystem: subsystem, category: "app")
    /// 라운드 생성·진행·종료·편집
    public static let round = Logger(subsystem: subsystem, category: "round")
    /// 카운터 +1/-1/penalty/clamp 이벤트
    public static let counter = Logger(subsystem: subsystem, category: "counter")
    /// CoreLocation 권한·좌표·매칭
    public static let location = Logger(subsystem: subsystem, category: "location")
    /// 카카오 API 호출·캐시·검증
    public static let kakao = Logger(subsystem: subsystem, category: "kakao")
    /// WC + CloudKit + SyncCoordinator
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    /// SwiftData/CloudKit ModelContainer
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    /// View .onAppear/.onDisappear/navigation
    public static let view = Logger(subsystem: subsystem, category: "view")
    /// Share/Worker/Network
    public static let share = Logger(subsystem: subsystem, category: "share")
    /// HealthKit
    public static let health = Logger(subsystem: subsystem, category: "health")
    /// 스코어카드 OCR import
    public static let ocr = Logger(subsystem: subsystem, category: "ocr")
}
