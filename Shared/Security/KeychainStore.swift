import Foundation
import Security

// MARK: - KeychainStoring 프로토콜
// 프로덕션: KeychainStore (Keychain Services)
// 테스트: InMemoryKeychainStore (Dictionary 기반)

public protocol KeychainStoring: AnyObject {
    func setEditToken(_ token: String, for shortId: String) throws
    func editToken(for shortId: String) -> String?
    func deleteEditToken(for shortId: String) throws
    func migrateIfNeeded(round: Round)
}

// MARK: - KeychainStore
// editToken Keychain 저장/조회/삭제 (33-SECURITY §3.4)
// 키 패턴: kr.co.zerolive.roundon.editToken.{shortId}
// kSecAttrAccessible = .whenUnlockedThisDeviceOnly (디바이스 외 전송 방지)

public final class KeychainStore: KeychainStoring, @unchecked Sendable {

    // MARK: Singleton

    public static let shared = KeychainStore()

    // MARK: Init

    public init() {}

    // MARK: Constants

    private static let keyPrefix = "kr.co.zerolive.roundon.editToken."

    // MARK: Public API

    /// editToken을 Keychain에 저장한다 (이미 있으면 덮어쓴다)
    public func setEditToken(_ token: String, for shortId: String) throws {
        let key = Self.keychainKey(for: shortId)
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // 기존 항목 삭제 후 재삽입 (덮어쓰기)
        // 삭제 실패를 무시해도 안전: 항목이 남아 있으면 아래 SecItemAdd가 duplicate로 실패해 throw되므로
        // 저장 실패가 조용히 묻히지 않는다.
        try? deleteItem(for: key)

        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Keychain에서 editToken을 조회한다
    public func editToken(for shortId: String) -> String? {
        let key = Self.keychainKey(for: shortId)

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// Keychain에서 editToken을 삭제한다
    public func deleteEditToken(for shortId: String) throws {
        let key = Self.keychainKey(for: shortId)
        try deleteItem(for: key)
    }

    // MARK: 마이그레이션 헬퍼

    /// Round.sharedEditToken 평문 필드를 Keychain으로 이관한다 (C4)
    /// 이미 Keychain에 있거나 평문이 nil이면 skip
    public func migrateIfNeeded(round: Round) {
        guard let shortId = round.sharedShortId,
              let plainToken = round.sharedEditToken,
              !plainToken.isEmpty,
              editToken(for: shortId) == nil  // Keychain에 아직 없을 때만
        else { return }

        do {
            try setEditToken(plainToken, for: shortId)
            round.sharedEditToken = nil  // Keychain 이관 성공 후에만 평문 제거
        } catch {
            // 평문을 지우지 않아야 다음 실행에서 재이관할 수 있다. 여기서 지우면 토큰이 영구 유실되어
            // 사용자가 자기 공유 링크를 수정·삭제할 수 없게 된다.
            AppLogger.share.error("[Keychain] editToken 이관 실패 — 평문 유지, 다음 실행에 재시도 (shortId=\(shortId)): \(error.localizedDescription)")
        }
    }

    // MARK: Private Helpers

    private static func keychainKey(for shortId: String) -> String {
        return keyPrefix + shortId
    }

    private func deleteItem(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound는 이미 없는 것이므로 무시
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - KeychainStore Stats 확장
// stats editToken 키 패턴: kr.co.zerolive.roundon.stats.editToken.<shortId>
// 라운드 editToken(kr.co.zerolive.roundon.editToken.<shortId>) 과 네임스페이스 분리

extension KeychainStore {

    private static let statsKeyPrefix = "kr.co.zerolive.roundon.stats.editToken."

    /// stats editToken을 Keychain에 저장한다
    public func setStatsEditToken(_ token: String, for shortId: String) throws {
        let key = Self.statsKeychainKey(for: shortId)
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        // 삭제 실패 무시 안전 — 남아 있으면 아래 SecItemAdd가 duplicate로 throw된다 (setEditToken과 동일 계약)
        try? deleteStatsItem(for: key)
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Keychain에서 stats editToken을 조회한다
    public func statsEditToken(for shortId: String) -> String? {
        let key = Self.statsKeychainKey(for: shortId)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// Keychain에서 stats editToken을 삭제한다
    public func removeStatsEditToken(for shortId: String) throws {
        let key = Self.statsKeychainKey(for: shortId)
        try deleteStatsItem(for: key)
    }

    private static func statsKeychainKey(for shortId: String) -> String {
        return statsKeyPrefix + shortId
    }

    private func deleteStatsItem(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - InMemoryKeychainStore
// 테스트 전용 — Keychain entitlement 없이도 동작하는 인메모리 구현

public final class InMemoryKeychainStore: KeychainStoring {

    private var storage: [String: String] = [:]

    public init() {}

    public func setEditToken(_ token: String, for shortId: String) throws {
        storage[shortId] = token
    }

    public func editToken(for shortId: String) -> String? {
        return storage[shortId]
    }

    public func deleteEditToken(for shortId: String) throws {
        storage.removeValue(forKey: shortId)
    }

    public func migrateIfNeeded(round: Round) {
        guard let shortId = round.sharedShortId,
              let plainToken = round.sharedEditToken,
              !plainToken.isEmpty,
              editToken(for: shortId) == nil
        else { return }

        do {
            try setEditToken(plainToken, for: shortId)
            round.sharedEditToken = nil  // 이관 성공 후에만 평문 제거 (프로덕션 구현과 동일 계약)
        } catch {
            AppLogger.share.error("[InMemoryKeychain] editToken 이관 실패 — 평문 유지: \(error.localizedDescription)")
        }
    }

    // MARK: Stats 네임스페이스 (인메모리: "stats:<shortId>" 키 분리)

    public func setStatsEditToken(_ token: String, for shortId: String) throws {
        storage["stats:\(shortId)"] = token
    }

    public func statsEditToken(for shortId: String) -> String? {
        return storage["stats:\(shortId)"]
    }

    public func removeStatsEditToken(for shortId: String) throws {
        storage.removeValue(forKey: "stats:\(shortId)")
    }
}

// MARK: - KeychainError

public enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "토큰을 인코딩할 수 없어요."
        case .saveFailed(let status):
            return "saveFailed(\(status))"
        case .deleteFailed(let status):
            return "deleteFailed(\(status))"
        }
    }
}
