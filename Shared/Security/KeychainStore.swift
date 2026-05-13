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

        try? setEditToken(plainToken, for: shortId)
        round.sharedEditToken = nil  // 평문 필드 비우기
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

        try? setEditToken(plainToken, for: shortId)
        round.sharedEditToken = nil
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
