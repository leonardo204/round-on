import Foundation

// MARK: - CourseRepository

/// 번들 JSON에서 골프장 목록을 로드하는 actor.
/// cold load는 첫 호출 시 1회만 수행하고 이후 메모리 캐시를 반환한다.
/// Watch 앱에는 포함되지 않음 (WatchConnectivity로 수신). iOS 앱 전용.
public actor CourseRepository {
    public static let shared = CourseRepository()

    private var cache: [GolfCourse]?

    // MARK: Public API

    /// 전체 골프장 목록 반환. 첫 호출 시 번들 JSON을 파싱한다.
    public func loadAll() async throws -> [GolfCourse] {
        if let cache { return cache }

        guard let url = Bundle(for: BundleToken.self).url(forResource: "courses", withExtension: "json")
                ?? Bundle.main.url(forResource: "courses", withExtension: "json") else {
            throw CourseRepositoryError.bundleResourceMissing
        }

        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(CourseDatasetDTO.self, from: data)
        let courses = dto.courses
        self.cache = courses
        return courses
    }

    /// 이름 prefix로 골프장 검색 (대소문자 무시, 한글 포함).
    /// - Parameter prefix: 검색어. 빈 문자열이면 전체 반환.
    public func search(byName prefix: String) async throws -> [GolfCourse] {
        let all = try await loadAll()
        guard !prefix.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(prefix) }
    }

    /// 지역명으로 필터링.
    /// - Parameter region: "경기", "서울" 등 지역 문자열.
    public func filter(region: String) async throws -> [GolfCourse] {
        let all = try await loadAll()
        return all.filter { $0.region == region }
    }
}

// MARK: - CourseRepositoryError

public enum CourseRepositoryError: Error, Sendable {
    case bundleResourceMissing
}

// MARK: - Private DTO

/// JSON 최상위 래퍼. 외부에는 [GolfCourse]만 노출.
private struct CourseDatasetDTO: Codable {
    let version: String
    let totalCourses: Int
    let courses: [GolfCourse]
}

/// framework 번들 탐색용 토큰 클래스.
private final class BundleToken {}
