import Foundation

// MARK: - ConsentManager
// Gemini Vision API 외부 전송 동의 상태를 관리한다.
// 동의 없이는 Gemini 호출 자체를 차단한다.
//
// UserDefaults 키: "gemini_data_consent_accepted" (Bool)
// 동의 시점 기록: "gemini_data_consent_date" (Double — timeIntervalSince1970)

public final class ConsentManager: @unchecked Sendable {

    public static let shared = ConsentManager()

    private let defaults: UserDefaults
    private let consentKey = "gemini_data_consent_accepted"
    private let consentDateKey = "gemini_data_consent_date"

    // MARK: - Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 상태 조회

    /// Gemini 데이터 전송에 동의했는지 여부
    public var isAccepted: Bool {
        defaults.bool(forKey: consentKey)
    }

    /// 동의 시점 (동의한 적 없으면 nil)
    public var acceptedDate: Date? {
        let ts = defaults.double(forKey: consentDateKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // MARK: - 상태 변경

    /// 동의 수락: UserDefaults에 동의 상태와 시점을 기록한다.
    public func accept() {
        defaults.set(true, forKey: consentKey)
        defaults.set(Date().timeIntervalSince1970, forKey: consentDateKey)
    }

    /// 동의 철회: 동의 상태를 false로 설정한다. (시점 기록은 유지)
    public func revoke() {
        defaults.set(false, forKey: consentKey)
    }
}
