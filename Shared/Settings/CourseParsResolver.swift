import Foundation
import SwiftData

// MARK: - CourseParsResolver

/// par 데이터 단일 진입점.
/// 우선순위: UserParOverride (사용자 수정) > CourseParsCatalog (번들) > nil
///
/// 호출자는 이 enum만 사용하고, CourseParsCatalog.pars/pars18 직접 호출은 금지.
@MainActor
public enum CourseParsResolver {

    // MARK: - 9홀 par 조회

    /// (courseId, subCourseName) → par 배열 (9개). 없으면 nil.
    /// - Parameters:
    ///   - courseId: courses.json의 id 필드
    ///   - subCourseName: 서브코스 이름. nil이면 첫 서브코스 fallback.
    ///   - context: SwiftData ModelContext (UserParOverride 조회용)
    public static func pars(
        courseId: String,
        subCourseName: String?,
        context: ModelContext
    ) -> [Int]? {
        // 1순위: UserParOverride (사용자 수정 데이터)
        let subName = subCourseName ?? ""
        if let override = fetchOverride(courseId: courseId, subCourseName: subName, context: context) {
            AppLogger.persistence.debug("CourseParsResolver: override 사용 — courseId=\(courseId) sub=\(subName)")
            return override.pars
        }

        // 2순위: CourseParsCatalog (번들 데이터)
        return CourseParsCatalog.pars(for: courseId, subCourseName: subCourseName)
    }

    // MARK: - 18홀 par 조회

    /// 18홀 라운드용 — 전반/후반 두 코스명을 합쳐 18개 par 반환.
    /// front 또는 back이 nil이면 CourseParsCatalog의 fallback 로직을 그대로 사용.
    /// - Parameters:
    ///   - courseId: courses.json의 id 필드
    ///   - front: 전반 서브코스 이름
    ///   - back: 후반 서브코스 이름
    ///   - context: SwiftData ModelContext (UserParOverride 조회용)
    public static func pars18(
        courseId: String,
        front: String?,
        back: String?,
        context: ModelContext
    ) -> [Int]? {
        let frontName = front ?? ""
        let backName = back ?? ""

        // 각 9홀에 대해 override 확인
        let frontOverride = fetchOverride(courseId: courseId, subCourseName: frontName, context: context)
        let backOverride = fetchOverride(courseId: courseId, subCourseName: backName, context: context)

        // 둘 다 override가 없으면 CourseParsCatalog 위임
        if frontOverride == nil && backOverride == nil {
            return CourseParsCatalog.pars18(courseId: courseId, front: front, back: back)
        }

        // override와 catalog를 혼합
        let frontPars: [Int]?
        if let ov = frontOverride {
            frontPars = ov.pars
        } else {
            frontPars = CourseParsCatalog.pars(for: courseId, subCourseName: front)
                     ?? CourseParsCatalog.pars18(courseId: courseId, front: front, back: back).flatMap { arr in
                         guard arr.count == 18 else { return nil }
                         return Array(arr.prefix(9))
                     }
        }

        let backPars: [Int]?
        if let ov = backOverride {
            backPars = ov.pars
        } else {
            backPars = CourseParsCatalog.pars(for: courseId, subCourseName: back)
                    ?? CourseParsCatalog.pars18(courseId: courseId, front: front, back: back).flatMap { arr in
                        guard arr.count == 18 else { return nil }
                        return Array(arr.suffix(9))
                    }
        }

        guard let f = frontPars, let b = backPars, f.count == 9, b.count == 9 else {
            return nil
        }
        return f + b
    }

    // MARK: - Private helpers

    private static func fetchOverride(
        courseId: String,
        subCourseName: String,
        context: ModelContext
    ) -> UserParOverride? {
        let compositeKey = "\(courseId)|\(subCourseName)"
        var descriptor = FetchDescriptor<UserParOverride>(
            predicate: #Predicate { $0.courseId == courseId && $0.subCourseName == subCourseName },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let results = (try? context.fetch(descriptor)) ?? []
        return results.first
    }
}
