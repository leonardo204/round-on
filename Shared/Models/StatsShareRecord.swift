import Foundation
import SwiftData

// MARK: - StatsShareRecord
// 통계 공유 영속 레코드 — 사용자당 최대 1건 유지 (간단화)
// - SwiftData @Model — 모든 필드 default 값 + 관계 없음 (CloudKit 호환 패턴)
// - 신규 모델 추가 — 라이트웨이트 마이그레이션 안전

@Model
public final class StatsShareRecord {
    /// 고유 식별자
    public var id: UUID = UUID()
    /// Worker shortId (예: s_xxxxxxxx)
    public var shortId: String = ""
    /// 전체 공유 URL (https://golf.zerolive.co.kr/s/s_xxx)
    public var url: String = ""
    /// 공유 생성 일시
    public var createdAt: Date = Date.now
    /// 만료 일시 (7일 후)
    public var expiresAt: Date = Date.now
    /// 카드 종류 raw (pr/hcp/trend)
    public var cardKindRaw: String = ""
    /// 공유에 표시된 이름 (effectiveDisplayName 적용 후)
    public var displayName: String = ""

    public init(
        id: UUID = UUID(),
        shortId: String,
        url: String,
        createdAt: Date = .now,
        expiresAt: Date,
        cardKindRaw: String,
        displayName: String
    ) {
        self.id = id
        self.shortId = shortId
        self.url = url
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.cardKindRaw = cardKindRaw
        self.displayName = displayName
    }

    /// 만료 여부
    public var isExpired: Bool {
        expiresAt < Date.now
    }
}
