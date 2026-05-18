import Foundation

// 번들 토큰 — Shared framework 본 모듈 번들 접근용 (watchOS/iOS 공통).
// Color+SeasonalGreen.swift의 SharedAssetBundleToken는 watchOS에서 제외되므로 별도 정의.
private final class CourseParsBundleToken {}

// MARK: - CourseParsCatalog
// 골프장별 코스/홀별 par 사전 데이터 로더.
// Shared/Resources/CoursePars/courses.json 번들에서 일괄 로드 후 메모리 캐시.
// 라운드 시작 시 (골프장ID, 서브코스명) 키로 par 배열 조회 → HoleScore.par prefill.
//
// 데이터 소스: 각 골프장 공식 사이트 크롤링 + 거리 휴리스틱 + 사용자 검증.
// 사용자 입력으로 사후 보정 가능 (HoleScore.par 변경 → 영구 저장).

public struct CoursePars: Codable, Sendable {
    public let courseId: String
    public let courseName: String
    public let source: String
    public let confidence: String       // "high" | "medium" | "low"
    public let subCourses: [SubCoursePars]
}

public struct SubCoursePars: Codable, Sendable {
    public let name: String
    public let pars: [Int]              // 항상 9개 (front 또는 back nine)
}

private struct CourseParsFile: Codable {
    let version: Int
    let updatedAt: String
    let courses: [CoursePars]
}

@MainActor
public enum CourseParsCatalog {

    private static var cache: [String: CoursePars] = [:]
    private static var loaded = false

    /// 번들에서 일괄 로드 (idempotent — 첫 호출만 실제 디스크 IO)
    public static func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        let bundle = Bundle(for: CourseParsBundleToken.self)
        guard let url = bundle.url(forResource: "courses", withExtension: "json", subdirectory: "CoursePars")
                     ?? bundle.url(forResource: "courses", withExtension: "json") else {
            AppLogger.persistence.warning("CourseParsCatalog: courses.json 번들 미발견")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(CourseParsFile.self, from: data)
            for c in file.courses {
                cache[c.courseId] = c
            }
            AppLogger.persistence.info("CourseParsCatalog: \(file.courses.count)개 골프장 로드 완료 (v\(file.version))")
        } catch {
            AppLogger.persistence.error("CourseParsCatalog: load 실패 — \(error.localizedDescription)")
        }
    }

    /// (골프장ID, 서브코스명) → par 배열 (9개). 없으면 nil.
    public static func pars(for courseId: String, subCourseName: String?) -> [Int]? {
        loadIfNeeded()
        guard let course = cache[courseId] else { return nil }
        guard let subName = subCourseName, !subName.isEmpty else {
            // 서브코스 미지정 — 첫 서브코스 사용 (단일 코스 골프장 대응)
            return course.subCourses.first?.pars
        }
        return course.subCourses.first(where: { $0.name == subName })?.pars
    }

    /// 18홀 라운드용 — 전반/후반 두 코스명을 합쳐 18개 par 반환
    /// front 또는 back이 nil이면 전체 first subCourse를 사용 (fallback)
    public static func pars18(courseId: String, front: String?, back: String?) -> [Int]? {
        loadIfNeeded()
        guard let course = cache[courseId] else { return nil }

        let frontPars = pars(for: courseId, subCourseName: front) ?? course.subCourses.first?.pars
        let backPars = pars(for: courseId, subCourseName: back)
                    ?? course.subCourses.dropFirst().first?.pars
                    ?? course.subCourses.first?.pars

        guard let f = frontPars, let b = backPars, f.count == 9, b.count == 9 else {
            return nil
        }
        return f + b
    }

    /// 디버그용 — 등록된 골프장 ID 목록
    public static var registeredCourseIds: [String] {
        loadIfNeeded()
        return Array(cache.keys).sorted()
    }
}
