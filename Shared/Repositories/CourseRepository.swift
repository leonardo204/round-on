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

    /// 특정 좌표 근처 골프장 목록 반환 (haversine 거리 기준 오름차순 정렬).
    /// clubhouse 좌표가 없는 코스는 제외된다.
    ///
    /// - Parameters:
    ///   - coord: 기준 좌표 (lat, lng)
    ///   - limit: 반환할 최대 개수 (기본 20)
    /// - Returns: 거리 오름차순으로 정렬된 골프장 목록
    public func nearestCourses(
        to coord: (lat: Double, lng: Double),
        limit: Int = 20
    ) async throws -> [GolfCourse] {
        let all = try await loadAll()

        // clubhouse 좌표 있는 코스만 대상
        let withCoord = all.compactMap { course -> (GolfCourse, Double)? in
            guard let ch = course.clubhouse else { return nil }
            let dist = haversineKm(
                lat1: coord.lat, lng1: coord.lng,
                lat2: ch.lat, lng2: ch.lng
            )
            return (course, dist)
        }

        // 거리 오름차순 정렬 후 limit 개수 반환
        return withCoord
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    // MARK: - 적응형 임계값 매칭

    /// 지역별 골프장 밀도를 고려한 적응형 임계값 기반 가장 가까운 골프장 탐색.
    ///
    /// 알고리즘:
    /// 1. 1km 반경 검색 → 결과 있으면 가장 가까운 1건 자동 매칭
    /// 2. 1km 없으면 3km 반경 → 1건이면 자동 매칭, 2건 이상이면 후보 목록 반환
    /// 3. 3km 없으면 5km 반경 → 후보 목록만 (자동 매칭 X)
    /// 4. 5km에도 없으면 matched: nil + candidates: []
    ///
    /// - Parameter coord: 기준 좌표 (lat, lng)
    /// - Returns: (matched: 단일 자동 매칭 결과, candidates: 후보 목록, radiusKm: 실제 사용된 반경)
    public func nearestCoursesAdaptive(
        to coord: (lat: Double, lng: Double)
    ) async throws -> AdaptiveMatchResult {
        let all = try await loadAll()

        // clubhouse 좌표 있는 코스만 거리와 함께 계산
        let withDistance: [(GolfCourse, Double)] = all.compactMap { course in
            guard let ch = course.clubhouse else { return nil }
            let dist = haversineKm(
                lat1: coord.lat, lng1: coord.lng,
                lat2: ch.lat, lng2: ch.lng
            )
            return (course, dist)
        }
        let sorted = withDistance.sorted { $0.1 < $1.1 }

        // 1단계: 1km 반경
        let within1km = sorted.filter { $0.1 <= 1.0 }
        if let best = within1km.first {
            return AdaptiveMatchResult(
                matched: best.0,
                candidates: [best.0],
                radiusKm: 1.0
            )
        }

        // 2단계: 3km 반경
        let within3km = sorted.filter { $0.1 <= 3.0 }
        if within3km.count == 1 {
            // 단일 결과 → 자동 매칭
            return AdaptiveMatchResult(
                matched: within3km[0].0,
                candidates: [within3km[0].0],
                radiusKm: 3.0
            )
        } else if within3km.count > 1 {
            // 다중 결과 → 후보 목록, 자동 매칭 X
            return AdaptiveMatchResult(
                matched: nil,
                candidates: within3km.map { $0.0 },
                radiusKm: 3.0
            )
        }

        // 3단계: 5km 반경
        let within5km = sorted.filter { $0.1 <= 5.0 }
        if !within5km.isEmpty {
            return AdaptiveMatchResult(
                matched: nil,
                candidates: within5km.map { $0.0 },
                radiusKm: 5.0
            )
        }

        // 4단계: 매칭 없음
        return AdaptiveMatchResult(
            matched: nil,
            candidates: [],
            radiusKm: 5.0
        )
    }
}

// MARK: - AdaptiveMatchResult

/// nearestCoursesAdaptive 반환 타입.
/// matched가 nil이고 candidates가 비어있으면 "매칭 없음" 상태.
public struct AdaptiveMatchResult: Sendable {
    /// 단일 자동 매칭된 골프장. 다중 후보 또는 없음이면 nil.
    public let matched: GolfCourse?
    /// 반경 내 모든 후보 목록 (거리 오름차순).
    public let candidates: [GolfCourse]
    /// 실제 탐색에 사용된 반경 (km).
    public let radiusKm: Double

    public init(matched: GolfCourse?, candidates: [GolfCourse], radiusKm: Double) {
        self.matched = matched
        self.candidates = candidates
        self.radiusKm = radiusKm
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
