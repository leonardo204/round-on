import Foundation

// MARK: - DeviceIdentifier
// 디바이스 식별 + perDeviceCounter 관리 (22-STATE §6)
// perDeviceCounter: UserDefaults에 영속하여 앱 재시작 후에도 단조 증가 유지

public enum DeviceKind: String, Sendable {
    case watch   = "Watch"
    case iPhone  = "iPhone"
}

// MARK: - PerDeviceCounter actor
// 단조 증가 카운터 — 디바이스별 분리

public actor PerDeviceCounter {

    public static let shared = PerDeviceCounter()

    private let userDefaultsKey = "kr.zerolive.golf.perDeviceCounter"
    private var current: UInt64

    private init() {
        let stored = UserDefaults.standard.object(forKey: "kr.zerolive.golf.perDeviceCounter") as? UInt64 ?? 0
        self.current = stored
    }

    /// 다음 카운터 값 반환 (단조 증가)
    public func next() -> UInt64 {
        current &+= 1   // 오버플로우 wrap-around (실용상 무한대)
        UserDefaults.standard.set(current, forKey: userDefaultsKey)
        return current
    }

    /// 현재 값 조회 (증가 없음)
    public var value: UInt64 { current }
}

// MARK: - DeviceIdentifier

public struct DeviceIdentifier: Sendable {

    /// 현재 디바이스 종류
    public static var kind: DeviceKind {
        #if os(watchOS)
        return .watch
        #else
        return .iPhone
        #endif
    }

    /// WC 메시지 deviceId 문자열
    public static var stringValue: String { kind.rawValue }
}
