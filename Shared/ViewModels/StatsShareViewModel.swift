import Foundation
import SwiftUI
import Observation

// MARK: - StatsShareViewModel
// 통계 공유 시트 상태 관리
// - 카드 종류 선택 + 닉네임 입력 + PIN 설정
// - createStatsShare API 호출 + Keychain 저장
// - ShareAPIClient는 App-iOS 레이어에서 주입 (Shared 레이어에서는 프로토콜로 추상)

@MainActor
@Observable
public final class StatsShareViewModel {

    // MARK: - Load State

    public enum LoadState: Equatable {
        case idle
        case loading
        case success(url: URL, shortId: String)
        case failed(String)

        public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case (.success(let a, let b), .success(let c, let d)): return a == c && b == d
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Public State

    /// 선택된 카드 종류 (PR / HCP / TREND)
    public var cardKind: StatsSignatureCardKind

    /// 공유에 표시할 닉네임 (마스킹 전) — 비워두면 자동 "익명"
    public var displayName: String

    /// PIN 입력값 (4자리 숫자)
    public var pin: String

    /// PIN 보호 사용 여부
    public var usePin: Bool

    /// 로드 상태
    public var loadState: LoadState = .idle

    // MARK: - Private

    private let keychain: InMemoryKeychainStore
    private let payloadBuilder: (StatsSignatureCardKind, String) -> StatsSharePayload
    private let apiClientClosure: () async throws -> StatsShareCreateResponseValue

    // MARK: - Init

    /// 프로덕션 이니셜라이저 — App-iOS 레이어에서 클로저로 API 호출 주입
    public init(
        initialCardKind: StatsSignatureCardKind,
        initialDisplayName: String = "",
        payloadBuilder: @escaping (StatsSignatureCardKind, String) -> StatsSharePayload,
        createStatsShare: @escaping () async throws -> StatsShareCreateResponseValue
    ) {
        self.cardKind = initialCardKind
        self.displayName = initialDisplayName
        self.pin = ""
        self.usePin = false
        self.keychain = InMemoryKeychainStore()
        self.payloadBuilder = payloadBuilder
        self.apiClientClosure = createStatsShare
    }

    // MARK: - Computed

    /// displayName 비워두면 "익명", 입력 시 trimmed 값 반환
    public var effectiveDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "익명" : trimmed
    }

    public var isPinValid: Bool {
        guard usePin else { return true }
        return pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    public var canGenerate: Bool {
        isPinValid && loadState != .loading
    }

    // MARK: - Actions

    /// 공유 링크 생성 + Keychain 저장
    public func generateAndShare() async {
        guard canGenerate else { return }
        loadState = .loading
        let kindRaw = cardKind.rawValue
        AppLogger.share.info("[StatsShareVM] generateAndShare 시작 — cardKind=\(kindRaw)")

        do {
            let resp = try await apiClientClosure()
            AppLogger.share.info("[StatsShareVM] createStatsShare 성공 — shortId=\(resp.shortId)")

            // Keychain 저장 (인메모리 — ViewModel 생명주기 동안 보유)
            try? keychain.setStatsEditToken(resp.editToken, for: resp.shortId)

            if let url = URL(string: resp.url) {
                loadState = .success(url: url, shortId: resp.shortId)
            } else {
                AppLogger.share.error("[StatsShareVM] URL 파싱 실패: \(resp.url)")
                loadState = .failed("URL 생성 실패")
            }
        } catch {
            AppLogger.share.error("[StatsShareVM] 오류: \(error.localizedDescription)")
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 현재 payload 생성 (미리보기 등에서 사용) — effectiveDisplayName 적용
    public func currentPayload() -> StatsSharePayload {
        payloadBuilder(cardKind, effectiveDisplayName)
    }

    /// 특정 cardKind 의 payload 생성 (picker 썸네일에서 사용) — effectiveDisplayName 적용
    public func previewPayload(for kind: StatsSignatureCardKind) -> StatsSharePayload {
        payloadBuilder(kind, effectiveDisplayName)
    }

    /// Keychain에서 shortId에 해당하는 editToken 조회
    public func storedEditToken(for shortId: String) -> String? {
        keychain.statsEditToken(for: shortId)
    }

    /// 상태 초기화 (시트 재진입 시)
    public func reset() {
        loadState = .idle
        pin = ""
        usePin = false
    }
}

// MARK: - StatsShareCreateResponseValue
// App-iOS ShareAPIClient.StatsShareCreateResponse 와 구조 동일 (Shared 레이어 의존 없이 주입)

public struct StatsShareCreateResponseValue: Sendable {
    public let shortId: String
    public let url: String
    public let editToken: String
    public let expiresAt: Date

    public init(shortId: String, url: String, editToken: String, expiresAt: Date) {
        self.shortId = shortId
        self.url = url
        self.editToken = editToken
        self.expiresAt = expiresAt
    }
}
