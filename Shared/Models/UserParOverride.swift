import Foundation
import SwiftData

// MARK: - UserParOverride

/// 사용자가 라운드 중 par를 변경한 내역을 영구 저장하는 모델.
/// 다음 라운드 시작 시 CourseParsResolver가 이 값을 우선 반환한다.
///
/// composite key: `\(courseId)|\(subCourseName)` — FetchDescriptor predicate로 조회.
/// @Attribute(.unique) 미사용 — CloudKit 미지원. PersistedDiscoveredCourse 패턴 답습.
/// 라이트웨이트 마이그레이션 안전 — 모든 프로퍼티에 default 값 부여.
@Model
public final class UserParOverride {
    /// 골프장 ID (courses.json의 id 필드)
    public var courseId: String = ""
    /// 서브코스 이름 (예: "동코스", "전반"). 9홀 단위로 저장.
    public var subCourseName: String = ""
    /// 9개 홀의 par 배열 (항상 9개)
    public var pars: [Int] = []
    /// 마지막 갱신 일시
    public var updatedAt: Date = Date.now
    /// 이 override를 마지막으로 생성/수정한 라운드 ID
    public var roundIdLast: UUID?

    public init(
        courseId: String,
        subCourseName: String,
        pars: [Int],
        updatedAt: Date = .now,
        roundIdLast: UUID? = nil
    ) {
        self.courseId = courseId
        self.subCourseName = subCourseName
        self.pars = pars
        self.updatedAt = updatedAt
        self.roundIdLast = roundIdLast
    }

    /// composite key (조회용 편의 프로퍼티)
    public var compositeKey: String { "\(courseId)|\(subCourseName)" }
}
