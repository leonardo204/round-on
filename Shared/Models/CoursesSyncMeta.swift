import Foundation
import SwiftData

// MARK: - CoursesSyncMeta

/// 원격 코스 데이터 동기화 메타정보.
/// endpoint 단위로 1행씩 유지 (courses / course-pars).
/// @Attribute(.unique) 미사용 — CloudKit 미지원. insert 전 endpoint로 조회.
/// 라이트웨이트 마이그레이션 안전 — 모든 프로퍼티에 default 값 부여.
@Model
public final class CoursesSyncMeta {
    /// API 엔드포인트 식별자. 예: "courses", "course-pars"
    public var endpoint: String = ""
    /// 마지막으로 받은 ETag 헤더 값 (If-None-Match 재전송용)
    public var etag: String = ""
    /// 서버가 반환한 데이터 버전 문자열
    public var version: String = ""
    /// 마지막 fetch 시도 일시
    public var lastFetchedAt: Date = Date.distantPast
    /// 마지막 fetch 성공 일시 (304 포함)
    public var lastSuccessAt: Date = Date.distantPast

    public init(
        endpoint: String,
        etag: String = "",
        version: String = "",
        lastFetchedAt: Date = .distantPast,
        lastSuccessAt: Date = .distantPast
    ) {
        self.endpoint = endpoint
        self.etag = etag
        self.version = version
        self.lastFetchedAt = lastFetchedAt
        self.lastSuccessAt = lastSuccessAt
    }
}
